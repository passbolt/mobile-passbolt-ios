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
import struct Foundation.Data
import class Foundation.UserDefaults
import struct Foundation.UUID

public struct Preferences {
  
  public typealias Key = Tagged<String, Self>
  
  public var load: (Key) -> Any?
  public var save: (Any, Key) -> Void
}

extension Preferences {
  
  public static func sharedUserDefaults() -> Self {
    let defaults: UserDefaults
      = .init(suiteName: "group.com.passbolt.mobile")
      ?? .standard
    let supportedTypes: Set<ObjectIdentifier> = [
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
      ObjectIdentifier(Dictionary<String, String>?.self)
    ]
    
    func load(for key: Key) -> Any? {
      defaults.value(forKey: key.rawValue)
    }
    
    func save(value: Any, for key: Key) {
      let typeOfValue: Any.Type = type(of: value)
      assert(
        supportedTypes.contains(ObjectIdentifier(typeOfValue)),
        "Data type (\(type(of: value))) is not supported by Preferences backed by UserDefaults"
      )
      defaults.setValue(value, forKey: key.rawValue)
    }
    
    return Self(
      load: load(for:),
      save: save(value:for:)
    )
  }
}

extension Preferences {
  
  public func load(
    _ type: String.Type = String.self,
    for key: Key
  ) -> String? {
    load(key) as? String
  }

  public func save(
    _ value: String,
    for key: Key
  ) {
    save(value, key)
  }
  
  public func load<Value>(
    _ type: Value.Type = Value.self,
    for key: Key
  ) -> Value?
  where Value: RawRepresentable, Value.RawValue == String {
    load(key).flatMap { $0 as? Value.RawValue }.flatMap(Value.init(rawValue:))
  }
  
  public func save<Value>(
    _ value: Value,
    for key: Key
  ) where Value: RawRepresentable, Value.RawValue == String {
    save(value.rawValue, key)
  }
  
  public func load<Value>(
    _ type: Array<Value>.Type = Array<Value>.self,
    for key: Key
  ) -> Array<Value>
  where Value: RawRepresentable, Value.RawValue == String {
    load(key)
      .flatMap { $0 as? Array<Value.RawValue> }
      .map { $0.compactMap(Value.init(rawValue:)) }
      ?? []
  }
  
  public func save<Value>(
    _ value: Array<Value>,
    for key: Key
  ) where Value: RawRepresentable, Value.RawValue == String {
    save(value.map(\.rawValue), key)
  }
  
  public func load<Value>(
    _ type: Value.Type = Value.self,
    for key: Key
  ) -> Value?
  where Value: RawRepresentable, Value.RawValue == Int {
    load(key).flatMap { $0 as? Value.RawValue }.flatMap(Value.init(rawValue:))
  }
  
  public func save<Value>(
    _ value: Value,
    for key: Key
  ) where Value: RawRepresentable, Value.RawValue == Int {
    save(value.rawValue, key)
  }
  
  public func load<Value>(
    _ type: Array<Value>.Type = Array<Value>.self,
    for key: Key
  ) -> Array<Value>
  where Value: RawRepresentable, Value.RawValue == Int {
    load(key)
      .flatMap { $0 as? Array<Value.RawValue> }
      .map { $0.compactMap(Value.init(rawValue:)) }
      ?? []
  }
  
  public func save<Value>(
    _ value: Array<Value>,
    for key: Key
  ) where Value: RawRepresentable, Value.RawValue == Int {
    save(value.map(\.rawValue), key)
  }
}

#if DEBUG
extension Preferences {
  
  // placeholder implementation for mocking and testing, unavailable in release
  public static var placeholder: Self {
    Self(
      load: Commons.placeholder("You have to provide mocks for used methods"),
      save: Commons.placeholder("You have to provide mocks for used methods")
    )
  }
}
#endif
