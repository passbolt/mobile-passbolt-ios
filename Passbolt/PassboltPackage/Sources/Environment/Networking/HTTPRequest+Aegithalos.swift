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

import Aegithalos
import Commons
import struct Foundation.Data
import class Foundation.JSONEncoder
import struct Foundation.URL
import struct Foundation.URLComponents
import struct Foundation.URLQueryItem

extension Mutation where Subject == HTTPRequest {

  public static func scheme(
    _ scheme: String
  ) -> Self {
    Self { request in
      request.scheme = scheme
    }
  }
  
  public static func url(
    _ url: URL
  ) -> Self {
    Self { request in
      request.url = url
    }
  }
  
  public static func url(
    string: String
  ) -> Self {
    Self { request in
      request.urlComponents = URLComponents(string: string) ?? .init()
    }
  }
  
  public static func url(
    _ urlString: StaticString
  ) -> Self {
    Self { request in
      // swiftlint:disable force_unwrapping
      request.url = URL(string: "\(urlString)")!
      // swiftlint:enable force_unwrapping
    }
  }
  
  public static func host(
    _ host: String
  ) -> Self {
    Self { request in
      request.host = host
    }
  }
  
  public static func port(
    _ port: Int
  ) -> Self {
    Self { request in
      request.port = port
    }
  }
  
  public static func method(
    _ method: HTTPMethod
  ) -> Self {
    Self { request in
      request.method = method
    }
  }
  
  public static func pathPrefix(
    _ path: String
  ) -> Self {
    Self { request in
      if request.path.hasPrefix("/") && path.hasSuffix("/") {
        request.path = "\(path)\(request.path.dropFirst())"
      } else if request.path.hasPrefix("/") && !path.hasSuffix("/") {
        request.path = "\(path)\(request.path)"
      } else if !request.path.hasPrefix("/") && path.hasSuffix("/") {
        request.path = "\(path)\(request.path)"
      } else {
        request.path = "\(path)/\(request.path)"
      }
    }
  }
  
  public static func path(
    _ path: String
  ) -> Self {
    Self { request in
      request.path = path
    }
  }
  
  public static func pathSuffix(
    _ path: String
  ) -> Self {
    Self { request in
      if request.path.hasSuffix("/") && path.hasPrefix("/") {
        request.path = "\(request.path)\(path.dropFirst())"
      } else if request.path.hasSuffix("/") && !path.hasPrefix("/") {
        request.path.append(path)
      } else if !request.path.hasSuffix("/") && path.hasPrefix("/") {
        request.path.append(path)
      } else {
        request.path.append("/\(path)")
      }
    }
  }
  
  public static func queryItem(
    _ itemName: String,
    value: String
  ) -> Self {
    Self { request in
      request.urlQuery.append(URLQueryItem(name: itemName, value: value))
    }
  }
  
  public static func header(
    _ headerName: String,
    value: String
  ) -> Self {
    Self { request in
      request.headers[headerName] = value
    }
  }
  
  public static func body(
    _ body: Data
  ) -> Self {
    Self { request in
      request.body = body
    }
  }
  
  public static func jsonBody<Body>(
    from body: Body,
    using encoder: JSONEncoder = .init()
  ) -> Self
  where Body: Encodable {
    Self { request in
      #if DEBUG
      do {
        request.body = try JSONEncoder().encode(body)
      } catch {
        unreachable("Failing request body encoding - \(error)")
      }
      #else
      request.body = (try? JSONEncoder().encode(body)) ?? Data()
      #endif
      request.headers["Content-Type"] = "application/json"
    }
  }
}
