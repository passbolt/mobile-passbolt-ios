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

import class Foundation.CachedURLResponse
import struct Foundation.Data
import class Foundation.HTTPURLResponse
import class Foundation.NSLock
import class Foundation.NSObject
import struct Foundation.URL
import class Foundation.URLCache
import struct Foundation.URLError
import struct Foundation.URLRequest
import class Foundation.URLResponse
import class Foundation.URLSession
import class Foundation.URLSessionConfiguration
import class Foundation.URLSessionTask
import protocol Foundation.URLSessionTaskDelegate

public struct Networking: EnvironmentElement {

  public var execute:
    (
      _ request: HTTPRequest,
      _ useCache: Bool
    ) async throws -> HTTPResponse

  public var clearCache: () -> Void

  public init(
    execute: @escaping (
      _ request: HTTPRequest,
      _ useCache: Bool
    ) async throws -> HTTPResponse,
    clearCache: @escaping () -> Void
  ) {
    self.execute = execute
    self.clearCache = clearCache
  }
}

extension Networking {

  public func make(
    _ request: HTTPRequest,
    useCache: Bool = false
  ) async throws -> HTTPResponse {
    try await execute(request, useCache)
  }
}

public final class URLSessionDelegate: NSObject, URLSessionTaskDelegate {

  public func urlSession(
    _ session: URLSession,
    task: URLSessionTask,
    willPerformHTTPRedirection response: HTTPURLResponse,
    newRequest request: URLRequest,
    completionHandler: @escaping (URLRequest?) -> Void
  ) {
    // Explicitly ignoring redirects
    completionHandler(nil)
  }
}

private let sessionDelegate: URLSessionDelegate = .init()

extension Networking {

  public static func foundation(
    _ urlSession: URLSession? = nil
  ) -> Self {
    let urlSession: URLSession =
      urlSession
      ?? {
        let urlSessionConfiguration: URLSessionConfiguration = .default
        urlSessionConfiguration.networkServiceType = .responsiveData
        urlSessionConfiguration.requestCachePolicy = .reloadIgnoringLocalAndRemoteCacheData
        urlSessionConfiguration.httpCookieAcceptPolicy = .never
        urlSessionConfiguration.httpShouldSetCookies = false
        urlSessionConfiguration.httpCookieStorage = .none
        urlSessionConfiguration.allowsCellularAccess = true
        urlSessionConfiguration.allowsConstrainedNetworkAccess = true
        urlSessionConfiguration.allowsExpensiveNetworkAccess = true
        urlSessionConfiguration.httpShouldUsePipelining = true
        urlSessionConfiguration.timeoutIntervalForResource = 30
        urlSessionConfiguration.timeoutIntervalForRequest = 30
        urlSessionConfiguration.waitsForConnectivity = true
        return URLSession(
          configuration: urlSessionConfiguration,
          delegate: sessionDelegate,
          delegateQueue: nil
        )
      }()

    let memoryCache: MemoryCache = .init()

    return Self(
      execute: { request, useCache in
        if useCache, let cachedResponse: HTTPResponse = await memoryCache.value(for: request) {
          return cachedResponse
        }
        else { /* NOP */
        }

        let urlRequest: URLRequest? = request.urlRequest(
          cachePolicy: .reloadIgnoringLocalAndRemoteCacheData
        )

        guard let url: URL = request.url
        else {
          throw
            URLInvalid
            .error(
              "Failed to prepare valid URL for HTTP request",
              rawString: request.urlComponents.description
            )
        }

        guard let urlRequest: URLRequest = urlRequest
        else {
          throw
            HTTPRequestInvalid
            .error(
              "Failed to prepare valid HTTP request",
              request: request,
              response: nil
            )
        }

        return try await withCheckedThrowingContinuation { continuation in
          urlSession
            .dataTask(with: urlRequest) { (data: Data?, response: URLResponse?, error: Error?) in
              if let error: Error = error {
                if let urlError: URLError = error as? URLError {
                  continuation
                    .resume(
                      throwing: mapURLErrors(
                        urlError,
                        request: request,
                        serverURL: url.serverURLString
                      )
                    )
                }
                else {
                  continuation
                    .resume(
                      throwing:
                        Unidentified
                        .error(
                          "Unidentified network error",
                          underlyingError: error
                        )
                        .recording(url.serverURLString, for: "serverURL")
                        .recording(request, for: "request")
                    )
                }
              }
              else if let urlResponse = response as? HTTPURLResponse,
                let httpResponse: HTTPResponse = HTTPResponse(from: urlResponse, with: data)
              {
                if useCache {
                  Task.detached {
                    await memoryCache.update(
                      value: httpResponse,
                      for: request
                    )
                  }
                }
                else {
                  /* NOP */
                }

                continuation.resume(returning: httpResponse)
              }
              else {
                continuation
                  .resume(
                    throwing:
                      HTTPResponseInvalid
                      .error(
                        "ServerResponseInvalid - Cannot create HTTPResponse",
                        request: request
                      )
                  )
              }
            }
            .resume()
        }
      },
      clearCache: {
        Task {
          await memoryCache.clear()
        }
      }
    )
  }
}

extension AppEnvironment {

  public var networking: Networking {
    get { element(Networking.self) }
    set { use(newValue) }
  }
}

#if DEBUG
extension Networking {

