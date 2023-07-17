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

  public typealias ID = Tagged<PassboltID, Self>
  // All actual fields from the specification are read/write
  public typealias FieldPath = WritableKeyPath<Resource, JSON>
  // Computed fields are read only but it also contains all actual fields
  public typealias ComputedFieldPath = KeyPath<Resource, JSON>

  public let id: ID
  public let specification: ResourceSpecification
  public let orderedFields: OrderedSet<ResourceFieldSpecification>
  public let containsUndefinedFields: Bool
  // internal cache to quickly access common things
  // and provide support for special, computed fields
  internal var flattenedFields: Dictionary<ComputedFieldPath, ResourceFieldSpecification>
  internal var metaPaths: Set<ComputedFieldPath>
  internal var secretPaths: Set<ComputedFieldPath>

  public init(
    id: ID,
    specification: ResourceSpecification
  ) {
    self.id = id
    self.specification = specification
    self.orderedFields = specification.metaFields
      .union(specification.secretFields)
      .sorted(using: ResourceFieldSpecification.Sorting())
      .asOrderedSet()
    self.containsUndefinedFields =
      specification.slug == .placeholder
      || specification.secretFields.contains(where: { (field: ResourceFieldSpecification) in
        if case .undefined = field.semantics {
          return true
        }
        else {
          return false
        }
      })
      || specification.metaFields.contains(where: { (field: ResourceFieldSpecification) in
        if case .undefined = field.semantics {
          return true
        }
        else {
          return false
        }
      })

    // prepare cache for quick access to fields
    func paths(
      for field: ResourceFieldSpecification
    ) -> Set<FieldPath> {
      var result: Set<FieldPath> = [field.path]
      if case .structure(let nestedFields) = field.content {
        for field in nestedFields {
          result.formUnion(paths(for: field))
        }
        return result
      }
      else {
        return result
      }
    }

    func fields(
      for field: ResourceFieldSpecification
    ) -> Dictionary<FieldPath, ResourceFieldSpecification> {
      var result: Dictionary<FieldPath, ResourceFieldSpecification> = [field.path: field]
      if case .structure(let nestedFields) = field.content {
        for field in nestedFields {
          result.merge(fields(for: field), uniquingKeysWith: { $1 })
        }
        return result
      }
      else {
        return result
      }
    }

    self.flattenedFields = .init()
    self.metaPaths = .init()
    self.secretPaths = .init()

    for field in specification.metaFields {
      self.metaPaths.formUnion(paths(for: field))
      self.flattenedFields.merge(fields(for: field), uniquingKeysWith: { $1 })
    }

    for field in specification.secretFields {
      self.secretPaths.formUnion(paths(for: field))
      self.flattenedFields.merge(fields(for: field), uniquingKeysWith: { $1 })
    }

    // add computed fields in order to properly find and resolve them

    // find name field, it has to be always available
    self.flattenedFields[\.nameField] = self.orderedFields
      .first(where: { (specification: ResourceFieldSpecification) in
        if specification.path == \.meta.name {
          return true
        }
        else {
          return false
        }
      })

    // find first field with password semantics
    self.flattenedFields[\.firstPassword] = self.orderedFields
      .first(where: { (specification: ResourceFieldSpecification) in
        if case .password = specification.semantics {
          return true
        }
        else {
          return false
        }
      })

    // find first field with totp semantics
    self.flattenedFields[\.firstTOTP] = self.orderedFields
      .first(where: { (specification: ResourceFieldSpecification) in
        if case .totp = specification.semantics {
          return true
        }
        else {
          return false
        }
      })

    // can't guess which description it will be,
    // proritizing encrypted one, description has a special handling
    self.flattenedFields[\.description] =
      specification.secretFields
      .first(where: { (specification: ResourceFieldSpecification) in
        if specification.path == \.secret.description {
          return true
        }
        else {
          return false
        }
      })
      ?? specification.metaFields
      .first(where: { (specification: ResourceFieldSpecification) in
        if specification.path == \.meta.description {
          return true
        }
        else {
          return false
        }
      })
  }

  public init(
    id: ID,
    slug: ResourceSpecification.Slug
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
      specification: specification
    )
  }

  public init(
    id: ID,
    slug: ResourceSpecification.Slug,
    metaFields: OrderedSet<ResourceFieldSpecification>,
    secretFields: OrderedSet<ResourceFieldSpecification>
  ) {
    self.init(
      id: id,
      specification: .init(
        slug: slug,
        metaFields: metaFields,
        secretFields: secretFields
      )
    )
  }
}

extension ResourceType: Sendable {}
extension ResourceType: Equatable {}

extension ResourceType {

  public var isDefault: Bool {
    self.specification.slug == .default
  }

  public var hasUnstructuredSecret: Bool {
    // if there is a field straight to the secret without any nested field
    // this is treated as special case without internal secret structure available
    // it can be either legacy or placeholder resource where there is none structure
    // or it was not available to parse and check,
    // it has to be the only element in secret specification
    self.secretPaths.count == 1 && self.secretPaths.contains(\.secret)
  }

  public var attachedOTPSlug: ResourceSpecification.Slug? {
    // only types where we know how to add OTP are supported
    switch self.specification.slug {
    case .passwordWithDescription:
      return .passwordWithTOTP

    case .passwordWithTOTP:
      return .passwordWithTOTP

    case .totp:
      return .totp

    case _:
      return .none
    }
  }

  public var detachedOTPSlug: ResourceSpecification.Slug? {
    // only types where we know how to remove OTP are supported
    switch self.specification.slug {
    case .passwordWithTOTP:
      return .passwordWithDescription

    case .totp:
      return .none

    case let slug:
      return slug
    }
  }

  public func validator(
    for path: ComputedFieldPath
  ) -> Validator<JSON> {
    self.flattenedFields[path]?.validator
      ?? .alwaysInvalid(displayable: "error.resource.field.unknown")
  }

  public func displayableName(
    forField path: ComputedFieldPath
  ) -> DisplayableString? {
    self.flattenedFields[path]?.name.displayable
  }

  public func contains(
    _ path: ComputedFieldPath
  ) -> Bool {
    self.flattenedFields.keys.contains(path)
  }

  public func fieldSpecification(
    for path: ComputedFieldPath
  ) -> ResourceFieldSpecification? {
    self.flattenedFields[path]
  }

  internal func validate(
    _ resource: Resource
  ) throws {
    for fieldSpecification in self.specification.metaFields {
      try fieldSpecification.validate(resource.meta[dynamicMember: fieldSpecification.name.rawValue])
    }
    if !resource.secretAvailable {
      // skip secret validation if there is no secret
    }
    else if self.specification.secretFields.count == 1, let fieldSpecification = self.specification.secretFields.first,
      fieldSpecification.path == \.secret
    {
      // fallback for legacy resource where secret was just plain field
      try fieldSpecification.validate(resource.secret)
    }
    else {
      for fieldSpecification in self.specification.secretFields {
        try fieldSpecification.validate(resource.secret[dynamicMember: fieldSpecification.name.rawValue])
      }
    }
  }
}
