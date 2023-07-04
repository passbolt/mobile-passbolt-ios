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

internal final class TOTPAttachSelectionListViewController: ViewController {

  public struct Context {

    public var totpSecret: TOTPSecret

    public init(
      totpSecret: TOTPSecret
    ) {
      self.totpSecret = totpSecret
    }
  }

  internal struct ViewState: Equatable {

    internal enum Confirmation {
      case attach
      case replace
    }

    internal var searchText: String
    internal var listItems: Array<TOTPAttachSelectionListItemViewModel>
    internal var confirmationAlert: Confirmation?
    internal var snackBarMessage: SnackBarMessage?
  }

  internal let viewState: ViewStateSource<ViewState>

  private struct LocalState: Equatable {
    fileprivate static func == (
      _ lhs: TOTPAttachSelectionListViewController.LocalState,
      _ rhs: TOTPAttachSelectionListViewController.LocalState
    ) -> Bool {
      lhs.selected?.id == rhs.selected?.id
        && lhs.selected?.slug == rhs.selected?.slug
    }

    fileprivate var selected: (id: Resource.ID, slug: ResourceSpecification.Slug)?
  }

  private let localState: Variable<LocalState>

  private let resourceSearchController: ResourceSearchController
  private let resourceEditPreparation: ResourceEditPreparation

  private let navigationToOTPResourcesList: NavigationToOTPResourcesList

  private let totpSecret: TOTPSecret

  private let features: Features

  internal init(
    context: Context,
    features: Features
  ) throws {
    try features.ensureScope(SessionScope.self)

    self.features = features

    self.totpSecret = context.totpSecret

    self.navigationToOTPResourcesList = try features.instance()

    self.resourceSearchController = try features.instance(
      context: .init(
        text: .init(),
        includedTypes: .init()
      )
    )
    self.resourceEditPreparation = try features.instance()

    self.localState = .init(
      initial: .init(
        selected: .none
      )
    )
    self.viewState = .init(
      initial: .init(
        searchText: .init(),
        listItems: .init(),
        snackBarMessage: .none
      ),
      updateFrom: ComputedVariable(
        combining: self.resourceSearchController.state,
        and: self.localState,
        combine: { (search: ResourceSearchState, local: LocalState) async throws -> ViewState in
          return ViewState(
            searchText: search.filter.text,
            listItems: search.result.map { item -> TOTPAttachSelectionListItemViewModel in
              .init(
                id: item.id,
                typeSlug: item.typeSlug,
                name: item.name,
                username: item.username,
                state: local.selected?.id == item.id
                  ? .selected
                  : [  // precise what types are allowed to attach OTP to
                    ResourceSpecification.Slug.passwordWithTOTP,
                    .passwordWithDescription,
                    .totp,
                  ]
                  .contains(item.typeSlug)
                    ? .none
                    : .notAllowed
              )
            }
          )
        }
      ),
      fallback: { (state: inout ViewState, error: Error) async in
        state.snackBarMessage = .error(error)
      }
    )
  }
}

extension TOTPAttachSelectionListViewController {

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
    self.localState.selected = (
      id: item.id,
      slug: item.typeSlug
    )
  }

  @MainActor internal func trySendForm() async {
    await withLogCatch(
      fallback: { [viewState] (error: Error) in
        viewState.update(\.snackBarMessage, to: .error(error))
      }
    ) {
      guard let selected: (id: Resource.ID, slug: ResourceSpecification.Slug) = self.localState.selected
      else {
        throw
          InvalidForm
          .error(displayable: "resource.form.error.invalid")
      }

      let availableTypes = try await self.resourceEditPreparation.availableTypes()

      guard
        let currentType: ResourceType = availableTypes.first(where: { $0.specification.slug == selected.slug }),
        !currentType.containsUndefinedFields
      else {
        throw
          InvalidResourceType
          .error(message: "Attempting to edit a resource with unknown type")
      }

      switch selected.slug {
      case .passwordWithDescription:
        if availableTypes.contains(where: { $0.specification.slug == .passwordWithTOTP }) {
          self.viewState.update(\.confirmationAlert, to: .attach)
        }
        else {
          throw
            InvalidResourceType
            .error(message: "Upgrade type with attached OTP is not available!")
        }

      case _:
        if currentType.contains(\.firstTOTP) {
          // keep current type and update its otp
          self.viewState.update(\.confirmationAlert, to: .replace)
        }
        else {
          throw
            InvalidResourceType
            .error(message: "Upgrade type with attached OTP is not available!")
        }
      }
    }
  }

  @MainActor internal func sendForm() async {
    await withLogCatch(
      fallback: { [viewState] (error: Error) in
        viewState.update(\.snackBarMessage, to: .error(error))
      }
    ) {
      guard let selected: (id: Resource.ID, slug: ResourceSpecification.Slug) = self.localState.selected
      else {
        throw
          InvalidForm
          .error(displayable: "resource.form.error.invalid")
      }

      let editingContext: ResourceEditingContext = try await self.resourceEditPreparation.prepareExisting(selected.id)

      guard
        let currentType: ResourceType = editingContext.availableTypes.first(where: {
          $0.specification.slug == selected.slug
        }),
        !currentType.containsUndefinedFields
      else {
        throw
          InvalidResourceType
          .error(message: "Attempting to edit a resource with unknown type")
      }

      let features: Features = self.features.branch(
        scope: ResourceEditScope.self,
        context: editingContext
      )

      let resourceEditForm: ResourceEditForm = try features.instance()

      switch selected.slug {
      case .passwordWithDescription:
        guard
          let updatedType: ResourceType = editingContext.availableTypes.first(where: {
            $0.specification.slug == .passwordWithTOTP
          })
        else {
          throw
            InvalidResourceType
            .error(message: "Upgrade type with attached OTP is not available!")
        }
        try resourceEditForm.updateType(updatedType)

      case _:
        if currentType.contains(\.firstTOTP) {
          break  // keep current type and update its otp
        }
        else {
          throw
            InvalidResourceType
            .error(message: "Upgrade type with attached OTP is not available!")
        }
      }

      resourceEditForm.update(\.firstTOTP, to: self.totpSecret)

      _ = try await resourceEditForm.sendForm()
      await navigationToOTPResourcesList.performCatching()
    }
  }
}

internal struct TOTPAttachSelectionListItemViewModel: Equatable, Identifiable {

  internal enum State: Equatable {
    case none
    case selected
    case notAllowed

    internal var selected: Bool {
      switch self {
      case .none:
        return false

      case .selected:
        return true

      case .notAllowed:
        return false
      }
    }

    internal var disabled: Bool {
      switch self {
      case .none:
        return false

      case .selected:
        return false

      case .notAllowed:
        return true
      }
    }
  }

  internal let id: Resource.ID
  internal var typeSlug: ResourceSpecification.Slug
  internal var name: String
  internal var username: String?
  internal var state: State
}
