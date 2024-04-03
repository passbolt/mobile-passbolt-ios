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
import FeatureScopes

// MARK: - Interface

public protocol StoredPropertyDescription {

  associatedtype Value: Sendable
  static var shared: Bool { get }
  static var key: OSStoredPropertyKey { get }
}

extension StoredPropertyDescription {

  public static var shared: Bool { false }
}

@dynamicMemberLookup
public struct StoredProperty<Description>: Sendable
where Description: StoredPropertyDescription {

  public typealias Value = Description.Value

  public var binding: StateBinding<Value?>
}

extension StoredProperty: LoadableFeature {

  #if DEBUG

  public nonisolated static var placeholder: Self {
    Self(
      binding: .placeholder
    )
  }
  #endif
}

extension StoredProperty {

  public var value: Value? {
    get { self.binding.get() }
    set { self.binding.set(to: newValue) }
  }

  @Sendable public func set(
    to newValue: Value?
  ) {
    self.binding.set(to: newValue)
  }

  @Sendable public func get(
    withDefault value: Value
  ) -> Value {
    self.binding.get() ?? value
  }

  public subscript<Property>(
    dynamicMember keyPath: KeyPath<Value, Property>
  ) -> Property? {
    if let value: Value = self.binding.get(\.self) {
      return value[keyPath: keyPath]
    }
    else {
      return .none
    }
  }
}

// MARK: - Implementation

extension StoredProperty {

  @MainActor fileprivate static func load(
    features: Features,
    removeDuplicates: @escaping (Value?, Value?) -> Bool
  ) throws -> Self {
    let propertyKey: OSStoredPropertyKey
    if Description.shared {
      propertyKey = Description.key
    }
    else {
      let account: Account = try features.sessionAccount()
      propertyKey = "\(Description.key)-\(account.localID.rawValue)"
    }
    let storedProperties: OSStoredProperties = features.instance()

    @Sendable nonisolated func fetch() -> Value? {
      storedProperties
        .fetch(propertyKey) as? Value
    }

    @Sendable nonisolated func store(
      _ property: Value?
    ) {
      storedProperties
        .store(propertyKey, property)
    }

    return Self(
      binding: .fromSource(
        read: fetch,
        write: store(_:)
      )
    )
  }

  @MainActor fileprivate static func loadRaw(
    features: Features,
    removeDuplicates: @escaping (Value?, Value?) -> Bool
  ) throws -> Self
  where Value: RawRepresentable {
    let propertyKey: OSStoredPropertyKey
    if Description.shared {
      propertyKey = Description.key
    }
    else {
      let account: Account = try features.sessionAccount()
      propertyKey = "\(Description.key)-\(account.localID.rawValue)"
    }
    let storedProperties: OSStoredProperties = features.instance()

    @Sendable nonisolated func fetch() -> Value? {
      (storedProperties
        .fetch(propertyKey) as? Value.RawValue)
        .flatMap(Value.init(rawValue:))
    }

    @Sendable nonisolated func store(
      _ property: Value?
    ) {
      storedProperties
        .store(propertyKey, property?.rawValue)
    }

    return Self(
      binding: .fromSource(
        read: fetch,
        write: store(_:)
      )
    )
  }
}

extension FeaturesRegistry {

  public mutating func usePassboltStoredProperty<Description, Scope>(
    _: Description.Type,
    in: Scope.Type
  ) where Description: StoredPropertyDescription, Description.Value: Equatable, Scope: FeaturesScope {
    self.usePassboltStoredProperty(
      Description.self,
      in: Scope.self,
      removeDuplicates: ==
    )
  }

  public mutating func usePassboltStoredProperty<Description, Scope>(
    _: Description.Type,
    in: Scope.Type,
    removeDuplicates: @escaping (Description.Value?, Description.Value?) -> Bool
  ) where Description: StoredPropertyDescription, Scope: FeaturesScope {
    self.use(
      .lazyLoaded(
        StoredProperty<Description>.self,
        load: {
          (features: Features) -> StoredProperty in
          try StoredProperty<Description>
            .load(
              features: features,
              removeDuplicates: removeDuplicates
            )
        }
      ),
      in: Scope.self
    )
  }

  public mutating func usePassboltStoredRawProperty<Description, Scope>(
    _: Description.Type,
    in: Scope.Type
  )
  where Description: StoredPropertyDescription, Description.Value: RawRepresentable & Equatable, Scope: FeaturesScope {
    self.usePassboltStoredRawProperty(
      Description.self,
      in: Scope.self,
      removeDuplicates: ==
    )
  }

  public mutating func usePassboltStoredRawProperty<Description, Scope>(
    _: Description.Type,
    in: Scope.Type,
    removeDuplicates: @escaping (Description.Value?, Description.Value?) -> Bool
  ) where Description: StoredPropertyDescription, Description.Value: RawRepresentable, Scope: FeaturesScope {
    self.use(
      .lazyLoaded(
        StoredProperty<Description>.self,
        load: {
          (features: Features) -> StoredProperty in
          try StoredProperty<Description>
            .loadRaw(
              features: features,
              removeDuplicates: removeDuplicates
            )
        }
      ),
      in: Scope.self
    )
  }
}
