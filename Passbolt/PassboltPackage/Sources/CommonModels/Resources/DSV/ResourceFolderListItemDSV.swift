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

import struct Foundation.Date

public struct ResourceFolderListItemDSV {

  public let id: ResourceFolder.ID
  public var name: String
  public var permissionType: PermissionTypeDSV
  public var shared: Bool
  public var parentFolderID: ResourceFolder.ID?
  public var contentCount: Int

  public init(
    id: ResourceFolder.ID,
    name: String,
    permissionType: PermissionTypeDSV,
    shared: Bool,
    parentFolderID: ResourceFolder.ID?,
    contentCount: Int
  ) {
    self.id = id
    self.name = name
    self.permissionType = permissionType
    self.shared = shared
    self.parentFolderID = parentFolderID
    self.contentCount = contentCount
  }
}

extension ResourceFolderListItemDSV: DSV {}

extension ResourceFolderListItemDSV: Hashable {}

#if DEBUG

extension ResourceFolderListItemDSV: RandomlyGenerated {

  public static func randomGenerator(
    using randomnessGenerator: RandomnessGenerator
  ) -> Generator<Self> {
    zip(
      with: ResourceFolderListItemDSV.init(id:name:permissionType:shared:parentFolderID:contentCount:),
      ResourceFolder.ID
        .randomGenerator(using: randomnessGenerator),
      Generator<String>
        .randomFolderName(using: randomnessGenerator),
      PermissionTypeDSV
        .randomGenerator(using: randomnessGenerator),
      Bool
        .randomGenerator(using: randomnessGenerator),
      ResourceFolder.ID
        .randomGenerator(using: randomnessGenerator)
        .optional(using: randomnessGenerator),
      Int
        .randomGenerator(min: 0, max: 10, using: randomnessGenerator)
    )
  }
}
#endif