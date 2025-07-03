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

public typealias ResourceSimulateShareNetworkOperation =
  NetworkOperation<ResourceSimulateShareNetworkOperationDescription>

public enum ResourceSimulateShareNetworkOperationDescription: NetworkOperationDescription {

  public struct Input {
    public let body: Body
    public let foreignModelId: PassboltID

    public init(
      foreignModelId: PassboltID,
      editedPermissions: OrderedSet<ResourcePermission>,
      removedPermissions: OrderedSet<ResourcePermission>
    ) {
      self.foreignModelId = foreignModelId
      let editedPermissions: Array<Permission> = editedPermissions.compactMap {
        (permission: ResourcePermission) -> Permission? in
        guard let aroData: (aro: ARO, foreignId: PassboltID) = permission.aroData else {
          // If aroData is nil, we cannot create a valid permission.
          return nil
        }
        return .init(
          id: permission.permissionID?.rawValue,
          aro: aroData.aro,
          aroForeignKey: aroData.foreignId,
          type: .init(from: permission.permission),
          isDeleted: false,
          isNew: permission.permissionID?.rawValue == nil
        )
      }
      let removedPermissions: Array<Permission> = removedPermissions.compactMap {
        (permission: ResourcePermission) -> Permission? in
        guard let aroData: (aro: ARO, foreignId: PassboltID) = permission.aroData,
          let id = permission.permissionID?.rawValue
        else {
          // If aroData or id is nil, we cannot create a valid permission.
          return nil
        }
        return .init(
          id: id,
          aro: aroData.aro,
          aroForeignKey: aroData.foreignId,
          type: .init(from: permission.permission),
          isDeleted: true,
          isNew: false
        )
      }
      self.body = Body(permissions: editedPermissions + removedPermissions)
    }

    public struct Body: Encodable {
      public let permissions: [Permission]
    }
  }

  public struct Permission: Encodable {
    public let id: PassboltID?
    public let aro: ARO
    public let aroForeignKey: PassboltID
    public let type: PermissionType
    public let isDeleted: Bool
    public let isNew: Bool

    public init(
      id: PassboltID?,
      aro: ARO,
      aroForeignKey: PassboltID,
      type: PermissionType,
      isDeleted: Bool,
      isNew: Bool
    ) {
      self.id = id
      self.aro = aro
      self.aroForeignKey = aroForeignKey
      self.type = type
      self.isDeleted = isDeleted
      self.isNew = isNew
    }

    private enum CodingKeys: String, CodingKey {
      case id = "id"
      case aro = "aro"
      case aroForeignKey = "aro_foreign_key"
      case type = "type"
      case isDeleted = "delete"
      case isNew = "is_new"
    }
  }

  public enum ARO: String, Encodable {
    case user = "User"
    case group = "Group"
  }

  public enum PermissionType: Int, Encodable {
    case read = 1
    case write = 7
    case owner = 15

    fileprivate init(from permission: CommonModels.Permission) {
      switch permission {
      case .read: self = .read
      case .write: self = .write
      case .owner: self = .owner
      }
    }
  }

  public struct Output: Decodable {
    public let changes: [ChangeType: [User.ID]]

    public init(from decoder: Decoder) throws {
      let container = try decoder.container(keyedBy: CodingKeys.self)
      let changesContainer = try container.nestedContainer(keyedBy: ChangeType.self, forKey: .changes)
      var changes: [ChangeType: [User.ID]] = [:]

      for key in changesContainer.allKeys {
        var ids: [User.ID] = []
        var nestedArray = try changesContainer.nestedUnkeyedContainer(forKey: key)
        while !nestedArray.isAtEnd {
          let userContainer = try nestedArray.nestedContainer(keyedBy: ChangeCodingKeys.self)
          let user = try userContainer.nestedContainer(keyedBy: UserCodingKeys.self, forKey: .user)
          let id = try user.decode(User.ID.self, forKey: .id)
          ids.append(id)
        }
        changes[key] = ids
      }
      self.changes = changes
    }
  }

  private enum CodingKeys: String, CodingKey {
    case changes
  }

  public enum ChangeType: String, Decodable, CodingKey {
    case added = "added"
    case removed = "removed"
  }

  private enum UserCodingKeys: String, CodingKey {
    case id
  }

  private enum ChangeCodingKeys: String, CodingKey {
    case user = "User"
  }
}

extension ResourcePermission {
  fileprivate typealias Operation = ResourceSimulateShareNetworkOperationDescription
  fileprivate var aroData: (aro: Operation.ARO, foreignId: PassboltID)? {
    let aro: Operation.ARO
    let aroForeignKey: PassboltID
    if let groupId: UserGroup.ID = userGroupID {
      aro = .group
      aroForeignKey = groupId.rawValue
    }
    else if let userId: User.ID = userID {
      aro = .user
      aroForeignKey = userId.rawValue
    }
    else {
      // If neither group nor user ID is available, we cannot create a valid permission.
      return nil
    }
    return (aro: aro, foreignId: aroForeignKey)
  }
}
