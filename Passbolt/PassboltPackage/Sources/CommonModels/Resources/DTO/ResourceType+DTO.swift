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
    let id: ResourceType.ID = try container.decode(ResourceType.ID.self, forKey: .id)
    let slug: ResourceSpecification.Slug = try container.decode(ResourceSpecification.Slug.self, forKey: .slug)
    let isDeleted: Bool = try container.decodeIfPresent(Bool.self, forKey: .deleted) ?? false
    // [MOB-1283] In order to make grade D we can use hardcoded types.
    // We are using it instead of decoding JSON schema in order to avoid
    // yet unnecessary work related to decoding and interpreting it.
    // Any unknown resource type will result in placeholder type, however
    // at this stage all resource types are are known and won't change without
    // preparation on the client side as well. This will require client updates
    // when we introduce new resource types though.
    let specification: ResourceSpecification
    switch slug {
    case .password, .v5Password:
      specification = .password(isV5: slug == .v5Password)

    case .passwordWithDescription, .v5Default:
      specification = .passwordWithDescription(isV5: slug == .v5Default)

    case .totp, .v5StandaloneTOTP:
      specification = .totp(isV5: slug == .v5StandaloneTOTP)

    case .passwordWithTOTP, .v5DefaultWithTOTP:
      specification = .passwordWithTOTP(isV5: slug == .v5DefaultWithTOTP)

    case _:
      specification = .placeholder
    }

    self.init(
      id: id,
      isDeleted: isDeleted,
      specification: specification
    )
  }

  private enum CodingKeys: String, CodingKey {

    case id = "id"
    case slug = "slug"
    case deleted = "deleted"
  }

  public var isSupported: Bool {
    specification.slug.isSupported && isDeleted == false
  }
}
