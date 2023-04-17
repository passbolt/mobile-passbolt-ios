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

@dynamicMemberLookup
public struct ResourceType {

  public typealias ID = Tagged<String, Self>
  public typealias Slug = Tagged<String, ID>

  public let id: ID
  public let slug: Slug
  public let _name: String  // `_` is used to avoid conflict with "name" field
  public let fields: OrderedSet<ResourceField>

  public init(
    id: ID,
    slug: Slug,
    name: String,
    fields: OrderedSet<ResourceField>
  ) {
    self.id = id
    self.slug = slug
    self._name = name
    self.fields =
      fields
      .sorted()
      .asOrderedSet()
  }

  public subscript(
    dynamicMember name: String
  ) -> ResourceField? {
    self.fields.first(where: { $0.name == name })
  }
}

extension ResourceType: Equatable {}

extension ResourceType {

  public var isDefault: Bool {
    self.slug == .default
  }
}

extension ResourceType.ID {

  internal static let validator: Validator<Self> = Validator<String>
    .uuid()
    .contraMap(\.rawValue)

  public var isValid: Bool {
    Self
      .validator
      .validate(self)
      .isValid
  }
}

extension ResourceType.Slug {

  public static let `default`: Self = .passwordWithDescription

  public static let password: Self = "password"
  public static let passwordWithDescription: Self = "password-and-description"
  public static let passwordWithTOTP: Self = "password-description-totp"
  public static let totp: Self = "totp"
  public static let hotp: Self = "hotp"
}
