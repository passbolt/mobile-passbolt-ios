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

public struct Resource {

  public typealias ID = Tagged<PassboltID, Self>

  public enum Favorite {

    public typealias ID = Tagged<PassboltID, Self>
  }

  public typealias FieldPath = WritableKeyPath<Resource, JSON>
  public typealias _FieldPath = KeyPath<Resource, JSON>

  public let id: Resource.ID?  // none is local, not synchronized resource
  public var path: OrderedSet<ResourceFolderPathItem>
  public var type: ResourceType {
    didSet { self.updateCaches() }
  }
  public var favoriteID: Resource.Favorite.ID?
  public var permission: Permission
  public var permissions: OrderedSet<ResourcePermission>
  public var tags: OrderedSet<ResourceTag>
  public let modified: Timestamp?  // local resources does not have modified date
  public var meta: JSON
  public var secret: JSON  // null means that secret was not fetched yet as it is requested and filled separately

  // Private caches for accessing common elements without traversing
  // the whole resource specification
  private var flattenedFields: Dictionary<_FieldPath, ResourceFieldSpecification>
  private var metaPaths: Set<_FieldPath>
  private var secretPaths: Set<_FieldPath>

  public init(
    id: Resource.ID? = .none,
    path: OrderedSet<ResourceFolderPathItem> = .init(),
    favoriteID: Resource.Favorite.ID? = .none,
    type: ResourceType,
    permission: Permission = .owner,
    tags: OrderedSet<ResourceTag> = .init(),
    permissions: OrderedSet<ResourcePermission> = .init(),
    modified: Timestamp? = .none,
    meta: JSON = .object([:]),
    secret: JSON = .null  // null is secret not yet fetched
  ) {
    self.id = id
    self.path = path
    self.favoriteID = favoriteID
    self.type = type
    self.permission = permission
    self.tags = tags
    self.permissions = permissions
    self.modified = modified
    self.meta = meta
    self.secret = secret
    self.flattenedFields = .init()
    self.metaPaths = .init()
    self.secretPaths = .init()
    self.updateCaches()
    if case .none = id {
      // no ID means that it is local resource,
      // in order to have a proper initial state
      // we have to initialize all fields
      // the most important is to provide non null
      // secret to avoid treating this resource
      // as one without secret downloaded yet
      self.initializeFields()
    }  // else use data provided by initializer, do not modify it
  }
}

extension Resource: Equatable {

  public static func == (
    _ lhs: Resource,
    rhs: Resource
  ) -> Bool {
    lhs.id == rhs.id
      && lhs.type == rhs.type
      && lhs.favoriteID == rhs.favoriteID
      && lhs.modified == rhs.modified
      && lhs.meta == rhs.meta
      && lhs.secret == rhs.secret
      && lhs.permission == rhs.permission
      && lhs.permissions == rhs.permissions
      && lhs.path == rhs.path
      && lhs.tags == rhs.tags
  }
}

extension Resource {

  public var parentFolderID: ResourceFolder.ID? {
    self.path.last?.id
  }

  public var favorite: Bool {
    self.favoriteID != .none
  }

  public var hasSecret: Bool {
    self.secret != .null
  }

  public var containsUndefinedFields: Bool {
    self.type.specification.slug == .placeholder
      || self.allFields.contains(where: { (field: ResourceFieldSpecification) in
        if case .undefined = field.semantics {
          return true
        }
        else {
          return false
        }
      })
  }

  public var containsOTP: Bool {
    // currently only TOTP is supported and recognized only by its name
    self.contains(\.secret.totp)
  }

  public var hasUnstructuredSecret: Bool {
    // if there is a field straight to the secret without any nested field
    // this is treated as special case without internal secret structure available
    // it can be either legacy or placeholder resource where there is none structure
    // or it was not available to parse and check,
    // it has to be the only element in secret specification
    self.secretPaths.count == 1 && self.secretPaths.contains(\.secret)
  }

  public var metaFields: OrderedSet<ResourceFieldSpecification> {
    self.type.specification.metaFields
  }

  public var secretFields: OrderedSet<ResourceFieldSpecification> {
    self.type.specification.secretFields
  }

  public var allFields: OrderedSet<ResourceFieldSpecification> {
    self.type.specification.metaFields
      .union(self.type.specification.secretFields)
  }

  public var allFieldsOrdered: OrderedSet<ResourceFieldSpecification> {
    self.type.specification.metaFields
      .union(self.type.specification.secretFields)
      .sorted(using: ResourceFieldSpecification.Sorting())
      .asOrderedSet()
  }
}

