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
import Commons
import Environment

import struct Foundation.Data
import class Foundation.JSONDecoder
import class Foundation.JSONSerialization
import struct Foundation.URL

internal struct NetworkResponseDecoding<SessionVariable, RequestVariable, Response> {

  internal var decode: (SessionVariable, RequestVariable, HTTPRequest, HTTPResponse) -> Result<Response, Error>
}

extension NetworkResponseDecoding where Response == Void {

  internal static func statusCodes(
    _ statusCodes: Range<HTTPStatusCode>,
    using decoder: JSONDecoder = .init()
  ) -> Self {
    Self { _, _, httpRequest, httpResponse in
      decodeStatusCode(
        matching: statusCodes,
        httpRequest: httpRequest,
        httpResponse: httpResponse,
        using: decoder
      )
    }
  }
}

extension NetworkResponseDecoding where Response == Data {

  internal static var rawBody: Self {
    Self { _, _, _, response in
      .success(response.body)
    }
  }
}

extension NetworkResponseDecoding where Response == String {

  internal static func bodyAsString(
    withEncoding encoding: String.Encoding = .utf8
  ) -> Self {
    Self { _, _, _, response in
      if let string: String = String(data: response.body, encoding: encoding) {
        return .success(string)
      }
      else {
        return .failure(
          NetworkResponseDecodingFailure
            .error(
              "Failed to decode string body",
              response: response
            )
        )
      }
    }
  }
}

extension NetworkResponseDecoding {

  internal static func decodeForbidden(
    httpRequest: HTTPRequest,
    httpResponse: HTTPResponse,
    using decoder: JSONDecoder = .init()
  ) -> Result<Void, Error> {
    do {
      let mfaResponse: MFARequiredResponse =
        try decoder
        .decode(
          MFARequiredResponse.self,
          from: httpResponse.body
        )

      return .failure(
        SessionMFAAuthorizationRequired
          .error(mfaProviders: mfaResponse.body.mfaProviders)
      )
    }
    catch {
      return .failure(
        HTTPForbidden
          .error(
            request: httpRequest,
            response: httpResponse
          )
      )
    }
  }

  internal static func decodeBadRequest(
    httpRequest: HTTPRequest,
    httpResponse: HTTPResponse
  ) -> Result<Void, Error> {
    do {
      guard
        let validationViolations: Dictionary<String, Any> = try JSONSerialization.jsonObject(
          with: httpResponse.body,
          options: .init()
        ) as? Dictionary<String, Any>
      else {
        return .failure(
          HTTPRequestInvalid
            .error(
              request: httpRequest,
              response: httpResponse
            )
        )
      }

      return .failure(
        NetworkRequestValidationFailure
          .error(validationViolations: validationViolations)
      )
    }
    catch let error {
      return .failure(
        NetworkResponseDecodingFailure
          .error(
            "Failed to decode bad request response",
            response: httpResponse,
            underlyingError: error
          )
      )
    }
  }

  internal static func decodeRedirect(
    httpRequest: HTTPRequest,
    httpResponse: HTTPResponse
  ) -> Result<Void, Error> {
    if let locationString: String = httpResponse.headers["Location"],
      let locationURL: URL = .init(string: locationString)
    {
      return .failure(
        HTTPRedirect
          .error(
            request: httpRequest,
            response: httpResponse,
            location: locationURL
          )
      )
    }
    else {
      return .failure(
        NetworkResponseInvalid
          .error(
            "Redirect response does not contain valid location URL",
            response: httpResponse
          )
      )
    }
  }

  internal static func decodeStatusCode(
    matching statusCodes: Range<HTTPStatusCode>,
    httpRequest: HTTPRequest,
    httpResponse: HTTPResponse,
    using decoder: JSONDecoder = .init()
  ) -> Result<Void, Error> {
    if statusCodes ~= httpResponse.statusCode {
      return .success(Void())
    }
    else if httpResponse.statusCode == 302 {
      return decodeRedirect(
        httpRequest: httpRequest,
        httpResponse: httpResponse
      )
    }
    else if httpResponse.statusCode == 400 {
      return decodeBadRequest(
        httpRequest: httpRequest,
        httpResponse: httpResponse
      )
    }
    else if httpResponse.statusCode == 401 {
      return .failure(
        HTTPUnauthorized
          .error(
            request: httpRequest,
            response: httpResponse
          )
      )
    }
    else if httpResponse.statusCode == 403 {
      return decodeForbidden(
        httpRequest: httpRequest,
        httpResponse: httpResponse,
        using: decoder
      )
    }
    else if httpResponse.statusCode == 404 {
      return .failure(
        HTTPNotFound
          .error(
            request: httpRequest,
            response: httpResponse
          )
      )
    }
    else {
      return .failure(
        HTTPStatusCodeUnexpected
          .error(
            "HTTP status code is not matching expected",
            request: httpRequest,
            response: httpResponse
          )
      )
    }
  }
}

extension NetworkResponseDecoding where Response: Decodable {

  internal static func bodyAsJSON(
    using decoder: JSONDecoder = .init()
  ) -> Self {
    Self { _, _, httpRequest, httpResponse in
      decodeStatusCode(
        matching: 200..<300,
        httpRequest: httpRequest,
        httpResponse: httpResponse,
        using: decoder
      )
      .flatMap {
        do {
          return .success(
            try decoder.decode(
              Response.self,
              from: httpResponse.body
            )
          )
        }
        catch let error {
          return .failure(
            NetworkResponseDecodingFailure
              .error(
                "Failed to decode bad request response",
                response: httpResponse,
                underlyingError: error
              )
          )
        }
      }
    }
  }
}
