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

public typealias ResourceFolderCreateNetworkOperation =
  NetworkOperation<ResourceFolderCreateNetworkOperationVariable, ResourceFolderCreateNetworkOperationResult>

public struct ResourceFolderCreateNetworkOperationVariable: Encodable {

  public var name: String
  public var parentFolderID: ResourceFolder.ID?

  public init(
    name: String,
    parentFolderID: ResourceFolder.ID?
  ) {
    self.name = name
    self.parentFolderID = parentFolderID
  }

  public enum CodingKeys: String, CodingKey {

    case name = "name"
    case parentFolderID = "folder_parent_id"
  }
}

public struct ResourceFolderCreateNetworkOperationResult: Decodable {

  public var resourceFolderID: ResourceFolder.ID
  public var ownerPermissionID: Permission.ID

  public init(
    resourceFolderID: ResourceFolder.ID,
    ownerPermissionID: Permission.ID
  ) {
    self.resourceFolderID = resourceFolderID
    self.ownerPermissionID = ownerPermissionID
  }

  public init(
    from decoder: Decoder
  ) throws {
    let container: KeyedDecodingContainer<ResourceFolderCreateNetworkOperationResult.CodingKeys> = try decoder.container(keyedBy: CodingKeys.self)

    self.resourceFolderID = try container.decode(ResourceFolder.ID.self, forKey: .resourceFolderID)

    let permissionContainer: KeyedDecodingContainer<ResourceFolderCreateNetworkOperationResult.PermissionCodingKeys> = try container.nestedContainer(keyedBy: PermissionCodingKeys.self, forKey: .permission)

    self.ownerPermissionID = try permissionContainer.decode(Permission.ID.self, forKey: .permissionID)
  }

  public enum CodingKeys: String, CodingKey {

    case resourceFolderID = "id"
    case permission = "permission"
  }

  public enum PermissionCodingKeys: String, CodingKey {

    case permissionID = "id"
  }
}