extension Resource {

  public func validate() throws {
    try self.type.specification
      .validate(
        meta: self.meta,
        secret: self.secret
      )
  }

  public func validated(
    _ path: Resource.FieldPath
  ) -> Validated<JSON> {
    self.validator(for: path)
      .validate(self[keyPath: path])
  }

  public func validator(
    for path: Resource.FieldPath
  ) -> Validator<JSON> {
    self.flattenedFields[path]?.validator
      ?? .alwaysInvalid(displayable: "error.resource.field.unknown")
  }
}

extension Resource {

  public func displayableName(
    forField path: FieldPath
  ) -> DisplayableString? {
    self.flattenedFields[path]?.name.displayable
  }

  public func totpSecret(
    forField path: FieldPath
  ) -> TOTPSecret? {
    // searching for predefined structure at given path
    self[keyPath: path].totpSecretValue
  }

  public func metaContains(
    _ path: FieldPath
  ) -> Bool {
    self.metaPaths.contains(path)
  }

  public func secretContains(
    _ path: FieldPath
  ) -> Bool {
    self.secretPaths.contains(path)
  }

  public func contains(
    _ path: FieldPath
  ) -> Bool {
    self.flattenedFields.keys.contains(path)
  }

  public func fieldSpecification(
    for path: _FieldPath
  ) -> ResourceFieldSpecification? {
    switch path {
    case \.firstPassword:
      // \.firstPassword is a helper path to find a field by its semantics
      // (it will also work for legacy - secret is password)
      return self.allFieldsOrdered
        .first(where: { specification in
          if case .password = specification.semantics {
            return true
          }
          else {
            return false
          }
        })

    case \.firstTOTP:
      // \.firstTOTP is a helper path to find a field by its semantics
      return self.allFieldsOrdered
        .first(where: { specification in
          if case .totp = specification.semantics {
            return true
          }
          else {
            return false
          }
        })

    case \.description:
      // can't guess which description it will be,
      // proritizing encrypted one, description has a special handling
      return self.flattenedFields[\.secret.description]
        ?? self.flattenedFields[\.meta.description]

    case _:
      return self.flattenedFields[path]
    }
  }

  @discardableResult
  public mutating func update(
    _ field: FieldPath,
    to value: JSON
  ) -> Validated<JSON> {
    guard let specification: ResourceFieldSpecification = self.flattenedFields[field]
    else {
      return .invalid(
        value,
        error:
          UnknownResourceField
          .error(
            "Attempting to assign a value to not existing resource field!",
            path: field,
            value: value
          )
      )
    }

    // try to auto convert if able
    switch specification.content {
    case .string, .stringEnum, .structure:
      self[keyPath: field] = value
      return specification.validator.validate(value)

    case .int:
      switch value {
      case .string(let string):
        if let integer: Int = Int(string) {
          let convertedValue: JSON = .integer(integer)
          self[keyPath: field] = convertedValue
          return specification.validator.validate(convertedValue)
        }
        else {
          self[keyPath: field] = value
          return specification.validator.validate(value)
        }

      case _:
        self[keyPath: field] = value
        return specification.validator.validate(value)
      }

    case .double:
      switch value {
      case .string(let string):
        if let float: Double = Double(string) {
          let convertedValue: JSON = .float(float)
          self[keyPath: field] = convertedValue
          return specification.validator.validate(convertedValue)
        }
        else {
          self[keyPath: field] = value
          return specification.validator.validate(value)
        }

      case _:
        self[keyPath: field] = value
        return specification.validator.validate(value)
      }
    }
  }
}

extension Resource {

  public var isLocal: Bool {
    self.id == .none
  }

  public var hasPassword: Bool {
    self.allFields
      .contains(where: { specification in
        if case .password = specification.semantics {
          return true
        }
        else {
          return false
        }
      })
  }

  // Note it will return nil if there is no password field
  // or if it is encrypted and secret part is not fetched
  public var firstPasswordPath: FieldPath? {
    self.allFieldsOrdered
      .first(where: { specification in
        if case .password = specification.semantics {
          return true
        }
        else {
          return false
        }
      })?
      .path
  }

  // Note it will return nil if there is no password field
  // or if it is encrypted and secret part is not fetched
  public var firstPasswordString: String? {
    self.firstPassword.stringValue
  }

