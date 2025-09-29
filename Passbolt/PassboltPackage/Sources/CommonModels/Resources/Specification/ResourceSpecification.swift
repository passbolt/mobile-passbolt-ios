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

  public let slug: Slug
  public let metaFields: OrderedSet<ResourceFieldSpecification>
  public let secretFields: OrderedSet<ResourceFieldSpecification>

  public init(
    slug: Slug,
    metaFields: OrderedSet<ResourceFieldSpecification>,
    secretFields: OrderedSet<ResourceFieldSpecification>
  ) {
    self.slug = slug
    self.metaFields = metaFields
    self.secretFields = secretFields
  }

  public static func specification(for slug: Slug) -> Self {
    switch slug {
    case .password, .v5Password:
      return .password(isV5: slug == .v5Password)
    case .passwordWithDescription, .v5Default:
      return .passwordWithDescription(isV5: slug == .v5Default)
    case .totp, .v5StandaloneTOTP:
      return .totp(isV5: slug == .v5StandaloneTOTP)
    case .passwordWithTOTP, .v5DefaultWithTOTP:
      return .passwordWithTOTP(isV5: slug == .v5DefaultWithTOTP)
    case .v5CustomFields:
      return .v5CustomFields()
    case _:
      return .placeholder
    }
  }
}

extension ResourceSpecification: Sendable {}
extension ResourceSpecification: Equatable {}

// MARK: - Hardcode of well known resource type specifications

extension ResourceSpecification.Slug {

  /// fallback used for undefined/unknown resource types
  public static let placeholder: Self = "placeholder"
  public static let password: Self = "password-string"
  public static let passwordWithDescription: Self = "password-and-description"
  public static let totp: Self = "totp"
  public static let passwordWithTOTP: Self = "password-description-totp"
  public static let v5Default: Self = "v5-default"
  public static let v5DefaultWithTOTP: Self = "v5-default-with-totp"
  public static let v5StandaloneTOTP: Self = "v5-totp-standalone"
  public static let v5Password: Self = "v5-password-string"
  public static let v5CustomFields: Self = "v5-custom-fields"

  /// Checks if the resource type is v4 or v5
  public var isSupported: Bool {
    Self.v4Types.contains(self)
      || Self.v5Types.contains(self)
  }

  /// V4 resource types
  public static var v4Types: [Self] {
    [.password, .passwordWithDescription, .totp, .passwordWithTOTP]
  }

  /// V5 resource types
  public static var v5Types: [Self] {
    [.v5StandaloneTOTP, .v5DefaultWithTOTP, .v5Password, .v5Default, .v5CustomFields]
  }

  public var isV5Type: Bool {
    Self.v5Types.contains(self)
  }

  /// All resource types that include TOTP functionality
  public static var allTOTPTypes: Set<Self> {
    [.totp, .v5StandaloneTOTP, .passwordWithTOTP, .v5DefaultWithTOTP]
  }

  /// Resource types that are TOTP-only without password
  public static var standaloneTOTPTypes: Set<Self> {
    [.totp, .v5StandaloneTOTP]
  }

  /// Checks if this is a standalone TOTP type without password
  public var isStandaloneTOTPType: Bool {
    Self.standaloneTOTPTypes.contains(self)
  }

  /// Checks if this is a simple password - without ability to add other secrets
  public var isSimplePasswordType: Bool {
    [.password, .v5Password].contains(self)
  }
}

extension ResourceSpecification {

  public static let `default`: Self = passwordWithDescription(isV5: false)

  public static func password(isV5: Bool) -> Self {
    .init(
      slug: isV5 ? .v5Password : .password,
      metaFields: .defaultMetaFields,
      secretFields: [
        .init(
          path: \.secret,
          name: .secret,
          content: .string(
            minLength: .none,
            maxLength: ResourceFieldSpecification.maxPasswordLength
          ),
          required: true,
          encrypted: true
        )
      ]
    )
  }

  public static func passwordWithDescription(isV5: Bool) -> Self {
    .init(
      slug: isV5 ? .v5Default : .passwordWithDescription,
      metaFields: .defaultMetaFields,
      secretFields: [
        .init(
          path: \.secret.password,
          name: .password,
          content: .string(
            minLength: .none,
            maxLength: ResourceFieldSpecification.maxPasswordLength
          ),
          required: false,
          encrypted: true
        ),
        .init(
          path: \.secret.description,
          name: .note,
          content: .string(
            minLength: .none,
            maxLength: isV5 ? ResourceFieldSpecification.maxNoteLength : ResourceFieldSpecification.maxV4NoteLength
          ),
          required: false,
          encrypted: true
        ),
      ]
    )
  }

