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

import Display
import FeatureScopes
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
    consumingErrors {
      guard let selected: SelectedItem = self.localState.value.selected
      else {
        throw
          InvalidForm
          .error(displayable: "resource.form.error.invalid")
      }

      if selected.typeInfo.type.contains(\.firstTOTP) {
        self.viewState.update(\.confirmationAlert, to: .replace)
      }
      else {
        self.viewState.update(\.confirmationAlert, to: .attach)
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

      let features: Features = try self.features.branch(
        scope: ResourceEditScope.self,
        context: editingContext
      )

      let resourceEditForm: ResourceEditForm = try features.instance()

      if attachedOTPType != selected.typeInfo.type {
        try resourceEditForm.updateType(attachedOTPType)
      }  // else keep current type

      resourceEditForm.update(\.firstTOTP, to: self.context.totpSecret)

      try await resourceEditForm.send()
      try await navigationToOTPScanning.revert()
      SnackBarMessageEvent.send(
        editingContext.editedResource.isLocal || !editingContext.editedResource.hasTOTP
          ? "otp.edit.otp.created.message"
          : "otp.edit.otp.replaced.message"
      )
    }
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
