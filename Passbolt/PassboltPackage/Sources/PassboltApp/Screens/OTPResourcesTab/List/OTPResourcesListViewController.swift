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
import SessionData
import SharedUIComponents

internal final class OTPResourcesListViewController: ViewController {

  internal struct ViewState: Equatable {

    internal var otpResources: Array<TOTPResourceViewModel> = .init()
    internal var isLoadingMore: Bool = false
    internal var hasMoreData: Bool = true
    internal var contentResetToken: Int = 0
    internal var lastFilterText: String = .init()
  }

  internal struct Context {

    internal let pageSize: Int

    internal init(pageSize: Int) {
      self.pageSize = pageSize
    }
  }

  internal nonisolated let viewState: ViewStateSource<ViewState>
  internal nonisolated let refreshSource: AnyUpdatable<Double?>

  internal let createAvailable: Bool

  private let pasteboard: OSPasteboard

  private let resourcesOTPController: ResourcesOTPController
  private let resourceEditPreparation: ResourceEditPreparation
  private let resources: ResourcesController
  private let sessionData: SessionData
  internal let searchController: ResourceSearchDisplayController

  /// A permission confirmation flow that may still be on screen, with the resource it was built for - it owns the
  /// editing scope branched for that one resource, and may only be reused for it.
  private struct OngoingConfirmation {

    fileprivate let resourceID: Resource.ID
    fileprivate let flow: ResourceEditPermissionConfirmation
  }

  // Detaching the TOTP changes the resource type, which reshapes and re-encrypts the secret for every recipient,
  // so a shared resource goes through the permission confirmation like any other edit. Retained here rather than
  // in the alert - which is a value copied into an `AlertItem` and dropped - for as long as the confirmation may
  // be on screen, and no longer: the scope it owns holds the decrypted secret.
  private var permissionConfirmation: OngoingConfirmation?

  private let features: Features
  private let context: Context

  internal init(
    context: Context,
    features: Features
  ) throws {
    try features.ensureScope(SessionScope.self)

    self.features = features
    self.context = context
    self.resources = try features.instance()
    self.sessionData = try features.instance()
    self.refreshSource = self.sessionData.refreshProgress

    self.createAvailable = try features.sessionConfiguration().resources.totpEnabled
    let otpController: ResourcesOTPController = try features.instance()
    self.resourcesOTPController = otpController
    self.pasteboard = features.instance()

    let navigationToAccountMenu: NavigationToAccountMenu = try features.instance()

    self.searchController = try features.instance(
      context: .init(
        searchPrompt: "otp.resources.search.placeholder",
        onPresentationMenuTap: .none,
        onAvatarTap: { [otpController] in
          otpController.hideOTP()
          try await navigationToAccountMenu.perform()
        }
      )
    )

    self.resourceEditPreparation = try features.instance()

    self.viewState = .init(
      initial: .init(),
      updateFrom: ComputedVariable(
        combined: searchController.searchText.asAnyUpdatable(),
        with: sessionData.lastUpdate,
        combine: { (update: (Update<String>, Update<Timestamp>)) in
          try update.0.value
        }
      ),
      update: { [resources, resourcesOTPController] (updateState, update: Update<String>) in
        do {
          var filter: ResourcesFilter = .init(sorting: .nameAlphabetically, otpOnly: true)
          filter.text = try update.value
          filter.limit = context.pageSize
          filter.offset = 0
          let otpResources: Array<TOTPResourceViewModel> =
            try await resources
            .filteredResourcesList(filter)
            .toTOTPResourceViewModels(using: resourcesOTPController)

          updateState { (viewState: inout ViewState) in
            viewState.otpResources = otpResources
            viewState.hasMoreData = otpResources.count >= context.pageSize
            viewState.isLoadingMore = false
            if viewState.lastFilterText != filter.text {
              viewState.contentResetToken += 1
            }
            viewState.lastFilterText = filter.text
          }
        }
        catch {
          error.consume()
        }
      }
    )
  }

