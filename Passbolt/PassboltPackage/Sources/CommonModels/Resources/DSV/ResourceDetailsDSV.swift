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

public struct ResourceDetailsDSV {

  public let id: Resource.ID
  public var permissionType: PermissionTypeDSV
  public var name: String
  public var url: String?
  public var username: String?
  public var description: String?
  public var fields: Array<ResourceFieldDSV>
  public var permissions: Set<PermissionDSV>

  public init(
    id: Resource.ID,
    permissionType: PermissionTypeDSV,
    name: String,
    url: String?,
    username: String?,
    description: String?,
    fields: Array<ResourceFieldDSV>,
    permissions: Set<PermissionDSV>
  ) {
    self.id = id
    self.permissionType = permissionType
    self.name = name
    self.url = url
    self.username = username
    self.description = description
    self.fields = fields
    self.permissions = permissions
  }
}

extension ResourceDetailsDSV: DSV {}

#if DEBUG

extension ResourceDetailsDSV: RandomlyGenerated {

  public static func randomGenerator(
    using randomnessGenerator: RandomnessGenerator
  ) -> Generator<Self> {
    zip(
      with: ResourceDetailsDSV.init(id:permissionType:name:url:username:description:fields:permissions:),
      Resource.ID
        .randomGenerator(using: randomnessGenerator),
      PermissionTypeDSV
        .randomGenerator(using: randomnessGenerator),
      Generator<String>
        .randomResourceName(using: randomnessGenerator),
      Generator<String>
        .randomURL(using: randomnessGenerator)
        .optional(using: randomnessGenerator),
      Generator<String>
        .randomEmail(using: randomnessGenerator)
        .optional(using: randomnessGenerator),
      Generator<String>
        .randomLongText(using: randomnessGenerator)
        .optional(using: randomnessGenerator),
      ResourceFieldDSV
        .randomGenerator(using: randomnessGenerator)
        .array(withCountIn: 1..<3, using: randomnessGenerator)
        // name field is required to be always present
        .appening(ResourceFieldDTO(name: .name, valueType: .string, required: true, encrypted: false, maxLength: 0)),
      PermissionDSV
        .randomGenerator(using: randomnessGenerator)
        .array(withCountIn: 0..<3, using: randomnessGenerator)
        .map { Set($0) }
    )
  }
}
#endif
