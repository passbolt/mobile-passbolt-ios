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
import class CoreNFC.NFCNDEFMessage
import class CoreNFC.NFCNDEFPayload
import struct Foundation.CharacterSet
import struct Foundation.Data
import struct Foundation.URL

public struct NDEFParser {

  public var parse: (Array<NFCNDEFMessage>) -> String?
}

extension NDEFParser {

  public static func yubikeyOTPParser() -> Self {

    func validate(token: String?) -> Bool {
      // validate length
      guard let token = token, (32...64) ~= token.count
      else { return false }

      // mod hex characters are legal
      let illegalCharacters: CharacterSet = .init(charactersIn: "bcdefghijklnrtuv").inverted
      return token.rangeOfCharacter(from: illegalCharacters) == .none
    }

    func uriToken(from uri: String) -> String? {
      let components: Array<String> = uri.components(separatedBy: "/")

      var token: String?

      if components.count > 1 {
        token = uri.components(separatedBy: "/").last
      }
      else {
        // payload is the actual value
        token = uri
      }

      guard var token = token
      else { return nil }

      if token.starts(with: "#") {
        token = token.replacingOccurrences(of: "#", with: "")
      }
      else {
        /* NOP */
      }

      return validate(token: token) ? token : nil
    }

    func textToken(from payload: String) -> String? {
      let components: Array<String> = payload.components(separatedBy: "/")

      if components.count > 1 {
        return validate(token: components.last) ? components.last : nil
      }
      else {
        return validate(token: payload) ? payload : nil
      }
    }

    func payload(from data: Data) -> String? {
      .init(data: data, encoding: .utf8)
    }

    func parse(message: NFCNDEFMessage) -> String? {
      for record in message.records where record.typeNameFormat == .nfcWellKnown {
        guard
          let payload = payload(from: record.payload),
          record.hasURI() || record.hasText()
        else { continue }

        switch (record.hasURI(), record.hasText()) {
        case (true, false):
          return uriToken(from: payload)
        case (false, true):
          return textToken(from: payload)
        case _:
          unreachable("Record cannot have both types at the same time")
        }
      }

      return nil
    }

    func parse(messages: Array<NFCNDEFMessage>) -> String? {
      for message in messages {
        guard let token = parse(message: message)
        else { continue }

        return token
      }

      return nil
    }

    return Self(
      parse: parse(messages:)
    )
  }
}

internal enum PayloadType: UInt8 {

  case text = 0x54
  case uri = 0x55
}

extension NFCNDEFPayload {

  fileprivate func hasURI() -> Bool {
    type.first == PayloadType.uri.rawValue
  }

  fileprivate func hasText() -> Bool {
    type.first == PayloadType.text.rawValue
  }
}
