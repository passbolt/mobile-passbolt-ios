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

import struct Foundation.Data
import class Foundation.UserDefaults

// MARK: - Interface

public struct StoredProperties {

  public var fetch: @Sendable (StoredPropertyKey) -> Any
  public var store: @Sendable (StoredPropertyKey, Any) -> Void
}

extension StoredProperties: StaticFeature {}

// MARK: - Implementation

extension StoredProperties {

  fileprivate static func sharedUserDefaults(
    suiteName: StaticString
  ) -> Self {
    guard
      let userDefaults: UserDefaults =
        .init(suiteName: "\(suiteName)")
    else {
      InternalInconsistency
        .error("Cannot access UserDefaults")
        .asFatalError()
    }

    @Sendable func fetch(
      _ key: StoredPropertyKey
    ) -> Any {
      userDefaults
        .value(forKey: key.rawValue) as Any
    }

    @Sendable func store(
      _ key: StoredPropertyKey,
      _ value: Any
    ) {
      #if DEBUG
      let typeOfValue: Any.Type = type(of: value)
      assert(
        supportedTypes.contains(ObjectIdentifier(typeOfValue)),
        "Type \(type(of: value)) is not supported by UserDefaults"
      )
      #endif
      return
        userDefaults
        .setValue(
          value,
          forKey: key.rawValue
        )
    }

    return Self(
      fetch: fetch(_:),
      store: store(_:_:)
    )
  }
}

#if DEBUG

private let supportedTypes: Set<ObjectIdentifier> = [
  ObjectIdentifier(Data.self),
  ObjectIdentifier(Data?.self),
  ObjectIdentifier(String.self),
  ObjectIdentifier(String?.self),
  ObjectIdentifier(Int.self),
  ObjectIdentifier(Int?.self),
  ObjectIdentifier(Bool.self),
  ObjectIdentifier(Bool?.self),
  ObjectIdentifier(Array<Int>.self),
  ObjectIdentifier(Array<Int>?.self),
  ObjectIdentifier(Array<String>.self),
  ObjectIdentifier(Array<String>?.self),
  ObjectIdentifier(Dictionary<String, Int>.self),
  ObjectIdentifier(Dictionary<String, Int>?.self),
  ObjectIdentifier(Dictionary<String, String>.self),
  ObjectIdentifier(Dictionary<String, String>?.self),
]
#endif

extension FeatureFactory {

  @FeaturesActor public func usePassboltSharedStoredProperties() {
    self.use(
      StoredProperties.sharedUserDefaults(suiteName: "group.com.passbolt.mobile")
    )
  }
}

#if DEBUG

extension StoredProperties {

  public static var placeholder: Self {
    Self(
      fetch: unimplemented(),
      store: unimplemented()
    )
  }
}
#endif
