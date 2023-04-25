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
  internal var fieldValues: Dictionary<ResourceField.ValuePath, ResourceFieldValue>

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
    self.initializeFieldValues()
  }

  public subscript(
    dynamicMember keyPath: ResourceField.ValuePath
  ) -> ResourceFieldValue {
    get {
      if self.type.contains(keyPath) {
        return self.fieldValues[keyPath] ?? .unknown(.null)
      }
      else {
        return .unknown(.null)
      }
    }
    set {
      guard self.type.contains(keyPath) else { return }
      self.fieldValues[keyPath] = newValue
    }
  }
}

extension Resource {

  private mutating func initializeFieldValues() {
    for field in self.fields {
      let initialValue: ResourceFieldValue
      switch field.content {
      case .string(let encrypted, _, _, _):
        if encrypted {
          initialValue = .encrypted
        }
        else {
          initialValue = .string("")
        }

      case .totp:
        initialValue = .encrypted

      case .unknown(let encrypted, _):
        if encrypted {
          initialValue = .encrypted
        }
        else {
          initialValue = .unknown(.null)
        }
      }

      self.fieldValues[field.valuePath] = initialValue
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