  @MainActor @Sendable internal final func loadMore() async {

    let currentState: ViewState = await viewState.current
    let hasMore: Bool = currentState.hasMoreData
    let isLoading: Bool = currentState.isLoadingMore

    guard hasMore, !isLoading else { return }

    self.viewState.update { (state: inout ViewState) in
      state.isLoadingMore = true
    }

    do {
      let pageSize: Int = context.pageSize
      let filterText: String = self.searchController.searchText.value
      let expectedOffset: Int = currentState.otpResources.count
      var filter: ResourcesFilter = .init(sorting: .nameAlphabetically, otpOnly: true)
      filter.text = filterText
      filter.limit = pageSize
      filter.offset = expectedOffset

      let nextPageResources: Array<ResourceListItemDSV> = try await self.resources.filteredResourcesList(filter)

      self.viewState.update { (state: inout ViewState) in
        // Discard the page if a filter update or refresh reset the list mid-flight.
        guard state.lastFilterText == filterText, state.otpResources.count == expectedOffset
        else {
          state.isLoadingMore = false
          return
        }
        state.otpResources.append(contentsOf: nextPageResources.toTOTPResourceViewModels(using: resourcesOTPController))
        state.hasMoreData = nextPageResources.count >= pageSize
        state.isLoadingMore = false
      }
    }
    catch {
      error.consume(context: "Failed to load more resources.")
      self.viewState.update { (state: inout ViewState) in
        state.isLoadingMore = false
      }
    }
  }
}

extension OTPResourcesListViewController {

  @Sendable internal func refreshList() async {
    await consumingErrors {
      try await self.sessionData.refreshIfNeeded()
    }
  }

  internal var createOTPAction: (@Sendable () async -> Void)? {
    self.createAvailable ? self.createOTP : .none
  }

  private func createOTP() async {
    await consumingErrors {
      let metadataTypeSettings: MetadataSettingsService = try await self.features.instance()
      let totpType: ResourceSpecification.Slug =
        metadataTypeSettings.typesSettings().defaultResourceTypes == .v5
        ? .v5StandaloneTOTP
        : .totp
      let editingContext: ResourceEditingContext = try await resourceEditPreparation.prepareNew(totpType, .none, .none)
      guard
        let resourceType: ResourceType = editingContext.availableTypes.first(where: {
          $0.specification.slug == totpType
        }),
        let totpPath: ResourceType.FieldPath = resourceType.fieldSpecification(for: \.firstTOTP)?.path
      else {
        return
      }
      let features: Features = try await self.features.branchIfNeeded(
        scope: ResourceEditScope.self,
        context: editingContext
      )
      let navigationToOTPScanning: NavigationToOTPScanning = try await features.instance()
      await navigationToOTPScanning.performCatching(
        context: .init(
          totpPath: totpPath
        )
      )
    }
  }

  @discardableResult
  private func revealOTP(
    for resourceID: Resource.ID
  ) async throws -> OTPValue {
    try await self.resourcesOTPController.revealOTP(resourceID)
  }

  private func copyOTP(
    _ value: OTPValue
  ) async throws {
    pasteboard.putWithAutoExpiration(value.otp.rawValue)
    SnackBarMessageEvent.send("otp.value.copied.message")
  }

  internal func revealAndCopyOTP(
    for resourceID: Resource.ID
  ) async {
    await consumingErrors(
      errorDiagnostics: "Failed to reveal or copy OTP."
    ) {
      try await self.copyOTP(self.revealOTP(for: resourceID))
    }
  }

  internal func showContextualMenu(
    for resourceID: Resource.ID
  ) async {
    await consumingErrors(
      errorDiagnostics: "Failed to navigate to OTP contextual menu."
    ) {
      await self.hideOTPCodes()
      let features: Features =
        try await features.branchIfNeeded(
          scope: ResourceScope.self,
          context: resourceID
        )
      let navigationToContextualMenu: NavigationToResourceOTPContextualMenu = try await features.instance()
      try await navigationToContextualMenu.perform(
        context: .init(
          revealOTP: { [self] in
            await consumingErrors(
              errorDiagnostics: "Failed to reveal OTP."
            ) {
              try await self.revealOTP(for: resourceID)
            }
          },
          // Only the identifier is captured, like the reveal action above - the branched container stays with this
          // presentation instead of being kept alive by the menu and the alert it opens.
          deleteOTP: { [weak self] in
            await self?.deleteOTP(for: resourceID)
          }
        )
      )
    }
  }

