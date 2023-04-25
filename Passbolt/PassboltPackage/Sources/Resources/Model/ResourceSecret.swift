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

import CommonModels
import Commons

import struct Foundation.Data
import class Foundation.JSONDecoder

public struct ResourceSecret {

  public let rawValue: String
  private var values: Dictionary<String, ResourceFieldValue>

  internal init(
    rawValue: String,
    values: Dictionary<String, ResourceFieldValue>
  ) {
    self.rawValue = rawValue
    self.values = values
  }

  public func value(
    for field: ResourceField
  ) -> ResourceFieldValue {
    self.values[field.name] ?? .unknown(.null)
  }

  public func value(
    forField name: StaticString
  ) -> ResourceFieldValue {
    self.values[name.description] ?? .unknown(.null)
  }
}

extension ResourceSecret {

  public static func from(
    decrypted message: String,
    using decoder: JSONDecoder = .init()
  ) throws -> Self {
    // We are using Data in order to use JSONDecoder
    // It shouldn't ever fail but just in case that
    // secret cannot be represented in utf8
    // we treat it as an error.
    if let data: Data = message.data(using: .utf8) {
      do {
        return Self(
          rawValue: message,
          values: try decoder.decode(Dictionary<String, ResourceFieldValue>.self, from: data)
        )
      }
      catch {
        return Self(
          rawValue: message,
          values: ["password": .string(message)]
        )
      }
    }
    else {
      throw
        ResourceSecretInvalid
        .error()
        .asAssertionFailure()
    }
  }
}

extension ResourceSecret: Equatable {}
