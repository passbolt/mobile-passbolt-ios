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
public struct StoredProperty<Value> {

  public var binding: ValueBinding<Value?>
}

extension StoredProperty: LoadableFeature {

  public typealias Context = StoredPropertyKey
}

extension StoredProperty {

  public var value: Value? {
    get { self.binding.get() }
    set { self.binding.set(newValue) }
  }

  public subscript<Property>(
    dynamicMember keyPath: KeyPath<Value, Property>
  ) -> Property? {
    if let value: Value = self.binding.get() {
      return value[keyPath: keyPath]
    }
    else {
      return .none
    }
  }
}

// MARK: - Implementation

extension StoredProperty {

  @FeaturesActor fileprivate static func load(
    features: FeatureFactory,
    context key: StoredPropertyKey,
    cancellables: Cancellables
  ) async throws -> Self {
    unowned let features: FeatureFactory = features
    let storedProperties: StoredProperties = features.instance()

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
      binding: .init(
        get: fetch,
        set: store(_:)
      )
    )
  }
}

extension FeatureFactory {

  @FeaturesActor public func usePassboltStoredProperty<Property>(
    _: Property.Type
  ) {
    self.use(
      .lazyLoaded(
        StoredProperty<Property>.self,
        load: StoredProperty<Property>.load(features:context:cancellables:)
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
