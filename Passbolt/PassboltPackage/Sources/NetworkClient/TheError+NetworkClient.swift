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

import struct Foundation.URL

extension TheError {

  internal static func httpError(
    _ error: HTTPError
  ) -> Self {
    Self(
      identifier: .httpError,
      underlyingError: error,
      extensions: [.context: "networking"]
    )
  }

  internal static func networkResponseDecodingFailed(
    underlyingError: Error?,
    rawNetworkResponse: HTTPResponse
  ) -> Self {
    Self(
      identifier: .networkResponseDecodingFailed,
      underlyingError: underlyingError,
      extensions: [
        .context: "networking-decoding",
        .rawNetworkResponse: rawNetworkResponse,
      ]
    )
  }

  internal static func missingSession(
    underlyingError: Error? = nil
  ) -> Self {
    Self(
      identifier: .missingSession,
      underlyingError: underlyingError,
      extensions: [:]
    )
  }

  internal static func notFound(
    underlyingError: Error? = nil
  ) -> Self {
    Self(
      identifier: .notFound,
      underlyingError: underlyingError,
      extensions: [:]
    )
  }

  internal static func mfaRequired(
    underlyingError: Error? = nil,
    mfaProviders: Array<MFAProvider>
  ) -> Self {
    Self(
      identifier: .mfaRequired,
      underlyingError: underlyingError,
      extensions: [.mfaProviders: mfaProviders]
    )
  }

  internal static func forbidden(
    underlyingError: Error? = nil
  ) -> Self {
    Self(
      identifier: .forbidden,
      underlyingError: underlyingError,
      extensions: [:]
    )
  }

  public static func redirect(
    underlyingError: Error? = nil,
    location: String
  ) -> Self {
    Self(
      identifier: .redirect,
      underlyingError: underlyingError,
      extensions: [.redirectLocation: location]
    )
  }

  #warning("TODO: resolve conflict with TheError+Validated")
  public static func validationError(
    underlyingError: Error? = nil,
    validationViolations: Dictionary<String, Any>
  ) -> Self {
    Self(
      identifier: .validationError,
      underlyingError: underlyingError,
      extensions: [.validationViolations: validationViolations]
    )
  }

  public static func serverNotReachable(
    url: URL?,
    underlyingError: Error? = nil
  ) -> Self {
    Self(
      identifier: .serverNotReachable,
      underlyingError: underlyingError,
      extensions: [.url: url as Any]
    )
  }
}

extension TheError.ID {

  public static var httpError: Self { "httpError" }
  public static var networkResponseDecodingFailed: Self { "networkResponseDecodingFailed" }
  public static var missingSession: Self { "missingSession" }
  public static var notFound: Self { "notFound" }
  public static var forbidden: Self { "forbidden" }
  public static var mfaRequired: Self { "mfaRequired" }
  public static var redirect: Self { "redirect" }
  public static var validationError: Self { "validationError" }
  public static var serverNotReachable: Self { "serverNotReachable" }
}

extension TheError.Extension {

  public static var rawNetworkResponse: Self { "rawNetworkResponse" }
}

extension TheError.Extension {

  public static var mfaProviders: Self { "mfaProviders" }
  public static var redirectLocation: Self { "location" }
  public static var validationViolations: Self { "validationViolations" }
  public static var url: Self { "url" }
}

extension TheError {

  public var rawNetworkResponse: HTTPResponse? { extensions[.rawNetworkResponse] as? HTTPResponse }
  public var validationViolations: Dictionary<String, Any>? {
    extensions[.validationViolations] as? Dictionary<String, Any>
  }
}

extension TheError {

  public var mfaProviders: Array<MFAProvider> { extensions[.mfaProviders] as? Array<MFAProvider> ?? [] }
  public var redirectLocation: String? { extensions[.redirectLocation] as? String }
  public var url: URL? { extensions[.url] as? URL }
}