  public static func totp(isV5: Bool) -> Self {
    .init(
      slug: isV5 ? .v5StandaloneTOTP : .totp,
      metaFields: .defaultMetaFields,
      secretFields: [
        .init(
          path: \.secret.totp,
          name: .totp,
          content: .totp,
          required: true,
          encrypted: true
        ),
        .secretCustomFields,
      ]
    )
  }

  public static func v5CustomFields() -> Self {
    .init(
      slug: .v5CustomFields,
      metaFields: [
        .metaName,
        .metaDescription,
        .metaURIs,
        .metaCustomFields,
      ],
      secretFields: [
        .secretCustomFields
      ]
    )
  }

  public static func passwordWithTOTP(isV5: Bool) -> Self {
    .init(
      slug: isV5 ? .v5DefaultWithTOTP : .passwordWithTOTP,
      metaFields: .defaultMetaFields,
      secretFields: [
        .init(
          path: \.secret.password,
          name: .password,
          content: .string(
            minLength: .none,
            maxLength: ResourceFieldSpecification.maxPasswordLength
          ),
          required: false,
          encrypted: true
        ),
        .init(
          path: \.secret.totp,
          name: .totp,
          content: .totp,
          required: true,
          encrypted: true
        ),
        .init(
          path: \.secret.description,
          name: .note,
          content: .string(
            minLength: .none,
            maxLength: isV5 ? ResourceFieldSpecification.maxNoteLength : ResourceFieldSpecification.maxV4NoteLength
          ),
          required: false,
          encrypted: true
        ),
      ]
    )
  }

  /// fallback used for undefined/unknown resource types
  public static let placeholder: Self = .init(
    slug: .placeholder,
    metaFields: [
      .init(
        // name is required for all resources
        path: \.meta.name,
        name: .name,
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
        name: .name,
        // it won't be edited, using no validation to avoid issues
        content: .string(),
        required: true,
        encrypted: true
      )
    ]
  )
}

extension ResourceFieldSpecification {
  fileprivate static var metaName: Self {
    .init(
      path: \.meta.name,
      name: .name,
      content: .string(
        minLength: .none,
        maxLength: Self.maxNameLength
      ),
      required: false,
      encrypted: false
    )
  }

  fileprivate static var metaUsername: Self {
    .init(
      path: \.meta.username,
      name: .username,
      content: .string(
        minLength: .none,
        maxLength: Self.maxUsernameLength
      ),
      required: false,
      encrypted: false
    )
  }

  fileprivate static var metaURIs: Self {
    .init(
      path: \.meta.uris,
      name: .uri,
      content: .list(maxCount: Self.maxURIsCount),
      required: false,
      encrypted: false
    )
  }

  fileprivate static var metaDescription: Self {
    .init(
      path: \.meta.description,
      name: .description,
      content: .string(
        minLength: .none,
        maxLength: Self.maxDescriptionLength
      ),
      required: false,
      encrypted: false
    )
  }

  fileprivate static var metaAppearance: Self {
    .init(
      path: \.meta.icon,
      name: .appearance,
      content: .structure([]),
      required: false,
      encrypted: false
    )
  }

  fileprivate static var metaCustomFields: Self {
    .init(
      path: \.meta.custom_fields,
      name: .customFields,
      content: .list(maxCount: Self.maxCustomFieldsCount),
      required: false,
      encrypted: false
    )
  }

  fileprivate static var secretCustomFields: Self {
    .init(
      path: \.secret.custom_fields,
      name: .customFields,
      content: .list(maxCount: Self.maxCustomFieldsCount),
      required: false,
      encrypted: true
    )
  }
}

extension OrderedSet where Element == ResourceFieldSpecification {

  fileprivate static var defaultMetaFields: Self {
    [
      .metaName,
      .metaURIs,
      .metaDescription,
      .metaAppearance,
      .metaCustomFields,
      .metaUsername,
    ]
  }
}

extension ResourceFieldSpecification {

  internal static let maxNameLength: Int = 255
  internal static let maxDescriptionLength: Int = 10_000
  internal static let maxNoteLength: Int = 50_000
  internal static let maxV4NoteLength: Int = 10_000
  internal static let maxUsernameLength: Int = 255
  internal static let maxPasswordLength: Int = 4096
  internal static let maxCustomFieldKeyLength: Int = 255
  internal static let maxCustomFieldValueLength: Int = 10_000
  internal static let maxCustomFieldsCount: Int = 128
  internal static let maxURIsCount: Int = 20
}
