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

public struct ResourceShareForm {

  public var permissionsSequence: () -> AnyAsyncSequence<OrderedSet<ResourcePermission>>
  public var currentPermissions: @Sendable () async -> OrderedSet<ResourcePermission>
  public var setUserPermission: @Sendable (User.ID, Permission) async -> Void
  public var deleteUserPermission: @Sendable (User.ID) async -> Void
  public var setUserGroupPermission: @Sendable (UserGroup.ID, Permission) async -> Void
  public var deleteUserGroupPermission: @Sendable (UserGroup.ID) async -> Void
  public var sendForm: @Sendable () async throws -> Void

  public init(
    permissionsSequence: @escaping () -> AnyAsyncSequence<OrderedSet<ResourcePermission>>,
    currentPermissions: @escaping @Sendable () async -> OrderedSet<ResourcePermission>,
    setUserPermission: @escaping @Sendable (User.ID, Permission) async -> Void,
    deleteUserPermission: @escaping @Sendable (User.ID) async -> Void,
    setUserGroupPermission: @escaping @Sendable (UserGroup.ID, Permission) async -> Void,
    deleteUserGroupPermission: @escaping @Sendable (UserGroup.ID) async -> Void,
    sendForm: @escaping @Sendable () async throws -> Void
  ) {
    self.permissionsSequence = permissionsSequence
    self.currentPermissions = currentPermissions
    self.setUserPermission = setUserPermission
    self.deleteUserPermission = deleteUserPermission
    self.setUserGroupPermission = setUserGroupPermission
    self.deleteUserGroupPermission = deleteUserGroupPermission
    self.sendForm = sendForm
  }
}

extension ResourceShareForm: LoadableFeature {

  public typealias Context = Resource.ID

  #if DEBUG

  public static var placeholder: Self {
    Self(
      permissionsSequence: unimplemented0(),
      currentPermissions: unimplemented0(),
      setUserPermission: unimplemented2(),
      deleteUserPermission: unimplemented1(),
      setUserGroupPermission: unimplemented2(),
      deleteUserGroupPermission: unimplemented1(),
      sendForm: unimplemented0()
    )
  }
  #endif
}
