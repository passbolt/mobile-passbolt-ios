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

import CommonModels
import SwiftUI

// MARK: - Row Data Model
private enum ResourceUserGroupsListRowData: DynamicListItem {

  case userGroup(ResourceUserGroupListItemDSV)
  case loadingIndicator

  fileprivate var id: String {
    switch self {
    case .userGroup(let group):
      return "group_\(group.id.rawValue.rawValue.uuidString)"
    case .loadingIndicator:
      return "loading"
    }
  }

  fileprivate var estimatedHeight: CGFloat {
    switch self {
    case .userGroup:
      return 64
    case .loadingIndicator:
      return 44
    }
  }
}

extension ResourceUserGroupsListRowData: Hashable {

  fileprivate static func == (lhs: ResourceUserGroupsListRowData, rhs: ResourceUserGroupsListRowData) -> Bool {
    lhs.id == rhs.id
  }

  fileprivate func hash(into hasher: inout Hasher) {
    hasher.combine(id)
  }
}

public struct ResourceUserGroupsListView: View {

  private let userGroups: Array<ResourceUserGroupListItemDSV>
  private let hasMoreData: Bool
  private let isLoadingMore: Bool
  private let contentResetToken: Int
  private let refreshAction: @Sendable () async -> Void
  private let loadMoreAction: @Sendable () async -> Void
  private let createAction: (@Sendable () async throws -> Void)?
  private let groupTapAction: (UserGroup.ID) async throws -> Void

  public init(
    userGroups: Array<ResourceUserGroupListItemDSV>,
    hasMoreData: Bool,
    isLoadingMore: Bool,
    contentResetToken: Int = 0,
    refreshAction: @escaping @Sendable () async -> Void,
    loadMoreAction: @escaping @Sendable () async -> Void,
    createAction: (@Sendable () async throws -> Void)?,
    groupTapAction: @Sendable @escaping (UserGroup.ID) async throws -> Void
  ) {
    self.userGroups = userGroups
    self.hasMoreData = hasMoreData
    self.isLoadingMore = isLoadingMore
    self.contentResetToken = contentResetToken
    self.refreshAction = refreshAction
    self.loadMoreAction = loadMoreAction
    self.createAction = createAction
    self.groupTapAction = groupTapAction
  }

  public var body: some View {
    let rowData: Array<ResourceUserGroupsListRowData> = self.rowData
    DynamicList(
      items: rowData,
      hasMoreData: hasMoreData,
      isLoadingMore: isLoadingMore,
      onLoadMore: loadMoreAction,
      refreshAction: refreshAction,
      contentResetToken: contentResetToken,
      content: { viewForRow($0) }
    )
    .background {
      if rowData.hasGroups == false {
        EmptyListView()
      }
    }
  }

  private var rowData: Array<ResourceUserGroupsListRowData> {
    var rows: Array<ResourceUserGroupsListRowData> = []

    for group in self.userGroups {
      rows.append(.userGroup(group))
    }

    if self.isLoadingMore {
      rows.append(.loadingIndicator)
    }

    return rows
  }

  @ViewBuilder
  private func viewForRow(_ row: ResourceUserGroupsListRowData) -> some View {
    switch row {
    case .userGroup(let group):
      ResourceUserGroupListItemView(
        name: group.name,
        contentCount: group.contentCount,
        action: {
          try await self.groupTapAction(group.id)
        }
      )
      .frame(height: row.estimatedHeight)

    case .loadingIndicator:
      HStack {
        Spacer()
        SwiftUI.ProgressView()
        Spacer()
      }
      .frame(height: row.estimatedHeight)
      .padding()
    }
  }
}

extension Array where Element == ResourceUserGroupsListRowData {

  fileprivate var hasGroups: Bool {
    self.contains { row in
      if case .userGroup = row {
        return true
      }
      return false
    }
  }
}
