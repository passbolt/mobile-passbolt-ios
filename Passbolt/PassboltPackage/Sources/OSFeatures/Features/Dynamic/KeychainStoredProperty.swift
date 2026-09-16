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

/// Description of a per account property stored in the keychain.
///
/// Use it instead of `StoredPropertyDescription` for settings which change security
/// behavior of the application. Application group user defaults are a plain property
/// list file which can be read and modified outside of the application, so a setting
/// kept there can be flipped by anyone able to reach that file.
public protocol KeychainStoredPropertyDescription {

  associatedtype Value: Codable & Sendable
  static var key: OSKeychainQuery.Key { get }
}

public struct KeychainStoredProperty<Description>: Sendable
where Description: KeychainStoredPropertyDescription {

  public typealias Value = Description.Value

  /// Cached access to the property. A keychain failure is indistinguishable from a missing
  /// value here - both become `.none`. Use `read` and `write` for decisions which must not
  /// fall back to a default without noticing that the keychain was unreachable.
  public var variable: StoredVariable<Value?>
  /// Reads the value directly from the keychain, bypassing the cache.
  /// Throws when the keychain is unreachable - `.none` means the value was never stored.
  public var read: @Sendable () throws -> Value?
  /// Writes the value directly to the keychain, bypassing the cache. `.none` removes it.
  /// Throws when the write did not land.
  ///
  /// The cached ``variable`` is not updated by this method, and it reads its backing storage
  /// only once - on first access - keeping that result for the rest of its lifetime. Writing
  /// after ``variable`` was first accessed leaves the two out of sync until the feature is
  /// reloaded, so use ``write`` only before that first access, or keep writing through
  /// ``variable`` instead.
  public var write: @Sendable (Value?) throws -> Void
}

extension KeychainStoredProperty: LoadableFeature {

  #if DEBUG

  public nonisolated static var placeholder: Self {
    Self(
      variable: .placeholder,
      read: unimplemented0(),
      write: unimplemented1()
    )
  }
  #endif
}

// MARK: - Implementation

extension KeychainStoredProperty {

  @MainActor fileprivate static func load(
    features: Features
  ) throws -> Self {
    let account: Account = try features.sessionAccount()
    let keychain: OSKeychain = features.instance()
    let query: OSKeychainQuery = .init(
      key: Description.key,
      tag: .init(rawValue: account.localID.rawValue),
      requiresBiometrics: false
    )

    @Sendable nonisolated func read() throws -> Value? {
      try keychain
        .loadFirst(Value.self, matching: query)
        .get()
    }

    @Sendable nonisolated func write(
      _ property: Value?
    ) throws {
      switch property {
      case .some(let value):
        try keychain
          .save(value, for: query)
          .get()

      case .none:
        try keychain
          .delete(matching: query)
          .get()
      }
    }

    @Sendable nonisolated func fetch() -> Value? {
      do {
        return try read()
      }
      catch {
        error.logged(
          info: .message("Failed to load keychain stored property")
        )
        return .none
      }
    }

    @Sendable nonisolated func store(
      _ property: Value?
    ) {
      do {
        try write(property)
      }
      catch {
        error.logged(
          info: .message("Failed to store keychain stored property")
        )
      }
    }

    return Self(
      variable: .init(
        fetch: fetch,
        store: store(_:)
      ),
      read: read,
      write: write(_:)
    )
  }
}

extension FeaturesRegistry {

  public mutating func usePassboltKeychainStoredProperty<Description, Scope>(
    _: Description.Type,
    in: Scope.Type
  ) where Description: KeychainStoredPropertyDescription, Scope: FeaturesScope {
    self.use(
      .lazyLoaded(
        KeychainStoredProperty<Description>.self,
        load: {
          (features: Features) -> KeychainStoredProperty in
          try KeychainStoredProperty<Description>
            .load(features: features)
        }
      ),
      in: Scope.self
    )
  }
}