  // Note it will return null if there is no password field
  // or if it is encrypted and secret part is not fetched
  public var firstPassword: JSON {
    if let path: FieldPath = self.firstPasswordPath {
      return self[keyPath: path]
    }
    else {
      return .null
    }
  }

  public var hasTOTP: Bool {
    self.allFields
      .contains(where: { specification in
        if case .totp = specification.semantics {
          return true
        }
        else {
          return false
        }
      })
  }

  // Note it will return nil if there is no totp field
  // or if it is encrypted and secret part is not fetched
  public var firstTOTPPath: FieldPath? {
    self.allFieldsOrdered
      .first(where: { specification in
        if case .totp = specification.semantics {
          return true
        }
        else {
          return false
        }
      })?
      .path
  }

  // Note it will return nil if there is no totp field
  // or if it is encrypted and secret part is not fetched
  public var firstTOTPSecret: TOTPSecret? {
    self.firstTOTP.totpSecretValue
  }

  // Note it will return null if there is no totp field
  // or if it is encrypted and secret part is not fetched
  public var firstTOTP: JSON {
    if let path: FieldPath = self.firstTOTPPath {
      return self[keyPath: path]
    }
    else {
      return .null
    }
  }

  public var hasEncryptedDescription: Bool {
    // description can be unencrypted or not exist at all
    // knowing if it is encrypted is quite important
    // and allows to quickly find proper value path to get its value
    self.secretFields
      .contains(where: { specification in
        if specification.path == \.secret.description {
          return true
        }
        else {
          return false
        }
      })
  }

  // Note it will return nil if there is no such field
  // or if it is encrypted and secret part is not fetched
  public var descriptionString: String? {
    self.description.stringValue
  }

  // Note it will return null if there is no such field
  // or if it is encrypted and secret part is not fetched
  public var description: JSON {
    let descriptionField: ResourceFieldSpecification? = self.allFields
      .first(where: { specification in
        // description has a bit of special handling
        // yet we can't easily find it, the only way
        // is to match exact path (either in meta or secret)
        specification.path == \.secret.description
          || specification.path == \.meta.description
      })

    if let descriptionField {
      return self[keyPath: descriptionField.path]
    }
    else {
      return .null
    }
  }
}

extension Resource {

  private mutating func updateCaches() {
    func paths(
      for field: ResourceFieldSpecification
    ) -> Set<Resource.FieldPath> {
      var result: Set<Resource.FieldPath> = [field.path]
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
    ) -> Dictionary<Resource.FieldPath, ResourceFieldSpecification> {
      var result: Dictionary<Resource.FieldPath, ResourceFieldSpecification> = [field.path: field]
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

    self.flattenedFields.removeAll(keepingCapacity: true)
    self.metaPaths.removeAll(keepingCapacity: true)
    self.secretPaths.removeAll(keepingCapacity: true)
    for field in self.metaFields {
      self.metaPaths.formUnion(paths(for: field))
      self.flattenedFields.merge(fields(for: field), uniquingKeysWith: { $1 })
    }

    for field in self.secretFields {
      self.secretPaths.formUnion(paths(for: field))
      self.flattenedFields.merge(fields(for: field), uniquingKeysWith: { $1 })
    }
  }

  // Initialize fields is required for creating new instances
  // of resources in order to have a proper fields structure
  // inside JSON representation
  private mutating func initializeFields() {
    // initializing fields to null seems to be
    // unnecessary but it is required to initialize
    // a proper structure inside JSON
    for field in self.allFields {
      switch field.semantics {
      case .text, .longText:
        if field.required {
          self[keyPath: field.path] = .string("")
        }
        else {
          self[keyPath: field.path] = .null
        }

      case .selection:
        // can't have default selection?
        // selection values does not define default
        self[keyPath: field.path] = .null

      case .password:
        if field.required {
          self[keyPath: field.path] = .string("")
        }
        else {
          self[keyPath: field.path] = .null
        }

      case .totp:
        if field.required {
					self[keyPath: field.path] = TOTPSecret().asJSON
        }
        else {
          self[keyPath: field.path] = .null
        }

      case .intValue:
        if field.required {
          self[keyPath: field.path] = .integer(0)
        }
        else {
          self[keyPath: field.path] = .null
        }

      case .floatValue:
        if field.required {
          self[keyPath: field.path] = .float(0)
        }
        else {
          self[keyPath: field.path] = .null
        }

      case .undefined:
        break  // can't initialize undefined fields
      }
    }
  }
}
