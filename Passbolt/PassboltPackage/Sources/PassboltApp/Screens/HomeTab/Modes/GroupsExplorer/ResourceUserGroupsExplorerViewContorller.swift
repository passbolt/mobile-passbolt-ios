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
    internal var isLoadingMore: Bool = false
    internal var hasMoreData: Bool = true
    internal var contentResetToken: Int = 0
    internal var lastFilterText: String = ""
  }

  internal nonisolated let viewState: ViewStateSource<ViewState>
  internal nonisolated let refreshIndicatorSource: AnyUpdatable<Bool>

  internal let searchController: ResourceSearchDisplayController

  fileprivate let features: Features
  fileprivate let sessionData: SessionData
  fileprivate let pageSize: Int = 50

  fileprivate let navigationToResourceDetails: NavigationToResourceDetails
  fileprivate let navigationToGroupContent: NavigationToGroupContent

  // Controller operates in two modes based on initialization context:
  // - Groups list mode: userGroupsFeature and sessionFeature are set, others are nil
  // - Group content mode: resourcesFeature and currentUserGroup are set, others are nil
  fileprivate var userGroupsFeature: UserGroups?
  fileprivate var resourcesFeature: ResourcesController?
  fileprivate var sessionFeature: Session?
  fileprivate var currentUserGroup: ResourceUserGroupListItemDSV?

  internal init(context: Context, features: Features) throws {
    self.features = features
    self.sessionData = try features.instance()
    self.refreshIndicatorSource = self.sessionData.isRefreshing
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

    if let userGroup: ResourceUserGroupListItemDSV = context {
      self.currentUserGroup = userGroup
      let resources: ResourcesController = try features.instance()
      self.resourcesFeature = resources
      let pageSize: Int = self.pageSize

      self.viewState = .init(
        initial: .init(
          title: .raw(userGroup.name),
          groupID: userGroup.id,
          isLoadingMore: false,
          hasMoreData: true
        ),
        updateFrom: ComputedVariable(combined: resources.lastUpdate, with: searchController.searchText),
        update: { updateState, updates in
          let filter: ResourcesFilter = .init(
            sorting: .nameAlphabetically,
            text: try updates.value.1,
            userGroups: [userGroup.id],
            limit: pageSize,
            offset: 0
          )
          let resources: Array<ResourceListItemDSV> = try await resources.filteredResourcesList(filter)
          updateState { state in
            state.resources = resources
            state.hasMoreData = resources.count >= pageSize
            state.isLoadingMore = false
            if state.lastFilterText != filter.text {
              state.contentResetToken += 1
            }
            state.lastFilterText = filter.text
          }
        }
      )
    }
    else {
      let userGroups: UserGroups = try features.instance()
      let session: Session = try features.instance()
      self.userGroupsFeature = userGroups
      self.sessionFeature = session
      let pageSize: Int = self.pageSize

      self.viewState = .init(
        initial: .init(
          title: .localized(key: "home.presentation.mode.resource.user.groups.explorer.title"),
          isLoadingMore: false,
          hasMoreData: true
        ),
        updateFrom: ComputedVariable(combined: sessionData.lastUpdate, with: searchController.searchText),
        update: { updateState, updates in
          let searchText: String = try updates.value.1
          let userId: User.ID = try await session.currentAccount().userID
          let userGroups: Array<ResourceUserGroupListItemDSV> =
            try await userGroups
            .filteredResourceUserGroups(
              .init(
                userID: userId,
                text: searchText,
                limit: pageSize,
                offset: 0
              )
            )

          updateState { state in
            state.groups = userGroups
            state.hasMoreData = userGroups.count >= pageSize
            state.isLoadingMore = false
            if state.lastFilterText != searchText {
              state.contentResetToken += 1
            }
            state.lastFilterText = searchText
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

  @MainActor func loadMore() async {
    let currentState: ViewState = await viewState.current
    let hasMore: Bool = currentState.hasMoreData
    let isLoading: Bool = currentState.isLoadingMore

    guard hasMore, !isLoading else { return }

    self.viewState.update { state in
      state.isLoadingMore = true
    }

    if currentState.groupID != nil {
      // Loading more resources within a group
      do {
        guard
          let resources: ResourcesController = self.resourcesFeature,
          let userGroup: ResourceUserGroupListItemDSV = self.currentUserGroup
        else { return }

        let searchText: String = self.searchController.searchText.value
        let filter: ResourcesFilter = .init(
          sorting: .nameAlphabetically,
          text: searchText,
          userGroups: [userGroup.id],
          limit: self.pageSize,
          offset: currentState.resources.count
        )
        let nextPageResources: Array<ResourceListItemDSV> = try await resources.filteredResourcesList(filter)

        self.viewState.update { state in
          state.resources.append(contentsOf: nextPageResources)
          state.hasMoreData = nextPageResources.count >= self.pageSize
          state.isLoadingMore = false
        }
      }
      catch {
        error.consume(context: "Failed to load more resources.")
        self.viewState.update { state in
          state.isLoadingMore = false
        }
      }
    }
    else {
      // Loading more groups
      do {
        guard
          let userGroups: UserGroups = self.userGroupsFeature,
          let session: Session = self.sessionFeature
        else { return }

        let searchText: String = self.searchController.searchText.value
        let userId: User.ID = try await session.currentAccount().userID
        let nextPageGroups: Array<ResourceUserGroupListItemDSV> =
          try await userGroups
          .filteredResourceUserGroups(
            .init(
              userID: userId,
              text: searchText,
              limit: self.pageSize,
              offset: currentState.groups.count
            )
          )

        self.viewState.update { state in
          state.groups.append(contentsOf: nextPageGroups)
          state.hasMoreData = nextPageGroups.count >= self.pageSize
          state.isLoadingMore = false
        }
      }
      catch {
        error.consume(context: "Failed to load more groups.")
        self.viewState.update { state in
          state.isLoadingMore = false
        }
      }
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
        try await self.features
        .branchIfNeeded(
          scope: ResourceScope.self,
          context: resourceID
        )

      let navigationToResourceContextualMenu: NavigationToResourceContextualMenu = try await features.instance()
      try await navigationToResourceContextualMenu.perform(
        context: .init()
      )
    }
  }
}
