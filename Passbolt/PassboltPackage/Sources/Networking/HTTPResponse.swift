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
import struct Foundation.URL
import class Foundation.URLResponse
import class Foundation.HTTPURLResponse

public struct HTTPResponse {
  
  public var url: URL
  public var statusCode: HTTPStatusCode
  public var headers: HTTPHeaders
  public var body: HTTPBody
  
  public init(
    url: URL,
    statusCode: HTTPStatusCode,
    headers: HTTPHeaders,
    body: HTTPBody
  ) {
    self.url = url
    self.statusCode = statusCode
    self.headers = headers
    self.body = body
  }
}

extension HTTPResponse {
  
  internal init?(
    from response: URLResponse,
    with body: Data? = nil
  ) {
    guard
      let httpResponse = response as? HTTPURLResponse,
      let url = httpResponse.url
    else { return nil }
    self.init(
      url: url,
      statusCode: httpResponse.statusCode,
      headers: httpResponse.allHeaderFields as? Dictionary<String, String> ?? .init(),
      body: body ?? Data()
    )
  }
}

extension HTTPResponse: CustomStringConvertible {
  
  public var description: String {
    """
    HTTP/1.1 \(statusCode)
    \(headers.map { "\($0.key): \($0.value)" }.joined(separator: "\n"))
    
    \(String(data: body, encoding: .utf8) ?? "")
    """
  }
}

extension HTTPResponse: CustomDebugStringConvertible {
  
  public var debugDescription: String {
    description
  }
}
