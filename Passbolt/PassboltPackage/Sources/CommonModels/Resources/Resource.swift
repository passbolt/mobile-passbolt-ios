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

  public typealias ID = Tagged<UUID, Self>

  public enum Favorite {

    public typealias ID = Tagged<UUID, Self>
  }

  public typealias FieldPath = WritableKeyPath<Resource, JSON>

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
  private var metaPaths: Set<Resource.FieldPath>
  private var secretPaths: Set<Resource.FieldPath>
  private var validators: Dictionary<Resource.FieldPath, Validator<JSON>>

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
    self.metaPaths = .init()
    self.secretPaths = .init()
    self.validators = .init()
    self.updateCaches()
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
    let metaFields: OrderedSet<ResourceFieldSpecification> = self.metaFields
    let secretFields: OrderedSet<ResourceFieldSpecification> = self.secretFields
    var allFields: OrderedSet<ResourceFieldSpecification> = .init()
    allFields.reserveCapacity(metaFields.count + secretFields.count)
    allFields.append(contentsOf: metaFields)
    allFields.append(contentsOf: secretFields)
    return allFields
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

  public func validator(
    for path: Resource.FieldPath
  ) -> Validator<JSON> {
    self.validators[path]
      ?? .alwaysInvalid(displayable: "error.resource.field.unknown")
  }
}

extension Resource {

  fileprivate mutating func updateCaches() {
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

    func validators(
      for field: ResourceFieldSpecification
    ) -> Dictionary<Resource.FieldPath, Validator<JSON>> {
      var result: Dictionary<Resource.FieldPath, Validator<JSON>> = [field.path: field.validator]
      if case .structure(let nestedFields) = field.content {
        for field in nestedFields {
          result.merge(validators(for: field), uniquingKeysWith: { $1 })
        }
        return result
      }
      else {
        return result
      }
    }

    self.metaPaths.removeAll(keepingCapacity: true)
    self.secretPaths.removeAll(keepingCapacity: true)
    self.validators.removeAll(keepingCapacity: true)
    for field in self.metaFields {
      self.validators.merge(validators(for: field), uniquingKeysWith: { $1 })
      self.metaPaths.formUnion(paths(for: field))
    }

    for field in self.secretFields {
      self.validators.merge(validators(for: field), uniquingKeysWith: { $1 })
      self.secretPaths.formUnion(paths(for: field))
    }
  }
}

extension Resource {

  public func metaContains(
    _ path: Resource.FieldPath
  ) -> Bool {
    self.metaPaths.contains(path)
  }

  public func secretContains(
    _ path: Resource.FieldPath
  ) -> Bool {
    self.secretPaths.contains(path)
  }

  public func contains(
    _ path: Resource.FieldPath
  ) -> Bool {
    self.metaContains(path) || self.secretContains(path)
  }
}