  /// Removes the TOTP from a resource, from the OTP list contextual menu.
  ///
  /// A standalone TOTP is the resource, so removing it deletes the resource - nothing is re-encrypted and there is
  /// nothing to confirm. Detaching it from a resource that also holds a password changes the resource type, which
  /// reshapes the secret and re-encrypts it for every recipient, so a shared resource goes through the permission
  /// confirmation first.
  @MainActor private func deleteOTP(
    for resourceID: Resource.ID
  ) async {
    await consumingErrors(
      errorDiagnostics: "Failed to delete OTP."
    ) {
      let features: Features =
        try await self.features.branchIfNeeded(
          scope: ResourceScope.self,
          context: resourceID
        )
      let resourceController: ResourceController = try await features.instance()
      let resource: Resource = try await resourceController.state.value

      if ResourceSpecification.Slug.standaloneTOTPTypes.contains(resource.type.specification.slug) {
        // for standalone TOTP we delete the resource
        try await resourceController.delete()
        SnackBarMessageEvent.send("otp.edit.otp.deleted.message")
      }
      else if let detachedOTPSlug: ResourceSpecification.Slug = resource.detachedOTPSlug {
        let editingContext: ResourceEditingContext =
          try await self.resourceEditPreparation.prepareExisting(resourceID)

        guard
          let detachedType: ResourceType = editingContext.availableTypes.first(
            where: { (type: ResourceType) -> Bool in
              type.specification.slug == detachedOTPSlug
            }
          )
        else {
          throw
            InvalidResourceTypeError
            .error(message: "Attempting to detach OTP from a resource which has none or unavailable detached type!")
        }

        let editingFeatures: Features =
          try await features.branchIfNeeded(
            scope: ResourceEditScope.self,
            context: editingContext
          )

        let resourceEditForm: ResourceEditForm = try await editingFeatures.instance()
        try resourceEditForm.updateType(detachedType)

        // Validated before the confirmation is offered - reviewing recipients only to be told the form is invalid
        // would be reviewing them for nothing.
        try await resourceEditForm.validateForm()

        // Editing a shared resource interposes the confirmation screen; that path runs the edit on confirm, so
        // return early when it takes over.
        if try await self.presentConfirmationIfNeeded(
          features: editingFeatures,
          resourceID: resourceID
        ) {
          return
        }

        do {
          try await resourceEditForm.send()
          await self.finishDeletion()
        }
        catch let error as MetadataPinnedKeyValidationError {
          // Same offer as on the confirmed path - a rotated key is trusted and the deletion retried, rather than
          // leaving the operator with an error they cannot act on.
          await self.navigateToMetadataPinnedKeyValidation(for: resourceID, reason: error.reason)
        }
      }
      else {
        throw
          InvalidResourceTypeError
          .error(message: "Attempting to delete OTP in a resource without OTP delete action supported!")
      }
    }
  }

