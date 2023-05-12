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

public struct ResourceSpecification {

  public typealias Slug = Tagged<String, Self>

  public var slug: Slug
  public var metaFields: OrderedSet<ResourceFieldSpecification>
  public var secretFields: OrderedSet<ResourceFieldSpecification>

  public init(
    slug: Slug,
    metaFields: OrderedSet<ResourceFieldSpecification>,
    secretFields: OrderedSet<ResourceFieldSpecification>
  ) {
    self.slug = slug
    self.metaFields = metaFields
    self.secretFields = secretFields
  }
}

extension ResourceSpecification: Equatable {}

extension ResourceSpecification {

  public func fieldSpecification(
    for path: Resource.FieldPath
  ) -> ResourceFieldSpecification? {
    for field in self.metaFields {
      if let match: ResourceFieldSpecification = field.specification(for: path) {
        return match
      }
      else {
        continue
      }
    }
    for field in self.secretFields {
      if let match: ResourceFieldSpecification = field.specification(for: path) {
        return match
      }
      else {
        continue
      }
    }
    return .none
  }
}

extension ResourceSpecification {

  internal func validate(
    meta: JSON,
    secret: JSON  // null skips secret validation
  ) throws {
    for fieldSpecification in self.metaFields {
      try fieldSpecification.validate(meta[dynamicMember: fieldSpecification.name.rawValue])
    }
    if case .null = secret {
      // skip secret validation if there was no secret
    }
    else if self.secretFields.count == 1, let fieldSpecification = self.secretFields.first,
      fieldSpecification.path == \.secret
    {
      // fallback for legacy resource where secret was just plain field
      try fieldSpecification.validate(secret)
    }
    else {
      for fieldSpecification in self.secretFields {
        try fieldSpecification.validate(secret[dynamicMember: fieldSpecification.name.rawValue])
      }
    }
  }
}

// MARK: - Hardcode of well known resource type specifications

extension ResourceSpecification.Slug {

  public static let `default`: Self = .passwordWithDescription

  /// fallback used for undefined/unknown resource types
  public static let placeholder: Self = "placeholder"
  public static let password: Self = "password-string"
  public static let passwordWithDescription: Self = "password-and-description"
  public static let totp: Self = "totp"
  public static let passwordWithTOTP: Self = "password-description-totp"
}

extension ResourceSpecification {

  public static let password: Self = .init(
    slug: .password,
    metaFields: [
      .init(
        path: \.meta.name,
        name: "name",
        content: .string(
          minLength: .none,
          maxLength: 255
        ),
        required: true,
        encrypted: false
      ),
      .init(
        path: \.meta.username,
        name: "username",
        content: .string(
          minLength: .none,
          maxLength: 255
        ),
        required: false,
        encrypted: false
      ),
      .init(
        path: \.meta.uri,
        name: "uri",
        content: .string(
          minLength: .none,
          maxLength: 1024
        ),
        required: false,
        encrypted: false
      ),
      .init(
        path: \.meta.description,
        name: "description",
        content: .string(
          minLength: .none,
          maxLength: 10000
        ),
        required: false,
        encrypted: false
      ),
    ],
    secretFields: [
      .init(
        path: \.secret,
        name: "secret",
        content: .string(
          minLength: .none,
          maxLength: 4096
        ),
        required: true,
        encrypted: true
      )
    ]
  )

  public static let passwordWithDescription: Self = .init(
    slug: .passwordWithDescription,
    metaFields: [
      .init(
        path: \.meta.name,
        name: "name",
        content: .string(
          minLength: .none,
          maxLength: 255
        ),
        required: true,
        encrypted: false
      ),
      .init(
        path: \.meta.username,
        name: "username",
        content: .string(
          minLength: .none,
          maxLength: 255
        ),
        required: false,
        encrypted: false
      ),
      .init(
        path: \.meta.uri,
        name: "uri",
        content: .string(
          minLength: .none,
          maxLength: 1024
        ),
        required: false,
        encrypted: false
      ),
    ],
    secretFields: [
      .init(
        path: \.secret.password,
        name: "password",
        content: .string(
          minLength: .none,
          maxLength: 4096
        ),
        required: true,
        encrypted: true
      ),
      .init(
        path: \.secret.description,
        name: "description",
        content: .string(
          minLength: .none,
          maxLength: 10000
        ),
        required: false,
        encrypted: true
      ),
    ]
  )

  public static let totp: Self = .init(
    slug: .totp,
    metaFields: [
      .init(
        path: \.meta.name,
        name: "name",
        content: .string(
          minLength: .none,
          maxLength: 255
        ),
        required: true,
        encrypted: false
      ),
      .init(
        path: \.meta.uri,
        name: "uri",
        content: .string(
          minLength: .none,
          maxLength: 1024
        ),
        required: false,
        encrypted: false
      ),
    ],
    secretFields: [
      .init(
        path: \.secret.totp,
        name: "totp",
        content: .totp,
        required: true,
        encrypted: true
      )
    ]
  )

  public static let passwordWithTOTP: Self = .init(
    slug: .passwordWithTOTP,
    metaFields: [
      .init(
        path: \.meta.name,
        name: "name",
        content: .string(
          minLength: .none,
          maxLength: 255
        ),
        required: true,
        encrypted: false
      ),
      .init(
        path: \.meta.username,
        name: "username",
        content: .string(
          minLength: .none,
          maxLength: 255
        ),
        required: false,
        encrypted: false
      ),
      .init(
        path: \.meta.uri,
        name: "uri",
        content: .string(
          minLength: .none,
          maxLength: 1024
        ),
        required: false,
        encrypted: false
      ),
    ],
    secretFields: [
      .init(
        path: \.secret.password,
        name: "password",
        content: .string(
          minLength: .none,
          maxLength: 4096
        ),
        required: true,
        encrypted: true
      ),
      .init(
        path: \.secret.totp,
        name: "totp",
        content: .totp,
        required: true,
        encrypted: true
      ),
      .init(
        path: \.secret.description,
        name: "description",
        content: .string(
          minLength: .none,
          maxLength: 10000
        ),
        required: false,
        encrypted: true
      ),
    ]
  )

  /// fallback used for undefined/unknown resource types
  public static let placeholder: Self = .init(
    slug: .placeholder,
    metaFields: [
      .init(
        // name is required for all resources
        path: \.meta.name,
        name: "name",
        // it won't be edited, using no validation to avoid issues
        content: .string(),
        required: true,
        encrypted: false
      )
    ],
    secretFields: [
      .init(
        // using handling similar to legacy resource type
        // treat the whole secret as a string instead of decoding internals
        path: \.secret,
        name: "secret",
        // it won't be edited, using no validation to avoid issues
        content: .string(),
        required: true,
        encrypted: true
      )
    ]
  )
}
