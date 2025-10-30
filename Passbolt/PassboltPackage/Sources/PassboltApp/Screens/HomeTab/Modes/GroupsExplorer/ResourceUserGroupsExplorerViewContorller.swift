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
import Resources
import Session
import SessionData
import SharedUIComponents
import Users

internal final class ResourceUserGroupsExplorerViewContorller: ViewController {

  internal typealias Context = ResourceUserGroupListItemDSV?

  internal struct ViewState: Equatable {
    internal var title: DisplayableString
    internal var groupID: UserGroup.ID?
    internal var groups: Array<ResourceUserGroupListItemDSV> = .init()
    internal var resources: Array<ResourceListItemDSV> = .init()
  }

  internal nonisolated let viewState: ViewStateSource<ViewState>

  internal let searchController: ResourceSearchDisplayController

  fileprivate let features: Features
  fileprivate let sessionData: SessionData

  fileprivate let navigationToResourceDetails: NavigationToResourceDetails
  fileprivate let navigationToGroupContent: NavigationToGroupContent

  internal init(context: Context, features: Features) throws {
    self.features = features
    self.sessionData = try features.instance()
    self.navigationToResourceDetails = try features.instance()
    self.navigationToGroupContent = try features.instance()

    let navigationToAccountMenu: NavigationToAccountMenu = try features.instance()
    let navigationToHomePresentationMenu: NavigationToHomePresentationMenu = try features.instance()

    self.searchController = try features.instance(
      context: .init(
        searchPrompt: .localized(key: "resources.search.placeholder"),
        onPresentationMenuTap: {
          await consumingErrors {
            try await navigationToHomePresentationMenu.perform()
          }
        },
        onAvatarTap: {
          await consumingErrors {
            try await navigationToAccountMenu.perform()
          }
        }
      )
    )

    if let userGroup = context {
      let resources: ResourcesController = try features.instance()

      self.viewState = .init(
        initial: .init(
          title: .raw(userGroup.name),
          groupID: userGroup.id
        ),
        updateFrom: ComputedVariable(combined: resources.lastUpdate, with: searchController.searchText),
        update: { updateState, updates in
          let filter: ResourcesFilter = .init(
            sorting: .nameAlphabetically,
            text: try updates.value.1,
            userGroups: [userGroup.id]
          )
          let resources: Array<ResourceListItemDSV> = try await resources.filteredResourcesList(filter)
          updateState { state in
            state.resources = resources
          }
        }
      )
    }
    else {

      let userGroups: UserGroups = try features.instance()
      let session: Session = try features.instance()
      self.viewState = .init(
        initial: .init(
          title: .localized(key: "home.presentation.mode.resource.user.groups.explorer.title")
        ),
        updateFrom: ComputedVariable(combined: sessionData.lastUpdate, with: searchController.searchText),
        update: { updateState, updates in
          let searchText: String = try updates.value.1
          let userId: User.ID = try await session.currentAccount().userID
          let userGroups: Array<ResourceUserGroupListItemDSV> =
            try await userGroups
            .filteredResourceUserGroups(.init(userID: userId, text: searchText))

          updateState { state in
            state.groups = userGroups
          }
        }
      )
    }
  }
}

extension ResourceUserGroupsExplorerViewContorller {

  func refreshIfNeeded() async {
    await consumingErrors {
      try await sessionData
        .refreshIfNeeded()
    }
  }

  func presentGroupContent(_ userGroup: ResourceUserGroupListItemDSV) async {
    await consumingErrors {
      try await navigationToGroupContent
        .perform(context: userGroup)
    }
  }

  func presentResourceDetails(_ resourceID: Resource.ID) async {
    await consumingErrors {
      try await navigationToResourceDetails
        .perform(context: resourceID)
    }
  }

  func presentResourceMenu(_ resourceID: Resource.ID) async {
    await consumingErrors {
      let features: Features =
        try self.features
        .branchIfNeeded(
          scope: ResourceScope.self,
          context: resourceID
        )

      let navigationToResourceContextualMenu: NavigationToResourceContextualMenu = try features.instance()
      try await navigationToResourceContextualMenu.perform(
        context: .init()
      )
    }
  }
}
