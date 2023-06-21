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

public typealias ResourceTypeDTO = ResourceType

extension ResourceTypeDTO: Decodable {

  public init(
    from decoder: Decoder
  ) throws {
    let container: KeyedDecodingContainer<ResourceTypeDTO.CodingKeys> = try decoder.container(keyedBy: CodingKeys.self)
    self.id = try container.decode(ResourceType.ID.self, forKey: .id)
    self.name = try container.decode(String.self, forKey: .name)
    let slug = try container.decode(ResourceSpecification.Slug.self, forKey: .slug)

    // [MOB-1283] In order to make grade D we can use hardcoded types.
    // We are using it instead of decoding JSON schema in order to avoid
    // yet unnecessary work related to decoding and interpreting it.
    // Any unknown resource type will result in placeholder type, however
    // at this stage all resource types are are known and won't change without
    // preparation on the client side as well. This will require client updates
    // when we introduce new resource types though.
    switch slug {
    case .password:
      self.specification = .password

    case .passwordWithDescription:
      self.specification = .passwordWithDescription

    case .totp:
      self.specification = .totp

    case .passwordWithTOTP:
      self.specification = .passwordWithTOTP

    case _:
      self.specification = .placeholder
    }
  }

  private enum CodingKeys: String, CodingKey {

    case id = "id"
    case name = "name"
    case slug = "slug"
  }
}
