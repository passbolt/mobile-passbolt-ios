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

import Features

// MARK: - Interface

public typealias ResourceShareNetworkOperation =
  NetworkOperation<ResourceShareNetworkOperationDescription>

public enum ResourceShareNetworkOperationDescription: NetworkOperationDescription {

  public typealias Input = ResourceShareNetworkOperationVariable
}

public struct ResourceShareNetworkOperationVariable {

  public var resourceID: Resource.ID
  public var body: RequestBody

  public init(
    resourceID: Resource.ID,
    body: RequestBody
  ) {
    self.resourceID = resourceID
    self.body = body
  }
}

extension ResourceShareNetworkOperationVariable {

  public struct RequestBody {

    public var newPermissions: Array<NewGenericPermissionDTO>
    public var updatedPermissions: Array<GenericPermissionDTO>
    public var deletedPermissions: Array<GenericPermissionDTO>
    public var newSecrets: OrderedSet<EncryptedMessage>

    public init(
      newPermissions: Array<NewGenericPermissionDTO>,
      updatedPermissions: Array<GenericPermissionDTO>,
      deletedPermissions: Array<GenericPermissionDTO>,
      newSecrets: OrderedSet<EncryptedMessage>
    ) {
      self.newPermissions = newPermissions
      self.updatedPermissions = updatedPermissions
      self.deletedPermissions = deletedPermissions
      self.newSecrets = newSecrets
    }
  }
}

extension ResourceShareNetworkOperationVariable.RequestBody: Encodable {

  private enum CodingKeys: String, CodingKey {

    case permissions = "permissions"
    case secrets = "secrets"
  }

  private enum PermissionCodingKeys: String, CodingKey {

    case new = "is_new"
    case deleted = "delete"
    case id = "id"
    case subject = "aro"
    case subjectID = "aro_foreign_key"
    case item = "aco"
    case itemID = "aco_foreign_key"
    case type = "type"
  }

