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

public struct ResourceType {

  public typealias ID = Tagged<UUID, Self>

  public let id: ID
  public let name: String
  public let specification: ResourceSpecification

  public init(
    id: ID,
    name: String,
    specification: ResourceSpecification
  ) {
    self.id = id
    self.name = name
    self.specification = specification
  }

  public init(
    id: ID,
    slug: ResourceSpecification.Slug,
    name: String
  ) {
    let specification: ResourceSpecification
    switch slug {
    case .password:
      specification = .password

    case .passwordWithDescription:
      specification = .passwordWithDescription

    case .totp:
      specification = .totp

    case .passwordWithTOTP:
      specification = .passwordWithTOTP

    case _:
      specification = .placeholder
    }

    self.init(
      id: id,
      name: name,
      specification: specification
    )
  }

  public init(
    id: ID,
    slug: ResourceSpecification.Slug,
    name: String,
    metaFields: OrderedSet<ResourceFieldSpecification>,
    secretFields: OrderedSet<ResourceFieldSpecification>
  ) {
    self.init(
      id: id,
      name: name,
      specification: .init(
        slug: slug,
        metaFields: metaFields,
        secretFields: secretFields
      )
    )
  }
}

extension ResourceType: Equatable {}

extension ResourceType {

  public var isDefault: Bool {
    self.specification.slug == .default
  }
}
