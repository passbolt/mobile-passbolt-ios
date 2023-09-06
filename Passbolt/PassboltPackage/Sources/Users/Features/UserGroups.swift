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
import Features

// MARK: - Interface

/// Access user groups data using current session.
public struct UserGroups {

  /// Access filtered user groups in context of resources.
  public var filteredResourceUserGroupList:
    @Sendable (AnyAsyncSequence<String>) -> AnyAsyncSequence<Array<ResourceUserGroupListItemDSV>>
  public var filteredResourceUserGroups:
    @Sendable (UserGroupsFilter) async throws -> Array<ResourceUserGroupListItemDSV>
  /// Access filtered user groups details.
  public var filteredUserGroups: @Sendable (UserGroupsFilter) async throws -> Array<UserGroupDetailsDSV>
  /// Access group members details for a given group.
  public var groupMembers: @Sendable (UserGroup.ID) async throws -> OrderedSet<UserDetailsDSV>

  public init(
    filteredResourceUserGroupList:
      @escaping @Sendable (AnyAsyncSequence<String>) -> AnyAsyncSequence<Array<ResourceUserGroupListItemDSV>>,
    filteredResourceUserGroups:
      @escaping @Sendable (UserGroupsFilter) async throws -> Array<ResourceUserGroupListItemDSV>,
    filteredUserGroups: @escaping @Sendable (UserGroupsFilter) async throws -> Array<UserGroupDetailsDSV>,
    groupMembers: @escaping @Sendable (UserGroup.ID) async throws -> OrderedSet<UserDetailsDSV>
  ) {
    self.filteredResourceUserGroupList = filteredResourceUserGroupList
    self.filteredResourceUserGroups = filteredResourceUserGroups
    self.filteredUserGroups = filteredUserGroups
    self.groupMembers = groupMembers
  }
}

extension UserGroups: LoadableFeature {


  #if DEBUG

  public static var placeholder: Self {
    Self(
      filteredResourceUserGroupList: unimplemented1(),
      filteredResourceUserGroups: unimplemented1(),
      filteredUserGroups: unimplemented1(),
      groupMembers: unimplemented1()
    )
  }
  #endif
}
