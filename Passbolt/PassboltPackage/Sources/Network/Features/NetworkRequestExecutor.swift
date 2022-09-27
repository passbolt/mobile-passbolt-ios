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

import Features

import struct Foundation.Data
import class Foundation.HTTPURLResponse
import class Foundation.JSONSerialization
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

// MARK: - Interface

/// NetworkRequestExecutor provides access
/// to generic HTTPRequest execution.
public struct NetworkRequestExecutor {
  /// Execute HTTPRequest using os network stack.
  public var execute: @Sendable (HTTPRequest) async throws -> HTTPResponse

  public init(
    execute: @escaping @Sendable (HTTPRequest) async throws -> HTTPResponse
  ) {
    self.execute = execute
  }
}

extension NetworkRequestExecutor: LoadableContextlessFeature {

  #if DEBUG
  public nonisolated static var placeholder: Self {
    Self(
      execute: unimplemented()
    )
  }
  #endif
}

// MARK: - Implementation

extension NetworkRequestExecutor {

  @MainActor fileprivate static func load(
    features: FeatureFactory,
    cancellables _: Cancellables
  ) async throws -> Self {
    let diagnostics: Diagnostics = features.instance()

    let urlSessionConfiguration: URLSessionConfiguration = .ephemeral
    urlSessionConfiguration.networkServiceType = .responsiveData
    urlSessionConfiguration.requestCachePolicy = .reloadIgnoringLocalAndRemoteCacheData
    urlSessionConfiguration.httpCookieAcceptPolicy = .never
    urlSessionConfiguration.httpShouldSetCookies = false
    urlSessionConfiguration.httpCookieStorage = .none
    urlSessionConfiguration.allowsCellularAccess = true
    urlSessionConfiguration.allowsConstrainedNetworkAccess = true
    urlSessionConfiguration.allowsExpensiveNetworkAccess = true
    urlSessionConfiguration.httpShouldUsePipelining = true
    urlSessionConfiguration.timeoutIntervalForResource = 10
    urlSessionConfiguration.timeoutIntervalForRequest = 10
    urlSessionConfiguration.waitsForConnectivity = false
    let sessionDelegate: URLSessionDelegate = .init()
    let urlSession: URLSession = .init(
      configuration: urlSessionConfiguration,
      delegate: sessionDelegate,
      delegateQueue: nil
    )

    @Sendable nonisolated func execute(
      _ httpRequest: HTTPRequest
    ) async throws -> HTTPResponse {
      guard let urlRequest: URLRequest = httpRequest.urlRequest()
      else {
        throw
          HTTPRequestInvalid
          .error(
            "Failed to prepare valid HTTP request",
            request: httpRequest,
            response: nil
          )
      }

      let httpResponse: HTTPResponse
      do {
        let result: (data: Data, response: URLResponse) = try await urlSession.data(for: urlRequest)

        if let httpURLResponse: HTTPURLResponse = result.response as? HTTPURLResponse,
          let response: HTTPResponse = HTTPResponse(from: httpURLResponse, with: result.data)
        {
          httpResponse = response
        }
        else {
          throw
            HTTPResponseInvalid
            .error(
              "ServerResponseInvalid - Cannot create HTTPResponse",
              request: httpRequest
            )
            .recording(result.response, for: "response")
            .recording(result.data, for: "body")
        }
      }
      catch let urlError as URLError {
        throw mapURLErrors(
          urlError,
          request: httpRequest,
          serverURL: httpRequest.url?.serverURLString ?? "N/A"
        )
      }
      catch let error as HTTPResponseInvalid {
        throw error
      }
      catch {
        throw
          Unidentified
          .error(
            "Unidentified network error",
            underlyingError: error
          )
          .recording(httpRequest, for: "request")
      }

      return try withVerifiedStatusCode(
        httpRequest: httpRequest,
        httpResponse: httpResponse
      )
    }

    nonisolated func withLogs(
      _ execute: @escaping @Sendable (HTTPRequest) async throws -> HTTPResponse
    ) -> @Sendable (HTTPRequest) async throws -> HTTPResponse {
      { (httpRequest: HTTPRequest) async throws -> HTTPResponse in
        let trace: Diagnostics.Trace = diagnostics.trace()
        trace.log(
          diagnostic: "HTTP",
          unsafe: httpRequest.method.rawValue,
          httpRequest.path
        )
        trace.log(debug: "Network request: \(httpRequest.debugDescription)")
        do {
          let httpResponse: HTTPResponse = try await execute(httpRequest)
          trace.log(
            diagnostic: "HTTP",
            unsafe: httpResponse.statusCode,
            httpRequest.path
          )
          trace.log(debug: "Network response: \(httpResponse.debugDescription)")
          return httpResponse
        }
        catch {
          trace.log(
            error: error,
            info: .message("Network call failed.")
          )
          throw error
        }
      }
    }

    return Self(
      execute: withLogs(execute(_:))
    )
  }
}

extension FeatureFactory {

  internal func usePassboltNetworkRequestExecutor() {
    self.use(
      .lazyLoaded(
        NetworkRequestExecutor.self,
        load: NetworkRequestExecutor
          .load(features:cancellables:)
      )
    )
  }
}

private final class URLSessionDelegate: NSObject, URLSessionTaskDelegate {

  fileprivate func urlSession(
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

extension HTTPRequest {

  fileprivate func urlRequest() -> URLRequest? {
    guard
      var urlRequest: URLRequest = url.map({ URLRequest(url: $0) })
    else { return nil }

    urlRequest.httpMethod = "\(method.rawValue)"
    urlRequest.httpBody = body
    urlRequest.allHTTPHeaderFields = headers
    urlRequest.timeoutInterval = 30
    urlRequest.cachePolicy = .reloadIgnoringLocalAndRemoteCacheData
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

private func withVerifiedStatusCode(
  httpRequest: HTTPRequest,
  httpResponse: HTTPResponse
) throws -> HTTPResponse {
  if 200..<300 ~= httpResponse.statusCode {
    return httpResponse
  }
  else if httpResponse.statusCode == 302,
    let locationString: String = httpResponse.headers["Location"],
    let locationURL: URL = .init(string: locationString)
  {
    throw
      HTTPRedirect
      .error(
        request: httpRequest,
        response: httpResponse,
        location: locationURL
      )
  }
  else if httpResponse.statusCode == 400 {
    if let validationViolations: Dictionary<String, Any> = try JSONSerialization.jsonObject(
      with: httpResponse.body,
      options: .init()
    ) as? Dictionary<String, Any> {
      throw
        NetworkRequestValidationFailure
        .error(
          validationViolations: validationViolations
        )
        .recording(httpRequest, for: "request")
        .recording(httpResponse, for: "response")
    }
    else {
      throw
        HTTPRequestInvalid
        .error(
          request: httpRequest,
          response: httpResponse
        )
    }
  }
  else if httpResponse.statusCode == 401 {
    throw
      HTTPUnauthorized
      .error(
        request: httpRequest,
        response: httpResponse
      )
  }
  else if httpResponse.statusCode == 403 {
    throw
      HTTPForbidden
      .error(
        request: httpRequest,
        response: httpResponse
      )
  }
  else if httpResponse.statusCode == 404 {
    throw
      HTTPNotFound
      .error(
        request: httpRequest,
        response: httpResponse
      )
  }
  else {
    throw
      HTTPStatusCodeUnexpected
      .error(
        "HTTP status code is not matching expected",
        request: httpRequest,
        response: httpResponse
      )
  }
}
