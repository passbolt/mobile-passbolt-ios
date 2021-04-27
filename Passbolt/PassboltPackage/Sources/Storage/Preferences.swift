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
  
  public var load: (String) -> Any?
  public var save: (String, Any) -> Void
}

extension Preferences {
  
  public static func userDefaults(
    _ defaults: UserDefaults = .standard
  ) -> Self {
    Self(
      load: { key in
        defaults.value(forKey: key)
      },
      save: { key, value in
        let typeOfValue: Any.Type = type(of: value)
        assert(
          typeOfValue == Data.self
            || typeOfValue == Data?.self
            || typeOfValue == String.self
            || typeOfValue == String?.self
            || typeOfValue == Int.self
            || typeOfValue == Int?.self
            || typeOfValue == Bool.self
            || typeOfValue == Bool?.self
            || typeOfValue == Array<Int>.self
            || typeOfValue == Array<Int>?.self
            || typeOfValue == Array<String>.self
            || typeOfValue == Array<String>?.self
            || typeOfValue == Dictionary<String, Int>.self
            || typeOfValue == Dictionary<String, Int>?.self
            || typeOfValue == Dictionary<String, String>.self
            || typeOfValue == Dictionary<String, String>?.self,
          "Data type (\(typeOfValue)) is not supported by Preferences backed by UserDefaults"
        )
        defaults.setValue(value, forKey: key)
      }
    )
  }
}

extension Preferences {
  
  public func load<Value>(
    _ type: Value.Type = Value.self,
    for key: String
  ) -> Value? {
    load(key) as? Value
  }
  
  public func save<Value>(
    _ value: Value,
    for key: String
  ) {
    save(key, value)
  }
  
  public func load(
    _ type: UUID.Type = UUID.self,
    for key: String
  ) -> UUID? {
    (load(key) as? String)
      .flatMap(UUID.init(uuidString:))
  }
  
  public func save(
    _ value: UUID,
    for key: String
  ) {
    save(key, value.uuidString)
  }
}

extension Preferences {
  
  internal static var forTesting: Self {
    Self(
      load: unreachable("Please use mock or verify your tests"),
      save: unreachable("Please use mock or verify your tests")
    )
  }
}
