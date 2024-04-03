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
import CryptoKit
import Foundation

extension JWT {

  public var signedPayload: String {
    var components: Array<String> = rawValue.components(separatedBy: ".")
    _ = components.popLast()

    return components.joined(separator: ".")
  }

  public func isExpired(
    timestamp: Timestamp,
    leeway: UInt = 0
  ) -> Bool {
    timestamp.rawValue + Int64(leeway) >= payload.expiration
  }
}

extension JWT {

  private static func decode(
    _ token: String
  ) -> Result<(header: Header, payload: Payload, signature: Signature), Error> {
    var components: Array<String> = token.components(separatedBy: ".")

    guard components.count == 3, let signature: Signature = components.popLast().map(Signature.init(rawValue:)) else {
      return .failure(
        JWTInvalid.error(
          underlyingError:
            DataInvalid
            .error("JWT decoding failed due to invalid components count")
            .recording(token, for: "token")
        )
      )
    }

    return decode(
      type: Payload.self,
      from: components.popLast()
    )
    .flatMap { payload in
      decode(
        type: Header.self,
        from: components.popLast()
      )
      .map { header in
        (header: header, payload: payload, signature: signature)
      }
    }
  }

  private static func decode<T: Decodable>(
    type: T.Type,
    from input: String?
  ) -> Result<T, Error> {
    guard
      let value = input,
      let preprocessed: Data = value.base64DecodeFromURLEncoded()
    else {
      return .failure(
        JWTInvalid.error(
          underlyingError:
            DataInvalid
            .error("JWT decoding failed")
            .recording(input as Any, for: "input")
        )
      )
    }

    return Result(
      catching: {
        try JSONDecoder.default.decode(type, from: preprocessed)

      })
      .mapError { error in
        JWTInvalid.error(
          underlyingError:
            DataInvalid
            .error("JWT decoding failed")
            .recording(input as Any, for: "input")
            .recording(error, for: "decodingError")
        )
      }
  }
}

extension JWT {

  public static func from(rawValue: String) -> Result<Self, Error> {
    JWT.decode(rawValue)
      .map {
        .init(
          header: $0.header,
          payload: $0.payload,
          signature: $0.signature,
          rawValue: rawValue
        )
      }
  }
}
