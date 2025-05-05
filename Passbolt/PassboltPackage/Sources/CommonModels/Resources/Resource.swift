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

  public typealias FieldPath = ResourceType.ComputedFieldPath

  public var id: Resource.ID?  // none is local, not synchronized resource
  public private(set) var type: ResourceType
  public var path: OrderedSet<ResourceFolderPathItem>
  public var favoriteID: Resource.Favorite.ID?
  public var permission: Permission
  public var permissions: OrderedSet<ResourcePermission>
  public var tags: OrderedSet<ResourceTag>
  public let modified: Timestamp?  // local resources does not have modified date
  public var meta: JSON
  public var secret: JSON  // null means that secret was not fetched yet as it is requested and filled separately
  public let expired: Timestamp?
  public let metadataKeyId: MetadataKeyDTO.ID?
  public let metadataKeyType: MetadataKeyDTO.MetadataKeyType?

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
    secret: JSON = .null,  // null is secret not yet fetched
    expired: Timestamp? = .none,
    metadataKeyId: MetadataKeyDTO.ID? = .none,
    metadataKeyType: MetadataKeyDTO.MetadataKeyType? = .none
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
    self.expired = expired
    self.metadataKeyId = metadataKeyId
    self.metadataKeyType = metadataKeyType
    self.initializeFieldsIfNeeded()
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
      && lhs.expired == rhs.expired
  }
}

// MARK: - Common info

extension Resource {

  // Name field is always required, we are not supporting
  // resources without a name inside the meta.
  public var name: String {
    get {
      self[keyPath: \Resource.meta.name].stringValue
        ?? DisplayableString
        .localized("resource")
        .string()
    }
    set { self[keyPath: \Resource.meta.name] = .string(newValue) }
  }

  public var isLocal: Bool {
    self.id == .none
  }

  public var parentFolderID: ResourceFolder.ID? {
    self.path.last?.id
  }

  public var favorite: Bool {
    self.favoriteID != .none
  }

  // Check if it is a TOTP resource
  public var isStandaloneTOTPResource: Bool {
    self.type.specification.slug.isStandaloneTOTPType
  }

  /// Checks if this is a simple password - without ability to add other secrets
  public var isSimplePasswordResource: Bool {
    self.type.specification.slug.isSimplePasswordType
  }
}

// MARK: - Validation

extension Resource {

  public func validate() throws {
    try self.type.validate(self)
  }

  public func validator(
    for path: FieldPath
  ) -> Validator<JSON> {
    self.type.validator(for: path)
  }

  public func validated(
    _ path: FieldPath
  ) -> Validated<JSON> {
    self.type.validator(for: path)
      .validate(self[keyPath: path])
  }
}

// MARK: - Fields

extension Resource {

  public var fields: OrderedSet<ResourceFieldSpecification> {
    self.type.orderedFields
  }

  public var secretAvailable: Bool {
    // local resource always "has secret" since all the data is local
    self.secret != .null || self.isLocal
  }

  public var canEdit: Bool {
    self.permission.canEdit && !self.containsUndefinedFields
  }

  public var containsUndefinedFields: Bool {
    self.type.containsUndefinedFields
  }

  public var hasUnstructuredSecret: Bool {
    self.type.hasUnstructuredSecret
  }

  public func displayableName(
    forField path: FieldPath
  ) -> DisplayableString? {
    self.type.displayableName(forField: path)
  }

  public func totpSecret(
    forField path: FieldPath
  ) -> TOTPSecret? {
    // searching for predefined structure at given path
    self[keyPath: path].totpSecretValue
  }

  public func contains(
    _ path: FieldPath
  ) -> Bool {
    self.type.contains(path)
  }

  public func isEncrypted(
    _ path: FieldPath
  ) -> Bool {
    self.type.fieldSpecification(for: path)?.encrypted ?? false
  }

  public func fieldSpecification(
    for path: FieldPath
  ) -> ResourceFieldSpecification? {
    self.type.fieldSpecification(for: path)
  }
}

// MARK: - Updates

extension Resource {