  public func encode(
    to encoder: Encoder
  ) throws {
    var container: KeyedEncodingContainer<CodingKeys> =
      encoder
      .container(
        keyedBy: CodingKeys.self
      )

    try container
      .encode(
        self.newSecrets,
        forKey: .secrets
      )

    var permissionsContainer: UnkeyedEncodingContainer =
      container
      .nestedUnkeyedContainer(
        forKey: .permissions
      )

    for newPermission in self.newPermissions {
      var permissionContainer: KeyedEncodingContainer<PermissionCodingKeys> =
        permissionsContainer
        .nestedContainer(
          keyedBy: PermissionCodingKeys.self
        )
      try permissionContainer
        .encode(
          true,
          forKey: .new
        )
      switch newPermission {
      case let .userToResource(userID, resourceID, type):
        try permissionContainer
          .encode(
            "User",
            forKey: .subject
          )
        try permissionContainer
          .encode(
            userID,
            forKey: .subjectID
          )
        try permissionContainer
          .encode(
            "Resource",
            forKey: .item
          )
        try permissionContainer
          .encode(
            resourceID,
            forKey: .itemID
          )
        try permissionContainer
          .encode(
            type,
            forKey: .type
          )

      case let .userToFolder(userID, folderID, type):
        try permissionContainer
          .encode(
            "User",
            forKey: .subject
          )
        try permissionContainer
          .encode(
            userID,
            forKey: .subjectID
          )
        try permissionContainer
          .encode(
            "Folder",
            forKey: .item
          )
        try permissionContainer
          .encode(
            folderID,
            forKey: .itemID
          )
        try permissionContainer
          .encode(
            type,
            forKey: .type
          )

      case let .userGroupToResource(userGroupID, resourceID, type):
        try permissionContainer
          .encode(
            "Group",
            forKey: .subject
          )
        try permissionContainer
          .encode(
            userGroupID,
            forKey: .subjectID
          )
        try permissionContainer
          .encode(
            "Resource",
            forKey: .item
          )
        try permissionContainer
          .encode(
            resourceID,
            forKey: .itemID
          )
        try permissionContainer
          .encode(
            type,
            forKey: .type
          )

      case let .userGroupToFolder(userID, folderID, type):
        try permissionContainer
          .encode(
            "Group",
            forKey: .subject
          )
        try permissionContainer
          .encode(
            userID,
            forKey: .subjectID
          )
        try permissionContainer
          .encode(
            "Folder",
            forKey: .item
          )
        try permissionContainer
          .encode(
            folderID,
            forKey: .itemID
          )
        try permissionContainer
          .encode(
            type,
            forKey: .type
          )
      }
    }

    for updatedPermission in self.updatedPermissions {
      var permissionContainer: KeyedEncodingContainer<PermissionCodingKeys> =
        permissionsContainer
        .nestedContainer(
          keyedBy: PermissionCodingKeys.self
        )

      switch updatedPermission {
      case let .userToResource(id, userID, resourceID, type):
        try permissionContainer
          .encode(
            id,
            forKey: .id
          )
        try permissionContainer
          .encode(
            "User",
            forKey: .subject
          )
        try permissionContainer
          .encode(
            userID,
            forKey: .subjectID
          )
        try permissionContainer
          .encode(
            "Resource",
            forKey: .item
          )
        try permissionContainer
          .encode(
            resourceID,
            forKey: .itemID
          )
        try permissionContainer
          .encode(
            type,
            forKey: .type
          )

      case let .userToFolder(id, userID, folderID, type):
        try permissionContainer
          .encode(
            id,
            forKey: .id
          )
        try permissionContainer
          .encode(
            "User",
            forKey: .subject
          )
        try permissionContainer
          .encode(
            userID,
            forKey: .subjectID
          )
        try permissionContainer
          .encode(
            "Folder",
            forKey: .item
          )
        try permissionContainer
          .encode(
            folderID,
            forKey: .itemID
          )
        try permissionContainer
          .encode(
            type,
            forKey: .type
          )

      case let .userGroupToResource(id, userGroupID, resourceID, type):
        try permissionContainer
          .encode(
            id,
            forKey: .id
          )
        try permissionContainer
          .encode(
            "Group",
            forKey: .subject
          )
        try permissionContainer
          .encode(
            userGroupID,
            forKey: .subjectID
          )
        try permissionContainer
          .encode(
            "Resource",
            forKey: .item
          )
        try permissionContainer
          .encode(
            resourceID,
            forKey: .itemID
          )
        try permissionContainer
          .encode(
            type,
            forKey: .type
          )

      case let .userGroupToFolder(id, userID, folderID, type):
        try permissionContainer
          .encode(
            id,
            forKey: .id
          )
        try permissionContainer
          .encode(
            "Group",
            forKey: .subject
          )
        try permissionContainer
          .encode(
            userID,
            forKey: .subjectID
          )
        try permissionContainer
          .encode(
            "Folder",
            forKey: .item
          )
        try permissionContainer
          .encode(
            folderID,
            forKey: .itemID
          )
        try permissionContainer
          .encode(
            type,
            forKey: .type
          )
      }
    }

    for deletedPermission in self.deletedPermissions {
      var permissionContainer: KeyedEncodingContainer<PermissionCodingKeys> =
        permissionsContainer
        .nestedContainer(
          keyedBy: PermissionCodingKeys.self
        )

      try permissionContainer
        .encode(
          true,
          forKey: .deleted
        )

      switch deletedPermission {
      case let .userToResource(id, userID, resourceID, type):
        try permissionContainer
          .encode(
            id,
            forKey: .id
          )
        try permissionContainer
          .encode(
            "User",
            forKey: .subject
          )
        try permissionContainer
          .encode(
            userID,
            forKey: .subjectID
          )
        try permissionContainer
          .encode(
            "Resource",
            forKey: .item
          )
        try permissionContainer
          .encode(
            resourceID,
            forKey: .itemID
          )
        try permissionContainer
          .encode(
            type,
            forKey: .type
          )

      case let .userToFolder(id, userID, folderID, type):
        try permissionContainer
          .encode(
            id,
            forKey: .id
          )
        try permissionContainer
          .encode(
            "User",
            forKey: .subject
          )
        try permissionContainer
          .encode(
            userID,
            forKey: .subjectID
          )
        try permissionContainer
          .encode(
            "Folder",
            forKey: .item
          )
        try permissionContainer
          .encode(
            folderID,
            forKey: .itemID
          )
        try permissionContainer
          .encode(
            type,
            forKey: .type
          )

      case let .userGroupToResource(id, userGroupID, resourceID, type):
        try permissionContainer
          .encode(
            id,
            forKey: .id
          )
        try permissionContainer
          .encode(
            "Group",
            forKey: .subject
          )
        try permissionContainer
          .encode(
            userGroupID,
            forKey: .subjectID
          )
        try permissionContainer
          .encode(
            "Resource",
            forKey: .item
          )
        try permissionContainer
          .encode(
            resourceID,
            forKey: .itemID
          )
        try permissionContainer
          .encode(
            type,
            forKey: .type
          )

      case let .userGroupToFolder(id, userID, folderID, type):
        try permissionContainer
          .encode(
            id,
            forKey: .id
          )
        try permissionContainer
          .encode(
            "Group",
            forKey: .subject
          )
        try permissionContainer
          .encode(
            userID,
            forKey: .subjectID
          )
        try permissionContainer
          .encode(
            "Folder",
            forKey: .item
          )
        try permissionContainer
          .encode(
            folderID,
            forKey: .itemID
          )
        try permissionContainer
          .encode(
            type,
            forKey: .type
          )
      }
    }
  }
}
