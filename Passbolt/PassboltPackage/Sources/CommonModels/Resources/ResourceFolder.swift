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

public struct ResourceFolder {

  public typealias ID = Tagged<PassboltID, Self>

  public var id: ID? {
    didSet { self.isLocallyEdited = true }
  }
  public var name: String {
    didSet { self.isLocallyEdited = true }
  }
  public var path: OrderedSet<ResourceFolderPathItem> {
    didSet { self.isLocallyEdited = true }
  }
  public var permission: Permission {
    didSet { self.isLocallyEdited = true }
  }
  public var permissions: OrderedSet<ResourceFolderPermission> {
    didSet { self.isLocallyEdited = true }
  }
  public private(set) var isLocallyEdited: Bool

  public init(
    id: ID?,
    name: String,
    path: OrderedSet<ResourceFolderPathItem>,
    permission: Permission,
    permissions: OrderedSet<ResourceFolderPermission>
  ) {
    self.id = id
    self.name = name
    self.path = path
    self.permission = permission
    self.permissions = permissions
    // if creating new local it is always locally edited
    self.isLocallyEdited = id == nil
  }
}

extension ResourceFolder: Equatable {}

// MARK: - Common info

extension ResourceFolder {

  public var isLocal: Bool {
    self.id == .none
  }

  public var parentFolderID: ID? {
    self.path.last?.id
  }

  public var shared: Bool {
    self.permissions.count > 1
      || self.permissions.contains { (permission: ResourceFolderPermission) in
        switch permission {
        case .user:
          return false

        case .userGroup:
          return true
        }
      }
  }
}

// MARK: - Validation

extension ResourceFolder {

  public func validate() throws {
    try self.nameValidator.ensureValid(self.name)
    try self.permissionsValidator.ensureValid(self.permissions)
  }

  public var nameValidator: Validator<String> {
    zip(
      .nonEmpty(displayable: "error.validation.folder.name.empty"),
      .maxLength(
        256,
        displayable: "error.validation.folder.name.too.long"
      )
    )
  }

  public var permissionsValidator: Validator<OrderedSet<ResourceFolderPermission>> {
    zip(
      .nonEmpty(
        displayable: "error.validation.permissions.empty"
      ),
      .contains(
        where: \.permission.isOwner,
        displayable: "error.resource.folder.owner.missing"
      )
    )
  }
}
