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

import Network

import class Foundation.JSONDecoder
import class Foundation.JSONSerialization
import struct Foundation.URL

internal struct NetworkResponseDecoder<Variable, Response> {

  internal var decode: (Variable, HTTPResponse) throws -> Response
}

extension NetworkResponseDecoder
where Response == Data {

  internal static var rawBody: Self {
    Self { _, response in
      response.body
    }
  }
}

extension NetworkResponseDecoder
where Response == String {

  internal static func bodyAsString(
    withEncoding encoding: String.Encoding = .utf8
  ) -> Self {
    Self { _, response in
      if let string: String = String(data: response.body, encoding: encoding) {
        return string
      }
      else {
        throw
          NetworkResponseDecodingFailure
          .error(
            "Failed to decode string body",
            response: response
          )
      }
    }
  }
}

extension NetworkResponseDecoder
where Response: Decodable {

  internal static func bodyAsJSON(
    using decoder: JSONDecoder = {
      let decoder: JSONDecoder = .init()
      decoder.dateDecodingStrategy = .iso8601
      return decoder
    }()
  ) -> Self {
    Self { _, httpResponse in
      do {
        return try decoder.decode(
          Response.self,
          from: httpResponse.body
        )
      }
      catch let error {
        throw
          NetworkResponseDecodingFailure
          .error(
            "Failed to decode bad request response",
            response: httpResponse,
            underlyingError: error
          )
      }
    }
  }
}
