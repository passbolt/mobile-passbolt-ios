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

public struct ResourceFolderDTO {

  public var id: ResourceFolder.ID
  public var name: String
  public var permissionType: PermissionTypeDTO
  public var shared: Bool
  public var parentFolderID: ResourceFolder.ID?
  public var permissions: OrderedSet<PermissionDTO>

  public init(
    id: ResourceFolder.ID,
    name: String,
    permissionType: PermissionTypeDTO,
    shared: Bool,
    parentFolderID: ResourceFolder.ID?,
    permissions: OrderedSet<PermissionDTO>
  ) {
    self.id = id
    self.name = name
    self.permissionType = permissionType
    self.shared = shared
    self.parentFolderID = parentFolderID
    self.permissions = permissions
  }
}

extension ResourceFolderDTO: DTO {}

extension ResourceFolderDTO: Decodable {

  public init(
    from decoder: Decoder
  ) throws {
    let container: KeyedDecodingContainer<CodingKeys> = try decoder.container(keyedBy: CodingKeys.self)
    self.id = try container.decode(ResourceFolder.ID.self, forKey: .id)
    self.name = try container.decode(String.self, forKey: .name)
    self.permissionType = try container.nestedContainer(keyedBy: PermissionTypeCodingKeys.self, forKey: .permissionType)
      .decode(PermissionTypeDTO.self, forKey: .type)
    self.shared = try !container.decode(Bool.self, forKey: .personal)
    self.parentFolderID = try container.decode(ResourceFolder.ID?.self, forKey: .parentFolderID)
    self.permissions = try container.decode(OrderedSet<PermissionDTO>.self, forKey: .permissions)
  }

  private enum CodingKeys: String, CodingKey {

    case id = "id"
    case name = "name"
    case permissionType = "permission"
    case personal = "personal"
    case parentFolderID = "folder_parent_id"
    case permissions = "permissions"
  }

  private enum PermissionTypeCodingKeys: String, CodingKey {

    case type = "type"
  }
}

extension ResourceFolderDTO: Hashable {}

#if DEBUG

extension ResourceFolderDTO: RandomlyGenerated {

  public static func randomGenerator(
    using randomnessGenerator: RandomnessGenerator
  ) -> Generator<Self> {
    zip(
      with: ResourceFolderDTO.init(id:name:permissionType:shared:parentFolderID:permissions:),
      ResourceFolder.ID
        .randomGenerator(using: randomnessGenerator),
      Generator<String>
        .randomFolderName(using: randomnessGenerator),
      PermissionTypeDTO
        .randomGenerator(using: randomnessGenerator),
      Bool
        .randomGenerator(using: randomnessGenerator),
      ResourceFolder.ID
        .randomGenerator(using: randomnessGenerator)
        .optional(using: randomnessGenerator),
      PermissionDTO
        .randomGenerator(using: randomnessGenerator)
        .array(withCount: 0)
        .map { OrderedSet($0) }
    )
  }
}
#endif
