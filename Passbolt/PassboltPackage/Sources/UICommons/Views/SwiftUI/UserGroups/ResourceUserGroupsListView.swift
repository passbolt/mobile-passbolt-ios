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

public struct ResourceUserGroupsListView: View {

  @State var id: IID = .init()
  private let userGroups: Array<ResourceUserGroupListItemDSV>
  private let contentEmpty: Bool
  private let refreshAction: () async -> Void
  private let createAction: (() async throws -> Void)?
  private let groupTapAction: (UserGroup.ID) async throws -> Void

  public init(
    userGroups: Array<ResourceUserGroupListItemDSV>,
    refreshAction: @escaping () async -> Void,
    createAction: (() async throws -> Void)?,
    groupTapAction: @escaping (UserGroup.ID) async throws -> Void
  ) {
    self.userGroups = userGroups
    self.contentEmpty = userGroups.isEmpty
    self.refreshAction = refreshAction
    self.createAction = createAction
    self.groupTapAction = groupTapAction
  }

  public var body: some View {
    List {
      if let createAction: () async throws -> Void = self.createAction {
        ResourceListAddView(action: createAction)
      }  // else no create row

      if self.contentEmpty {
        // empty
        EmptyListView()
      }
      else {
        ResourceUserGroupsListSectionView(
          userGroups: self.userGroups,
          tapAction: self.groupTapAction
        )
      }
    }
    .refreshable {
      await self.refreshAction()
    }
    .listStyle(.plain)
    .environment(\.defaultMinListRowHeight, 20)
    .id(self.id)
  }
}
