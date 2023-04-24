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
public struct Resource {

  public typealias ID = Tagged<String, Self>

  public enum Favorite {

    public typealias ID = Tagged<String, Self>
  }

  public let id: Resource.ID?  // none is local, not synchronized resource
  public var path: OrderedSet<ResourceFolderPathItem>
  public var type: ResourceType
  public var favoriteID: Resource.Favorite.ID?
  public var permission: Permission
  public var permissions: OrderedSet<ResourcePermission>
  public var tags: OrderedSet<ResourceTag>
  public let modified: Timestamp?  // local resources does not have modified date
  private var fieldValues: Dictionary<ResourceField.ValuePath, ResourceFieldValue>

  public init(
    id: Resource.ID? = .none,
    path: OrderedSet<ResourceFolderPathItem> = .init(),
    favoriteID: Resource.Favorite.ID? = .none,
    type: ResourceType,
    permission: Permission = .owner,
    tags: OrderedSet<ResourceTag> = .init(),
    permissions: OrderedSet<ResourcePermission> = .init(),
    modified: Timestamp? = .none
  ) {
    self.id = id
    self.path = path
    self.favoriteID = favoriteID
    self.type = type
    self.permission = permission
    self.tags = tags
    self.permissions = permissions
    self.modified = modified
    self.fieldValues = .init()
  }

  public subscript(
    dynamicMember keyPath: ResourceField.ValuePath
  ) -> ResourceFieldValue? {
    get {
      if self.type.contains(keyPath) {
        return self.fieldValues[keyPath]
      }
      else {
        return .none
      }
    }
    set {
      guard self.type.contains(keyPath) else { return }
      self.fieldValues[keyPath] = newValue
    }
  }

  public static func keyPath(
    for field: ResourceField
  ) -> WritableKeyPath<Resource, ResourceFieldValue?> {
    \Resource[dynamicMember:field.valuePath]
  }

  public func value(
    for field: ResourceField
  ) -> ResourceFieldValue? {
    value(for: field.valuePath)
  }

  public func value(
    forField name: StaticString
  ) -> ResourceFieldValue? {
    value(for: ResourceField.valuePath(forName: name))
  }

  private func value(
    for path: ResourceField.ValuePath
  ) -> ResourceFieldValue? {
    guard let field: ResourceField = self.type.fields.first(where: { $0.valuePath == path })
    else { return .none }
    return self.fieldValues[field.valuePath]
      ?? (field.encrypted ? .encrypted : .none)
  }

  public mutating func set(
    _ value: ResourceFieldValue?,
    for field: ResourceField
  ) throws {
    try self.set(
      value,
      for: field.valuePath
    )
  }

  public mutating func set(
    _ value: ResourceFieldValue?,
    forField name: StaticString
  ) throws {
    try self.set(
      value,
      for: ResourceField.valuePath(forName: name)
    )
  }

  private mutating func set(
    _ value: ResourceFieldValue?,
    for path: ResourceField.ValuePath
  ) throws {
    guard let field: ResourceField = self.type.fields.first(where: { $0.valuePath == path })
    else {
      throw
        InvalidResourceData
        .error(
          message: "Trying to set non existing field value!"
        )
    }
    guard field.accepts(value)
    else {
      throw
        InvalidResourceData
        .error(
          message: "Trying to set wrong field value!"
        )
    }
    self.fieldValues[field.valuePath] = value
  }

  public func validate() throws {
    for field in self.fields {
      let error: TheError? = field
        .validator
        .contraMapOptional()
        .validate(self.value(for: field))
        .error
      if let error {
        throw error
      }
      else {
        continue
      }
    }
  }
}

extension Resource: Equatable {}

extension Resource {

  public var parentFolderID: ResourceFolder.ID? {
    self.path.last?.id
  }

  public var favorite: Bool {
    self.favoriteID != .none
  }

  public var fields: OrderedSet<ResourceField> {
    self.type.fields
  }

  public var encryptedFields: OrderedSet<ResourceField> {
    self.type.fields.filter(\.encrypted).asOrderedSet()
  }
}

extension Resource.ID {

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

extension Resource.Favorite.ID {

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
