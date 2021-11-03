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
import class Foundation.JSONDecoder

@dynamicMemberLookup
public struct ResourceSecret {

  private var values: Dictionary<String, String>

  internal init(
    values: Dictionary<String, String>
  ) {
    self.values = values
  }

  public subscript(
    dynamicMember key: String
  ) -> String? {
    values[key]
  }
}

extension ResourceSecret {

  internal static func from(
    decrypted message: String,
    using decoder: JSONDecoder = .init()
  ) -> Self? {
    // We are using Data in order to use JSONDecoder
    // It shouldn't ever fail but just in case that
    // secret cannot be represented in utf8
    // we treat it as an error.
    if let data: Data = message.data(using: .utf8) {
      do {
        return Self(
          values: try decoder.decode(Dictionary<String, String>.self, from: data)
        )
      }
      catch {
        return Self(
          values: ["password": message]
        )
      }
    }
    else {
      return nil
    }
  }
}
