//
// Passbolt - Open source password manager for teams
// Copyright (c) 2021 Passbolt SA
//
// This program is free software: you can redistribute it and/or modify it under the terms of the GNU Affero General
// Public License (AGPL) as published by the Free Software Foundation version 3.
//
// The name "Passbolt" is a registered trademark of Passbolt SA, and Passbolt SA hereby declines to grant a trademark
// license to "Passbolt" pursuant to the GNU Affero General Public License version 3 Section 7(e), without a separate
// agreement with Passbolt SA.
//
// This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied
// warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See GNU Affero General Public License for more details.
//
// You should have received a copy of the GNU Affero General Public License along with this program. If not,
// see GNU Affero General Public License v3 (http://www.gnu.org/licenses/agpl-3.0.html).
//
// @copyright     Copyright (c) Passbolt SA (https://www.passbolt.com)
// @license       https://opensource.org/licenses/AGPL-3.0 AGPL License
// @link          https://www.passbolt.com Passbolt (tm)
// @since         v1.0
//

import Commons
import Display
import FeatureScopes
import Metadata
import OSFeatures
import Resources

internal final class OTPAttachSelectionListViewController: ViewController {

  internal struct Context {

    internal var totpSecret: TOTPSecret
  }

  internal struct ViewState: Equatable {

    internal enum Confirmation {
      case attach
      case replace
    }

    internal var searchText: String
    internal var listItems: Array<TOTPAttachSelectionListItemViewModel>
    internal var confirmationAlert: Confirmation?
  }

  nonisolated internal let viewState: ViewStateSource<ViewState>

  private struct LocalState: Equatable {

    fileprivate var selected: SelectedItem?
  }

  fileprivate struct SelectedItem: Equatable {

    fileprivate var id: Resource.ID
    fileprivate var typeInfo: ResourceTypeInfo
  }

  private let localState: Variable<LocalState>

  private let resourceSearchController: ResourceSearchController
  private let resourceEditPreparation: ResourceEditPreparation

  private let navigationToOTPScanning: NavigationToOTPScanning

  /// A permission confirmation flow that may still be on screen, with the resource it was built for - it owns the
  /// editing scope branched for that one resource, and may only be reused for it.
  private struct OngoingConfirmation {

    fileprivate let resourceID: Resource.ID
    fileprivate let flow: ResourceEditPermissionConfirmation
  }

  // Attaching the code rewrites the resource secret, so a shared resource goes through the permission
  // confirmation like any other edit. Retained for as long as the confirmation may be on screen, and no longer -
  // the scope it owns holds the decrypted secret.
  private var permissionConfirmation: OngoingConfirmation?

  private let context: Context

  private let features: Features

  internal init(
    context: Context,
    features: Features
  ) throws {
    try features.ensureScope(SessionScope.self)

    self.features = features

    self.context = context

    self.navigationToOTPScanning = try features.instance()

    self.resourceSearchController = try features.instance()
    self.resourceEditPreparation = try features.instance()

    self.localState = .init(
      initial: .init(
        selected: .none
      )
    )
    self.viewState = .init(
      initial: .init(
        searchText: .init(),
        listItems: .init()
      ),
      updateFrom: ComputedVariable(
        combined: self.resourceSearchController.state,
        with: self.localState
      ),
      update: { (updateView, update: Update<(ResourceSearchState, LocalState)>) in
        do {
          let (search, local): (ResourceSearchState, LocalState) = try update.value
          updateView { (viewState: inout ViewState) in
            viewState.searchText = search.filter.text
            viewState.listItems = search.result.map {
              (item: ResourceSearchResultItem) -> TOTPAttachSelectionListItemViewModel in
              .init(
                id: item.id,
                typeInfo: item.typeInfo,
                icon: item.icon,
                name: item.name,
                username: item.username,
                state: local.selected?.id == item.id
                  ? .selected
                  : mapDeselectedState(of: item)
              )
            }
          }
        }
        catch {
          SnackBarMessageEvent.send(.error(error))
        }

        func mapDeselectedState(of item: ResourceSearchResultItem) -> TOTPAttachSelectionListItemViewModel.State {
          guard item.typeInfo.type.attachedOTPSlug != nil else {
            return .notCompatibleWithTotp
          }
          return item.permission.canEdit ? .deselected : .notAllowed
        }
      }
    )
  }
}

