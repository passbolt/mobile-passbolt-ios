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

import Combine
import struct Foundation.Data
import struct Foundation.URLError
import class Foundation.URLSession
import class Foundation.URLResponse
import struct Foundation.URLRequest

public struct Networking {
  
  public var execute: (
    _ request: HTTPRequest
  ) -> AnyPublisher<HTTPResponse, HTTPRequestError>
}

extension Networking {
  
  public func make(
    _ request: HTTPRequest
  ) -> AnyPublisher<HTTPResponse, HTTPRequestError> {
    execute(request)
  }
}

extension Networking {
 
  private static let urlSession: URLSession = .init(configuration: .ephemeral)
  
  public static func foundation() -> Self {
    Self(
      execute: { request in
        guard
          let urlRequest = request.urlRequest
        else {
          return Fail<HTTPResponse, HTTPRequestError>(
            error: .invalidRequest(request)
          )
          .eraseToAnyPublisher()
        }
        return urlSession
          .dataTaskPublisher(for: urlRequest)
          .mapError(mapURLErrors)
          .flatMap { data, response -> AnyPublisher<HTTPResponse, HTTPRequestError> in
            if let httpResponse: HTTPResponse = HTTPResponse(from: response, with: data) {
              return Just(httpResponse)
                .setFailureType(to: HTTPRequestError.self)
                .eraseToAnyPublisher()
            } else {
              return Fail<HTTPResponse, HTTPRequestError>(
                error: .invalidResponse
              )
              .eraseToAnyPublisher()
            }
          }
          .eraseToAnyPublisher()
      }
    )
  }
}

private func mapURLErrors(
  _ error: URLError
) -> HTTPRequestError {
  switch error.code {
  case .cancelled:
    return .canceled
    
  case .notConnectedToInternet, .cannotFindHost:
    return .cannotConnect
    
  case .timedOut:
    return .timeout
    
  case _: // fill more errors if needed
    return .other(error)
  }
}
