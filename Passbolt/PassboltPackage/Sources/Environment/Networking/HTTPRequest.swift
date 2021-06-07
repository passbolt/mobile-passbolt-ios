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
import struct Foundation.URLComponents
import struct Foundation.URLRequest
import struct Foundation.URLQueryItem

public struct HTTPRequest {
  
  public var method: HTTPMethod
  public var headers: HTTPHeaders
  public var body: HTTPBody
  public var urlComponents: URLComponents
  
  public init(
    url: URL? = .none,
    method: HTTPMethod = .get,
    headers: HTTPHeaders = .empty,
    body: HTTPBody = .empty
  ) {
    self.method = method
    self.urlComponents = url
      .flatMap {
        URLComponents(url: $0, resolvingAgainstBaseURL: true)
      }
      ?? URLComponents()
    self.headers = headers
    self.body = body
  }
}

extension HTTPRequest {
  
  public var url: URL? {
    get { urlComponents.url }
    set {
      urlComponents = newValue
        .flatMap { URLComponents(url: $0, resolvingAgainstBaseURL: true) }
        ?? urlComponents
    }
  }
  
  public var scheme: String? {
    get { urlComponents.scheme }
    set { urlComponents.scheme = newValue }
  }
  
  public var host: String? {
    get { urlComponents.host }
    set { urlComponents.host = newValue }
  }
  
  public var port: Int? {
    get { urlComponents.port }
    set { urlComponents.port = newValue }
  }
  
  public var path: String {
    get { urlComponents.path }
    set { urlComponents.path = newValue }
  }
  /// Query component of this request's URL.
  public var urlQuery: Array<URLQueryItem> {
    get { urlComponents.queryItems ?? [] }
    set { urlComponents.queryItems = newValue }
  }
}

extension HTTPRequest: CustomStringConvertible {
  
  public var description: String {
    // swiftlint:disable line_length
    """
    \(method.rawValue) \(urlComponents.percentEncodedPath)\(urlComponents.percentEncodedQuery.map { "?\($0))" } ?? "") HTTP/1.1
    \(headers.map { "\($0.key): \($0.value)" }.joined(separator: "\n"))
    
    \(String(data: body, encoding: .utf8) ?? "")
    """
  }
  // swiftlint:enable line_length
}

extension HTTPRequest: CustomDebugStringConvertible {
  
  public var debugDescription: String {
    description
  }
}

extension HTTPRequest {
  
  internal func urlRequest(
    cachePolicy: URLRequest.CachePolicy = .reloadIgnoringLocalAndRemoteCacheData
  ) -> URLRequest? {
    guard
      var urlRequest: URLRequest = url.map({ URLRequest(url: $0) })
    else { return nil }
    
    urlRequest.httpMethod = method.rawValue
    urlRequest.httpBody = body
    urlRequest.allHTTPHeaderFields = headers
    urlRequest.timeoutInterval = 10
    urlRequest.cachePolicy = cachePolicy
    urlRequest.httpShouldHandleCookies = false
    return urlRequest
  }
}
