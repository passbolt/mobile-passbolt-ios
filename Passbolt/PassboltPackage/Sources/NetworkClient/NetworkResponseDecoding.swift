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
import Environment
import struct Foundation.Data
import class Foundation.JSONDecoder

internal struct NetworkResponseDecoding<Response> {
  
  internal var decode: (HTTPResponse) -> Result<Response, TheError>
}

extension NetworkResponseDecoding where Response == Void {
  
  internal static func statusCode(
    _ statusCode: HTTPStatusCode
  ) -> Self {
    Self { response in
      if response.statusCode == statusCode {
        return .success(Void())
      } else {
        return .failure(.httpError(.invalidResponse))
      }
    }
  }
}

extension NetworkResponseDecoding where Response == Data {
  
  internal static var rawBody: Self {
    Self { response in
      .success(response.body)
    }
  }
}

extension NetworkResponseDecoding where Response == String {
  
  internal static func bodyAsString(
    withEncoding encoding: String.Encoding = .utf8
  ) -> Self {
    Self { response in
      if let string: String = String(data: response.body, encoding: encoding) {
        return .success(string)
      } else {
        return .failure(
          .networkResponseDecodingFailed(
            underlyingError: nil,
            rawNetworkResponse: response
          )
        )
      }
    }
  }
}

extension NetworkResponseDecoding where Response: Decodable {
  
  internal static func bodyAsJSON(
    using decoder: JSONDecoder = .init()
  ) -> Self {
    Self { response in
      do {
        return .success(
          try decoder.decode(
            Response.self,
            from: response.body
          )
        )
      } catch {
        return .failure(
          .networkResponseDecodingFailed(
            underlyingError: error,
            rawNetworkResponse: response
          )
        )
      }
    }
  }
}