  // placeholder implementation for mocking and testing, unavailable in release
  public static var placeholder: Self {
    Self(
      execute: unimplemented("You have to provide mocks for used methods"),
      clearCache: unimplemented("You have to provide mocks for used methods")
    )
  }
}
#endif

extension HTTPRequest {

  fileprivate func urlRequest(
    cachePolicy: URLRequest.CachePolicy = .reloadIgnoringLocalAndRemoteCacheData
  ) -> URLRequest? {
    guard
      var urlRequest: URLRequest = url.map({ URLRequest(url: $0) })
    else { return nil }

    urlRequest.httpMethod = method.rawValue
    urlRequest.httpBody = body
    urlRequest.allHTTPHeaderFields = headers
    urlRequest.timeoutInterval = 30
    urlRequest.cachePolicy = cachePolicy
    urlRequest.httpShouldHandleCookies = false
    return urlRequest
  }
}

extension HTTPResponse {

  fileprivate init?(
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

// current cache implementation does not track
// ongoing requests - it should be improved in future
private final actor MemoryCache {

  private var cache: Dictionary<HTTPRequest, HTTPResponse> = .init()

  fileprivate func value(for request: HTTPRequest) -> HTTPResponse? {
    cache[request]
  }

  fileprivate func update(
    value response: HTTPResponse?,
    for request: HTTPRequest
  ) {
    // clear cache if exceeds 25 MB
    if cache.values.reduce(into: 0, { $0 += $1.body.count }) >= 26_214_400 {
      cache.removeAll()
    }
    else {
      /* NOP */
    }
    cache[request] = response
  }

  fileprivate func clear() {
    cache.removeAll()
  }
}

private func mapURLErrors(
  _ error: URLError,
  request: HTTPRequest,
  serverURL: URLString
) -> TheError {
  switch error.code {
  case .cancelled:
    return
      Cancelled
      .error("HTTP request cancelled")

  case .badURL, .unsupportedURL:
    return
      URLInvalid
      .error(
        "Invalid URL for HTTP request",
        rawString: request.url?.absoluteString ?? "N/A"
      )

  case .notConnectedToInternet:
    return
      InternetConnectionIssue
      .error("Not connected to the internet")

  case .cannotFindHost:
    return
      ServerConnectionIssue
      .error(
        "ServerConnectionIssue - Cannot find host",
        serverURL: serverURL
      )

  case .cannotConnectToHost:
    return
      ServerConnectionIssue
      .error(
        "ServerConnectionIssue - Cannot connect to host",
        serverURL: serverURL
      )

  case .dnsLookupFailed:
    return
      ServerConnectionIssue
      .error(
        "ServerConnectionIssue - DNS lookup failed",
        serverURL: serverURL
      )

  case .httpTooManyRedirects:
    return
      ServerConnectionIssue
      .error(
        "ServerConnectionIssue - Too many redirects",
        serverURL: serverURL
      )

  case .redirectToNonExistentLocation:
    return
      ServerConnectionIssue
      .error(
        "ServerConnectionIssue - Invalid redirect",
        serverURL: serverURL
      )

  case .secureConnectionFailed:
    return
      ServerConnectionIssue
      .error(
        "ServerConnectionIssue - Secure connection failed",
        serverURL: serverURL
      )

  case .appTransportSecurityRequiresSecureConnection:
    return
      ServerConnectionIssue
      .error(
        "ServerConnectionIssue - Insecure connection forbidden",
        serverURL: serverURL
      )

  case .serverCertificateHasBadDate:
    return
      ServerCertificateInvalid
      .error(
        "ServerCertificateInvalid - Bad certificate date",
        serverURL: serverURL
      )

  case .serverCertificateUntrusted:
    return
      ServerCertificateInvalid
      .error(
        "ServerCertificateInvalid - Untrusted certificate",
        serverURL: serverURL
      )

  case .serverCertificateHasUnknownRoot:
    return
      ServerCertificateInvalid
      .error(
        "ServerCertificateInvalid - Unknown root certificate",
        serverURL: serverURL
      )

  case .serverCertificateNotYetValid:
    return
      ServerCertificateInvalid
      .error(
        "ServerCertificateInvalid - Certificate not yet valid",
        serverURL: serverURL
      )

  case .clientCertificateRequired:
    return
      ClientCertificateInvalid
      .error("ClientCertificateInvalid - No client certificate.")

  case .clientCertificateRejected:
    return
      ClientCertificateInvalid
      .error("ClientCertificateInvalid - Client certificate rejected.")

  case .timedOut:
    return
      ServerResponseTimeout
      .error(
        "HTTP request timed out",
        serverURL: serverURL
      )

  case .badServerResponse:
    return
      ServerResponseInvalid
      .error("ServerResponseInvalid - Bad response")

  case .cannotParseResponse:
    return
      ServerResponseInvalid
      .error("ServerResponseInvalid - Cannot parse response")

  case .dataLengthExceedsMaximum:
    return
      ServerResponseInvalid
      .error("ServerResponseInvalid - Data length exceeds maximum")

  case .networkConnectionLost:
    return
      ServerConnectionIssue
      .error(
        "ServerConnectionIssue - Connection lost",
        serverURL: serverURL
      )

  case _:  // fill more errors if needed
    return
      Unidentified
      .error(
        "Unidentified network error",
        underlyingError: error
      )
      .recording(serverURL, for: "serverURL")
      .recording(request, for: "request")
  }
}
