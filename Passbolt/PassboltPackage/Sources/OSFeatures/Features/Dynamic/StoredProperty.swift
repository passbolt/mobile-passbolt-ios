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

// MARK: - Interface

@dynamicMemberLookup
public struct StoredProperty<Value>: Sendable
where Value: Sendable {
  public var binding: StateBinding<Value?>
}

extension StoredProperty: LoadableFeature {

  public typealias Context = OSStoredPropertyKey
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
    context key: OSStoredPropertyKey,
    removeDuplicates: @escaping (Value?, Value?) -> Bool,
    cancellables: Cancellables
  ) throws -> Self {
    let storedProperties: OSStoredProperties = features.instance()

    @Sendable nonisolated func fetch() -> Value? {
      storedProperties
        .fetch(key) as? Value
    }

    @Sendable nonisolated func store(
      _ property: Value?
    ) {
      storedProperties
        .store(key, property)
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
    context key: OSStoredPropertyKey,
    removeDuplicates: @escaping (Value?, Value?) -> Bool,
    cancellables: Cancellables
  ) throws -> Self
  where Value: RawRepresentable {
    let storedProperties: OSStoredProperties = features.instance()

    @Sendable nonisolated func fetch() -> Value? {
      (storedProperties
        .fetch(key) as? Value.RawValue)
        .flatMap(Value.init(rawValue:))
    }

    @Sendable nonisolated func store(
      _ property: Value?
    ) {
      storedProperties
        .store(key, property?.rawValue)
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

  public mutating func usePassboltStoredProperty<Property: Equatable>(
    _: Property.Type
  ) {
    self.usePassboltStoredProperty(
      Property.self,
      removeDuplicates: ==
    )
  }

  public mutating func usePassboltStoredProperty<Property>(
    _: Property.Type,
    removeDuplicates: @escaping (Property?, Property?) -> Bool
  ) {
    self.use(
      .lazyLoaded(
        StoredProperty<Property>.self,
        load: {
          (features: Features, context: StoredProperty.Context, cancellables: Cancellables) -> StoredProperty in
          try StoredProperty<Property>.load(
            features: features,
            context: context,
            removeDuplicates: removeDuplicates,
            cancellables: cancellables
          )
        }
      )
    )
  }

  public mutating func usePassboltStoredRawProperty<Property>(
    _: Property.Type
  ) where Property: RawRepresentable & Equatable {
    self.usePassboltStoredRawProperty(
      Property.self,
      removeDuplicates: ==
    )
  }

  public mutating func usePassboltStoredRawProperty<Property>(
    _: Property.Type,
    removeDuplicates: @escaping (Property?, Property?) -> Bool
  ) where Property: RawRepresentable {
    self.use(
      .lazyLoaded(
        StoredProperty<Property>.self,
        load: {
          (features: Features, context: StoredProperty.Context, cancellables: Cancellables) -> StoredProperty in
          try StoredProperty<Property>.loadRaw(
            features: features,
            context: context,
            removeDuplicates: removeDuplicates,
            cancellables: cancellables
          )
        }
      )
    )
  }
}

#if DEBUG

extension StoredProperty {

  public nonisolated static var placeholder: Self {
    Self(
      binding: .placeholder
    )
  }
}
#endif
