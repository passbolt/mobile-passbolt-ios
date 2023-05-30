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

import Accounts
import Display
import OSFeatures
import Resources
import Session
import SessionData
import SharedUIComponents
import UIComponents
import Users

@MainActor
internal struct ResourceUserGroupsExplorerController {

  internal let viewState: ObservableValue<ViewState>
  internal var refreshIfNeeded: @MainActor () async -> Void
  internal var presentGroupContent: @MainActor (ResourceUserGroupListItemDSV) -> Void
  internal var presentResourceCreationFrom: @MainActor () -> Void
  internal var presentResourceDetails: @MainActor (Resource.ID) -> Void
  internal var presentResourceMenu: @MainActor (Resource.ID) -> Void
  internal var presentHomePresentationMenu: @MainActor () -> Void
  internal var presentAccountMenu: @MainActor () -> Void
}

extension ResourceUserGroupsExplorerController: ComponentController {

  internal typealias ControlledView = ResourceUserGroupsExplorerView
  internal typealias Context = ResourceUserGroupListItemDSV?

  @MainActor internal static func instance(
    in context: Context,
    with features: inout Features,
    cancellables: Cancellables
  ) throws -> Self {
    let features: Features = features
    let currentAccount: Account = try features.sessionAccount()

    let diagnostics: OSDiagnostics = features.instance()
    let asyncExecutor: AsyncExecutor = try features.instance()

    let navigationToAccountMenu: NavigationToAccountMenu = try features.instance()

    let navigation: DisplayNavigation = try features.instance()
    let accountDetails: AccountDetails = try features.instance(context: currentAccount)
    let resources: ResourcesController = try features.instance()
    let userGroups: UserGroups = try features.instance()
    let sessionData: SessionData = try features.instance()
    let navigationToResourceDetails: NavigationToResourceDetails = try features.instance()

    let viewState: ObservableValue<ViewState>

    if let userGroup: ResourceUserGroupListItemDSV = context {
      viewState = .init(
        initial: .init(
          title: .raw(userGroup.name),
          groupID: userGroup.id,
          // temporarily disable create for groups
          canCreateResources: false
        )
      )

      // refresh the list based on filters data
      cancellables.executeOnMainActor {
        let filterSequence: AnyAsyncSequence<ResourcesFilter> =
          viewState
          .valuePublisher
          .map { filter in
            ResourcesFilter(
              sorting: .nameAlphabetically,
              text: filter.searchText,
              userGroups: [userGroup.id]
            )
          }
          .removeDuplicates()
          .asAnyAsyncSequence()

        try await combineLatest(filterSequence, resources.lastUpdate)
          .map { (filter, _) in
            try await resources.filteredResourcesList(filter)
          }
          .forEach { resourcesList in
            await viewState.withValue { state in
              state.resources = resourcesList
            }
          }
      }
    }
    else {
      viewState = .init(
        initial: .init(
          title: .localized(key: "home.presentation.mode.resource.user.groups.explorer.title"),
          canCreateResources: false
        )
      )

      // refresh the list based on filters data
      cancellables.executeOnMainActor {
        let filterSequence: AnyAsyncSequence<String> =
          viewState
          .valuePublisher
          .map(\.searchText)
          .removeDuplicates()
          .asAnyAsyncSequence()

        try await userGroups
          .filteredResourceUserGroupList(filterSequence)
          .forEach { groupsList in
            await viewState.withValue { state in
              state.groups = groupsList
            }
          }
      }
    }

    // get the the user avatar image
    cancellables.executeOnMainActor {
      // ignore errors on getting avatar
      viewState.userAvatarImage =
        try? await accountDetails
        .avatarImage()
    }

    @MainActor func refreshIfNeeded() async {
      do {
        try await sessionData
          .refreshIfNeeded()
      }
      catch {
        diagnostics.log(error: error)
        viewState.snackBarMessage = .error(error.asTheError().displayableMessage)
      }
    }

    @MainActor func presentGroupContent(_ userGroup: ResourceUserGroupListItemDSV) {
      cancellables.executeOnMainActor {
        await navigation.push(
          legacy: ResourceUserGroupsExplorerView.self,
          context: userGroup
        )
      }
    }

    @MainActor func presentResourceCreationFrom() {
      presentResourceEditingForm(for: .create(folderID: .none, uri: .none))
    }

    @MainActor func presentResourceShareForm(
      for resourceID: Resource.ID
    ) {
      cancellables.executeOnMainActor {
        await navigation.push(
          legacy: ResourcePermissionEditListView.self,
          context: resourceID
        )
      }
    }

    @MainActor func presentResourceEditingForm(
      for context: ResourceEditScope.Context
    ) {
      cancellables.executeOnMainActor {
        await navigation.push(
          legacy: ResourceEditViewController.self,
          context: (
            context,
            completion: { _ in
              viewState.snackBarMessage = .info(
                .localized(
                  key: "resource.form.new.password.created"
                )
              )
            }
          )
        )
      }
    }

    @MainActor func presentResourceDetails(_ resourceID: Resource.ID) {
      cancellables.executeOnMainActor {
        try await navigationToResourceDetails
          .perform(context: resourceID)
      }
    }

    @MainActor func presentResourceMenu(_ resourceID: Resource.ID) {
      cancellables.executeOnMainActor {
				let features: Features = features
					.branchIfNeeded(
						scope: ResourceDetailsScope.self,
						context: resourceID
					)
					?? features
        let navigationToResourceContextualMenu: NavigationToResourceContextualMenu = try features.instance()
        try await navigationToResourceContextualMenu.perform(
          context: .init(
            showMessage: { (message: SnackBarMessage?) in
              viewState.snackBarMessage = message
            }
          )
        )
      }
    }

    @MainActor func presentHomePresentationMenu() {
      cancellables.executeOnMainActor {
        await navigation.presentSheet(
          HomePresentationMenuView.self,
          in: .foldersExplorer
        )
      }
    }

    @MainActor func presentAccountMenu() {
      asyncExecutor.schedule(.reuse) {
        await diagnostics
          .withLogCatch(
            info: .message(
              "Navigation to account menu failed!"
            )
          ) {
            try await navigationToAccountMenu.perform()
          }
      }
    }

    return Self(
      viewState: viewState,
      refreshIfNeeded: refreshIfNeeded,
      presentGroupContent: presentGroupContent(_:),
      presentResourceCreationFrom: presentResourceCreationFrom,
      presentResourceDetails: presentResourceDetails(_:),
      presentResourceMenu: presentResourceMenu(_:),
      presentHomePresentationMenu: presentHomePresentationMenu,
      presentAccountMenu: presentAccountMenu
    )
  }
}