  @discardableResult
  public mutating func update(
    _ field: FieldPath,
    to value: JSON
  ) -> Validated<JSON> {
    guard let specification: ResourceFieldSpecification = self.type.fieldSpecification(for: field)
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
      self[keyPath: specification.path] = value
      return specification.validator.validate(value)

    case .int:
      switch value {
      case .string(let string):
        if let integer: Int = Int(string) {
          let convertedValue: JSON = .integer(integer)
          self[keyPath: specification.path] = convertedValue
          return specification.validator.validate(convertedValue)
        }
        else {
          self[keyPath: specification.path] = value
          return specification.validator.validate(value)
        }

      case _:
        self[keyPath: specification.path] = value
        return specification.validator.validate(value)
      }

    case .double:
      switch value {
      case .string(let string):
        if let float: Double = Double(string) {
          let convertedValue: JSON = .float(float)
          self[keyPath: specification.path] = convertedValue
          return specification.validator.validate(convertedValue)
        }
        else {
          self[keyPath: specification.path] = value
          return specification.validator.validate(value)
        }

      case _:
        self[keyPath: specification.path] = value
        return specification.validator.validate(value)
      }
    case .list:
      self[keyPath: specification.path] = .array([value])
      return .valid(value)
    }
  }

  public mutating func updateType(
    to resourceType: ResourceType
  ) throws {
    guard self.type != resourceType else { return }  // no need to update
    guard !self.type.containsUndefinedFields
    else {  // can't update properly if current type has undefined fields
      throw InvalidResourceTypeError.error(
        message: "Attempting to update a resource which has a type containing undefined fields!"
      )
    }
    guard !resourceType.containsUndefinedFields
    else {  // can't update properly if updated type has undefined fields
      throw InvalidResourceTypeError.error(
        message: "Attempting to update a resource type to a type containing undefined fields!"
      )
    }

    // remove fields that were in the old one but are not present in new one
    let newFields: Dictionary<ResourceType.ComputedFieldPath, ResourceFieldSpecification>.Values = resourceType
      .flattenedFields.values
    let removedFields: Array<ResourceFieldSpecification> = self.type.flattenedFields.values.filter {
      !newFields.contains($0)
    }
    for field in removedFields {
      #warning("To verify - this should not leave any junk values!")
      self[keyPath: field.path].remove()
    }
    // update metadata resource type if needed
    if self.type.isV4ResourceType == false {
      self.meta[keyPath: \.resource_type_id] = .string(resourceType.id.rawValue.rawValue.uuidString)
    }
    // assign new type and initialize fields if needed
    self.type = resourceType
    self.initializeFieldsIfNeeded()
  }
}

// MARK: - Computed fields

// NOTE: all computed resource fields have to be read only and supported
// inside resource type, it won't work otherwise, resource fields
// have to return JSON, otherwise it won't be counted as actual resource
// fields (it will be plain computed properties on Resource type, not
// a passbolt resource fields)
extension Resource {

  // Name field is always required, we are not supporting
  // resources without a name inside the meta.
  public var nameField: JSON {
    self[keyPath: \Resource.meta.name]
  }

  public var hasPassword: Bool {
    self.firstPasswordPath != nil
  }

  // Note it will return nil if there is no password field
  public var firstPasswordPath: ResourceType.FieldPath? {
    self.type.fieldSpecification(for: \.firstPassword)?.path
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

  public var canAttachOTP: Bool {
    self.canEdit && self.attachedOTPSlug != nil
  }

  public var attachedOTPSlug: ResourceSpecification.Slug? {
    self.type.attachedOTPSlug
  }

  public var canDetachOTP: Bool {
    self.canEdit && self.detachedOTPSlug != nil
  }

  public var detachedOTPSlug: ResourceSpecification.Slug? {
    self.type.detachedOTPSlug
  }

  public var hasTOTP: Bool {
    self.type.fieldSpecification(for: \.firstTOTP) != nil
  }

  // Note it will return nil if there is no totp field
  public var firstTOTPPath: ResourceType.FieldPath? {
    self.type.fieldSpecification(for: \.firstTOTP)?.path
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
    self.type.fieldSpecification(for: \.description)?.encrypted ?? false
  }

  // Note it will return nil if there is no description field
  public var descriptionPath: ResourceType.FieldPath? {
    self.type.fieldSpecification(for: \.description)?.path
  }

  // Note it will return nil if there is no description field
  // or if it is encrypted and secret part is not fetched
  public var descriptionString: String? {
    self.description.stringValue
  }

  // Note it will return null if there is no description field
  // or if it is encrypted and secret part is not fetched
  public var description: JSON {
    if let path: FieldPath = self.descriptionPath {
      return self[keyPath: path]
    }
    else {
      return .null
    }
  }
}

// MARK: - internal

extension Resource {

  // Initialize fields is required for creating new instances
  // of resources in order to have a proper fields structure
  // inside JSON representation. It should not modify any data
  // that is already provided (initialize only null fields and
  // only if those are required) initializing fields to null
  // seems to be unnecessary but it is required to have
  // a proper structure inside JSON.
  private mutating func initializeFieldsIfNeeded() {
    for field in self.fields where self[keyPath: field.path] == .null {
      // do not initialize secret in resources without secret
      // unless it is local
      guard self.isLocal || !field.encrypted || self.secretAvailable
      else { continue }  // skip field

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
      case .list:
        self[keyPath: field.path] = .array([])
      case .undefined:
        break  // can't initialize undefined fields
      }
    }
  }
}