extension OTPAttachSelectionListViewController {

  @MainActor internal func setSearch(
    text: String
  ) {
    self.resourceSearchController.updateFilter { (filter: inout ResourceSearchFilter) in
      filter.text = text
    }
  }

  @MainActor internal func select(
    _ item: TOTPAttachSelectionListItemViewModel
  ) {
    switch item.state {
    case .deselected, .selected:
      self.localState.mutate { (state: inout LocalState) in
        state.selected = .init(
          id: item.id,
          typeInfo: item.typeInfo
        )
      }
    case .notAllowed:
      SnackBarMessageEvent.send(.error(.localized("otp.attach.error.notAllowed")))
    case .notCompatibleWithTotp:
      SnackBarMessageEvent.send(.error(.localized("otp.attach.error.notCompatible")))
    }

  }

  @MainActor internal func trySendForm() async {
    await consumingErrors {
      guard let selected: SelectedItem = self.localState.value.selected
      else {
        throw
          InvalidForm
          .error(displayable: "resource.form.error.invalid")
      }

      if selected.typeInfo.type.contains(\.firstTOTP) {
        await self.viewState.update(\.confirmationAlert, to: .replace)
      }
      else {
        await self.viewState.update(\.confirmationAlert, to: .attach)
      }
    }
  }

  @MainActor internal func sendForm() async {
    await consumingErrors {
      guard let selected: SelectedItem = self.localState.value.selected
      else {
        throw
          InvalidForm
          .error(displayable: "resource.form.error.invalid")
      }

      let editingContext: ResourceEditingContext = try await self.resourceEditPreparation.prepareExisting(selected.id)

      guard
        let attachedOTPSlug: ResourceSpecification.Slug = selected.typeInfo.type.attachedOTPSlug,
        let attachedOTPType: ResourceType =
          editingContext.availableTypes.first(where: { $0.specification.slug == attachedOTPSlug })
      else {
        throw
          InvalidResourceTypeError
          .error(message: "Attempting to attach OTP to a resource which has none or unavailable attached type!")
      }

      let features: Features = try await self.features.branch(
        scope: ResourceEditScope.self,
        context: editingContext
      )

      let resourceEditForm: ResourceEditForm = try await features.instance()

      if attachedOTPType != selected.typeInfo.type {
        try resourceEditForm.updateType(attachedOTPType)
      }  // else keep current type

      resourceEditForm.update(\.firstTOTP, to: self.context.totpSecret)

      let message: SnackBarMessage =
        editingContext.editedResource.isLocal || !editingContext.editedResource.hasTOTP
        ? "otp.edit.otp.created.message"
        : "otp.edit.otp.replaced.message"

      // Validated before the confirmation is offered - reviewing recipients only to be told the form is invalid
      // would be reviewing them for nothing.
      try await resourceEditForm.validateForm()

      // Editing a shared resource interposes the confirmation screen; that path runs the edit on confirm, so
      // return early when it takes over.
      if try await self.presentConfirmationIfNeeded(
        features: features,
        resourceID: selected.id,
        message: message
      ) {
        return
      }

      do {
        try await resourceEditForm.send()
        await self.finishAttaching(message: message)
      }
      catch let error as MetadataPinnedKeyValidationError {
        // Same offer as on the confirmed path - a rotated key is trusted and the attach retried, rather than
        // leaving the operator with an error they cannot act on.
        await self.navigateToMetadataPinnedKeyValidation(reason: error.reason)
      }
    }
  }