  /// Presents the permission confirmation when the detach calls for it, retaining the flow - and with it the
  /// editing scope branched for the resource - for as long as the confirmation may be on screen.
  ///
  /// A flow from an earlier attempt is reused rather than replaced, but only while its confirmation screen is still
  /// displayed and only for the resource it was built for: trusting a rotated metadata key runs this deletion again
  /// from the start, and that screen confirms into the flow it was opened with. Replacing it would release the
  /// branched scope behind the displayed screen and leave its confirm button reporting a failure.
  ///
  /// Otherwise the flow is dropped and this deletion builds its own - once the operator left the confirmation they
  /// are free to open the menu of another resource, and a reused flow would confirm the recipients of the previous
  /// one and detach its TOTP.
  @MainActor private func presentConfirmationIfNeeded(
    features: Features,
    resourceID: Resource.ID
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
        await self?.finishDeletion()
      },
      onInvalidMetadataKey: { [weak self] (reason: MetadataPinnedKeyValidationError.Reason) in
        await self?.navigateToMetadataPinnedKeyValidation(for: resourceID, reason: reason)
      },
      onCancelled: { [weak self, weak permissionConfirmation] in
        // Backing out leaves nothing to resume, so the flow - and the editing scope it owns, holding the decrypted
        // secret - goes now rather than at the next deletion. Identity checked so a cancel can only ever drop the
        // flow it belongs to.
        guard let flow: ResourceEditPermissionConfirmation = permissionConfirmation,
          self?.permissionConfirmation?.flow === flow
        else { return }
        self?.permissionConfirmation = .none
      }
    )
    // Retained only while its screen may be displayed - otherwise the branched scope would outlive the deletion it
    // was created for. Cancelling releases it through `onCancelled`; this covers leaving the screen any other way,
    // which reports no cancellation. A flow whose screen is still up is never dropped, even by a deletion that did
    // not take it over: the presented screen holds nothing but a weak reference back to it, so releasing it here
    // would leave its confirm button reporting a failure.
    if takenOver {
      self.permissionConfirmation = .init(resourceID: resourceID, flow: permissionConfirmation)
    }
    else if ongoingDisplayed == false {
      self.permissionConfirmation = .none
    }
    return takenOver
  }

  /// Releases a confirmation flow whose screen is no longer displayed.
  ///
  /// The flow owns the editing scope branched for its deletion, which holds the decrypted secret, so it may not
  /// outlive the screen it was created for. `onCancelled` covers the cancel button - the only way out of the
  /// confirmation that reports a cancellation - and the next deletion covers the rest, but this list is a tab that
  /// lives for the whole session: a confirmation left by a back gesture would otherwise keep a decrypted secret in
  /// memory until the operator happens to delete another TOTP, or until they sign out.
  ///
  /// A flow whose screen is still up is never dropped - the screen holds nothing but a weak reference back to it,
  /// so releasing it would leave its confirm button reporting a failure. Only a definite "not displayed" releases
  /// the flow; a flow that cannot be asked is kept for the next checkpoint.
  @MainActor private func releaseAbandonedConfirmation() {
    guard let ongoing: OngoingConfirmation = self.permissionConfirmation,
      let displayed: Bool = try? ongoing.flow.isConfirmationDisplayed(),
      displayed == false
    else { return }
    self.permissionConfirmation = .none
  }

  /// Reports a removed TOTP. The list is the screen the deletion was started from and the confirmation pops itself,
  /// so there is no navigation to perform here.
  @MainActor private func finishDeletion() async {
    self.permissionConfirmation = .none
    SnackBarMessageEvent.send("otp.edit.otp.deleted.message")
  }

  @MainActor private func navigateToMetadataPinnedKeyValidation(
    for resourceID: Resource.ID,
    reason: MetadataPinnedKeyValidationError.Reason
  ) async {
    await presentMetadataPinnedKeyValidation(
      features: self.features,
      reason: reason,
      onTrustedKey: { [weak self] in await self?.deleteOTP(for: resourceID) }
    )
  }

  internal func hideOTPCodes() {
    // Leaving the list and opening a contextual menu on it both pass through here - the checkpoints at which a
    // confirmation the operator left without cancelling is noticed and released.
    self.releaseAbandonedConfirmation()
    self.resourcesOTPController.hideOTP()
  }
}

internal struct TOTPResourceViewModel {

  internal var id: Resource.ID
  internal var name: String
  internal var isExpired: Bool
  internal var icon: ResourceIcon
  internal var resourceTypeSlug: ResourceSpecification.Slug?
  internal var generateOTP: @Sendable () async -> OTPValue?

  internal init(
    id: Resource.ID,
    name: String,
    isExpired: Bool,
    icon: ResourceIcon,
    resourceTypeSlug: ResourceSpecification.Slug?,
    generateOTP: @Sendable @escaping () async -> OTPValue?
  ) {
    self.id = id
    self.name = name
    self.isExpired = isExpired
    self.icon = icon
    self.resourceTypeSlug = resourceTypeSlug
    self.generateOTP = generateOTP
  }
}

extension TOTPResourceViewModel: Equatable {

  internal static func == (
    _ lhs: TOTPResourceViewModel,
    _ rhs: TOTPResourceViewModel
  ) -> Bool {
    lhs.id == rhs.id
      && lhs.name == rhs.name
  }
}

extension TOTPResourceViewModel: Identifiable {}

extension Array where Element == ResourceListItemDSV {

  fileprivate func toTOTPResourceViewModels(
    using resourcesOTPController: ResourcesOTPController
  ) -> Array<TOTPResourceViewModel> {
    var list: Array<TOTPResourceViewModel> = .init()

    for item in self {
      let otpIterator: UncheckedSendableBox<AnyAsyncIterator<OTPValue?>> = .init(
        resourcesOTPController
          .currentOTP
          .asAnyAsyncSequence()
          .map { (update: Update<OTPValue>) -> OTPValue? in
            if let otp: OTPValue = try? update.value, otp.resourceID == item.id {
              return otp
            }
            else {
              return .none
            }
          }
          .removeDuplicates()
          .makeAsyncIterator()
          .asAnyAsyncIterator()
      )
      list.append(
        .init(
          id: item.id,
          name: item.name,
          isExpired: item.isExpired,
          icon: item.icon,
          resourceTypeSlug: item.typeInfo.typeSlug,
          generateOTP: { () async -> OTPValue? in
            (try? await otpIterator.value.next())?.flatMap { $0 }
          }
        )
      )
    }

    return list
  }
}
