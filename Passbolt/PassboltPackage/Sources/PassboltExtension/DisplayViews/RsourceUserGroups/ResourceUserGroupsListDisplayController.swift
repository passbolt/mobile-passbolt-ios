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
import SessionData
import Users

internal final class ResourceUserGroupsListDisplayController: ViewController {

  internal nonisolated let viewState: ViewStateSource<ViewState>

  private let sessionData: SessionData
  private let userGroups: UserGroups

  private let context: Context
  private let features: Features

  internal init(
    context: Context,
    features: Features
  ) throws {
    try features.ensureScope(SessionScope.self)

    self.context = context
    self.features = features

    self.sessionData = try features.instance()
    self.userGroups = try features.instance()

    let pageSize: Int = context.pageSize

    self.viewState = .init(
      initial: .init(
        userGroups: .init(),
        isLoadingMore: false,
        hasMoreData: true,
        contentResetToken: 0,
        lastFilterText: ""
      ),
      updateFrom: ComputedVariable(
        combined: context.filter,
        with: self.sessionData.lastUpdate
      ),

      update: { [userGroups] (updateView, update) in
        await consumingErrors {
          let filter: UserGroupsFilter = try update.value.0
          let filteredUserGroups: Array<ResourceUserGroupListItemDSV> = try await userGroups.filteredResourceUserGroups(
            .init(
              userID: filter.userID,
              text: filter.text,
              limit: pageSize,
              offset: 0
            )
          )

          updateView { viewState in
            viewState.userGroups = filteredUserGroups
            viewState.hasMoreData = filteredUserGroups.count >= pageSize
            viewState.isLoadingMore = false
            if viewState.lastFilterText != filter.text {
              viewState.contentResetToken += 1
            }
            viewState.lastFilterText = filter.text
          }
        }
      }
    )
  }
}

extension ResourceUserGroupsListDisplayController {

  internal struct Context {

    internal var filter: AnyUpdatable<UserGroupsFilter>
    internal var selectGroup: (UserGroup.ID) async throws -> Void
    internal var pageSize: Int

    internal init(
      filter: AnyUpdatable<UserGroupsFilter>,
      selectGroup: @escaping (UserGroup.ID) async throws -> Void,
      pageSize: Int = 50
    ) {
      self.filter = filter
      self.selectGroup = selectGroup
      self.pageSize = pageSize
    }
  }

  internal struct ViewState: Equatable {

    internal var userGroups: Array<ResourceUserGroupListItemDSV>
    internal var isLoadingMore: Bool
    internal var hasMoreData: Bool
    internal var contentResetToken: Int
    internal var lastFilterText: String
  }
}

extension ResourceUserGroupsListDisplayController {

  internal final func refresh() async {
    do {
      try await self.sessionData.refreshIfNeeded()
    }
    catch {
      error.consume(
        context: "Failed to refresh session data."
      )
    }
  }

  @MainActor internal final func loadMore() async {
    let currentState: ViewState = await viewState.current
    let hasMore: Bool = currentState.hasMoreData
    let isLoading: Bool = currentState.isLoadingMore

    guard hasMore, !isLoading else { return }

    self.viewState.update { state in
      state.isLoadingMore = true
    }

    do {
      let pageSize: Int = self.context.pageSize
      let filter: UserGroupsFilter = try await self.context.filter.value
      let nextPageGroups: Array<ResourceUserGroupListItemDSV> = try await self.userGroups.filteredResourceUserGroups(
        .init(
          userID: filter.userID,
          text: filter.text,
          limit: pageSize,
          offset: currentState.userGroups.count
        )
      )

      self.viewState.update { state in
        state.userGroups.append(contentsOf: nextPageGroups)
        state.hasMoreData = nextPageGroups.count >= pageSize
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

  internal final func selectGroup(
    _ id: UserGroup.ID
  ) async throws {
    try await self.context.selectGroup(id)
  }
}