  /// Presents the permission confirmation when the edit calls for it, retaining the flow - and with it the
  /// editing scope branched for the selected resource - for as long as the confirmation may be on screen.
  ///
  /// A flow from an earlier attempt is reused rather than replaced, but only while its confirmation screen is still
  /// displayed and only for the resource it was built for: trusting a rotated metadata key runs this submission
  /// again from the start, and that screen confirms into the flow it was opened with. Replacing it would release
  /// the branched scope behind the displayed screen and leave its confirm button reporting a failure.
  ///
  /// Otherwise the flow is dropped and this submission builds its own. It is bound to the scope branched for the
  /// resource selected back then, and once the operator left the confirmation - cancelling it, or going back - they
  /// are free to select another resource before submitting again. A reused flow would then confirm the recipients
  /// of the previously selected resource and attach the code to it.
  @MainActor private func presentConfirmationIfNeeded(
    features: Features,
    resourceID: Resource.ID,
    message: SnackBarMessage
  ) async throws -> Bool {
    let ongoing: OngoingConfirmation? = self.permissionConfirmation
    let ongoingDisplayed: Bool = try ongoing?.flow.isConfirmationDisplayed() ?? false

    let permissionConfirmation: ResourceEditPermissionConfirmation
    if let ongoing: OngoingConfirmation = ongoing,
      ongoingDisplayed,
      ongoing.resourceID == resourceID
    {
      permissionConfirmation = ongoing.flow
    }
    else {
      permissionConfirmation = try .init(features: features)
    }
    let takenOver: Bool = try await permissionConfirmation.presentEditConfirmationIfNeeded(
      onApplied: { [weak self] (_: Resource) in
        await self?.finishAttaching(message: message)
      },
      onInvalidMetadataKey: { [weak self] (reason: MetadataPinnedKeyValidationError.Reason) in
        await self?.navigateToMetadataPinnedKeyValidation(reason: reason)
      },
      onCancelled: { [weak self, weak permissionConfirmation] in
        // Backing out leaves nothing to resume, so the flow - and the editing scope it owns, holding the decrypted
        // secret - goes now rather than at the next submission. Identity checked so a cancel can only ever drop
        // the flow it belongs to.
        guard let flow: ResourceEditPermissionConfirmation = permissionConfirmation,
          self?.permissionConfirmation?.flow === flow
        else { return }
        self?.permissionConfirmation = .none
      }
    )
    // Retained only while its screen may be displayed - otherwise the branched scope would outlive the submission
    // it was created for. Cancelling releases it through `onCancelled`; this covers leaving the screen any other
    // way, which reports no cancellation. A flow whose screen is still up is never dropped, even by a submission
    // that did not take it over: the presented screen holds nothing but a weak reference back to it, so releasing
    // it here would leave its confirm button reporting a failure.
    if takenOver {
      self.permissionConfirmation = .init(resourceID: resourceID, flow: permissionConfirmation)
    }
    else if ongoingDisplayed == false {
      self.permissionConfirmation = .none
    }
    return takenOver
  }

  /// Leaves the scanning flow after the code was attached. Navigation failures are logged rather than thrown: the
  /// resource is already updated, and reporting a failure here would invite attaching it a second time.
  @MainActor private func finishAttaching(
    message: SnackBarMessage
  ) async {
    self.permissionConfirmation = .none
    do {
      try await self.navigationToOTPScanning.revert()
    }
    catch {
      error.logged()
    }
    SnackBarMessageEvent.send(message)
  }

  @MainActor private func navigateToMetadataPinnedKeyValidation(
    reason: MetadataPinnedKeyValidationError.Reason
  ) async {
    await presentMetadataPinnedKeyValidation(
      features: self.features,
      reason: reason,
      onTrustedKey: { [weak self] in await self?.sendForm() }
    )
  }
}

internal struct TOTPAttachSelectionListItemViewModel: Equatable, Identifiable {

  internal enum State: Equatable {
    case deselected
    case selected
    case notAllowed
    case notCompatibleWithTotp

    internal var selected: Bool {
      switch self {
      case .deselected:
        return false

      case .selected:
        return true

      case .notAllowed, .notCompatibleWithTotp:
        return false
      }
    }

    internal var disabled: Bool {
      switch self {
      case .deselected:
        return false

      case .selected:
        return false

      case .notAllowed, .notCompatibleWithTotp:
        return true
      }
    }
  }

  internal let id: Resource.ID
  internal var typeInfo: ResourceTypeInfo
  internal var icon: ResourceIcon
  internal var name: String
  internal var username: String?
  internal var state: State

  internal init(
    id: Resource.ID,
    typeInfo: ResourceTypeInfo,
    icon: ResourceIcon,
    name: String,
    username: String? = nil,
    state: State
  ) {
    self.id = id
    self.typeInfo = typeInfo
    self.icon = icon
    self.name = name
    self.username = username
    self.state = state
  }
}
