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
import CryptoKit
import Foundation

private let jsonDecoder: JSONDecoder = .init()
private let jsonEncoder: JSONEncoder = .init()

public struct JWT: Codable {
  public typealias Signature = String
  
  public var header: Header
  public var payload: Payload
  public var signature: Signature
  
  public let rawValue: String
}

extension JWT {
  
  public enum Algorithm: String, Codable, CaseIterable {
    case RS256 = "RS256"
  }
  
  public struct Header: Codable, Equatable {
    
    internal var algorithm: Algorithm
    internal var type: String
    
    private enum CodingKeys: String, CodingKey {
      case algorithm = "alg"
      case type = "typ"
    }
  }
  
  public struct Payload: Codable, Equatable {
    // https://datatracker.ietf.org/doc/html/rfc7519#section-4.1
    internal var audience: String?
    internal var expiration: Int // EPOCH
    internal var issuer: String?
    internal var subject: String?
    
    private enum CodingKeys: String, CodingKey {
      
      case audience = "aud"
      case expiration = "exp"
      case issuer = "iss"
      case subject = "sub"
    }
  }
  
  public var signedPayload: String {
    var components: Array<String> = rawValue.components(separatedBy: ".")
    _ = components.popLast()
    
    return components.joined(separator: ".")
  }
  
  public func isExpired(timestamp: Int) -> Bool {
    timestamp > payload.expiration
  }
}

extension JWT {
  
  private static func decode(
    _ token: String
  ) -> Result<(header: Header, payload: Payload, signature: String), TheError> {
    var components: Array<String> = token.components(separatedBy: ".")
    
    guard components.count == 3, let signature: Signature = components.popLast() else {
      return .failure(.jwtError().appending(context: "malformed-token"))
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
  ) -> Result<T, TheError> {
    guard let value = input,
      let preprocessed = value.base64DecodeFromURLEncoded(options: .ignoreUnknownCharacters) else {
      return .failure(.jwtError())
    }
    
    return Result(catching: { try jsonDecoder.decode(type, from: preprocessed) })
      .mapError { TheError.jwtError(underlyingError: $0) }
  }
}

extension JWT {

  public static func from(rawValue: String) -> Result<Self, TheError> {
    JWT.decode(rawValue).map {
      .init(
        header: $0.header,
        payload: $0.payload,
        signature: $0.signature,
        rawValue: rawValue
      )
    }
  }
}
