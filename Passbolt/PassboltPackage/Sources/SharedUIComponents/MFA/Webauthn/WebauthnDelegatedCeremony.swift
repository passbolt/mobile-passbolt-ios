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

import AuthenticationServices
import CommonModels
import Commons
import Localization

import class Foundation.Bundle
import struct Foundation.URL
import struct Foundation.URLComponents
import struct Foundation.URLQueryItem

/// Runs the server rendered passkey ceremony and waits for its callback.
@MainActor
internal final class WebauthnDelegatedCeremony {

  /// The window is owned by the scene, it is never owned by the ceremony.
  private weak var anchor: ASPresentationAnchor?
  private var contextProvider: WebauthnCeremonyContextProvider?
  private var session: ASWebAuthenticationSession?

  /// The anchor is reported by the view hierarchy - it has to be the window
  /// actually presenting the MFA screen.
  internal func updatePresentationAnchor(
    _ anchor: ASPresentationAnchor?
  ) {
    self.anchor = anchor
  }

  /// Present the ceremony page for the given instance and wait for its callback.
  /// - Parameters:
  ///   - domain: Address of the instance the account belongs to.
  ///   - state: Delegated state issued by the prompt of the instance.
  /// - Returns: Single use delegated token issued after a successful assertion.
  /// - Throws: `Cancelled` if the user closed the ceremony page or cancelled the ceremony on it,
  ///   `WebauthnAuthorizationFailure` if the ceremony could not be presented or its callback
  ///   carries no delegated token, or the error of the authentication session.
  internal func authorize(
    domain: URLString,
    state: String
  ) async throws -> String {
    guard let anchor: ASPresentationAnchor = self.anchor
    else {
      throw
        WebauthnAuthorizationFailure
        .error("Missing passkey ceremony presentation anchor")
    }

    let url: URL = try WebauthnCeremony.url(
      domain: domain,
      state: state,
      language: WebauthnCeremony.applicationLanguage
    )

    let contextProvider: WebauthnCeremonyContextProvider = .init(anchor: anchor)
    self.contextProvider = contextProvider
    defer {
      self.session?.cancel()
      self.session = .none
      self.contextProvider = .none
    }
    let callbackURL: URL = try await future {
      [weak self] (fulfill: @escaping @Sendable (Result<URL, Error>) -> Void) in
      guard let self: WebauthnDelegatedCeremony = self
      else { return fulfill(.failure(Cancelled.error())) }

      let session: ASWebAuthenticationSession = .init(
        url: url,
        callbackURLScheme: WebauthnCeremony.callbackURLScheme,
        completionHandler: { @Sendable(callbackURL: URL?, error: Error?) in
          if let callbackURL: URL {
            fulfill(.success(callbackURL))
          }
          else if let error: Error {
            fulfill(.failure(WebauthnCeremony.mappedError(error)))
          }
          else {
            fulfill(.failure(Cancelled.error()))
          }
        }
      )
      // `presentationContextProvider` is held weakly by the session,
      // it is kept alive by the ceremony until the callback arrives
      session.presentationContextProvider = contextProvider
      self.session = session
      guard session.start()
      else {
        return fulfill(
          .failure(
            WebauthnAuthorizationFailure
              .error("Failed to start the passkey ceremony session")
          )
        )
      }
    }

    return try WebauthnCeremony.delegatedToken(from: callbackURL)
  }
}

/// The anchor is captured upfront, for the time of a single ceremony,
/// so the presentation can't fall back to a window which is not on screen.
private final class WebauthnCeremonyContextProvider: NSObject, ASWebAuthenticationPresentationContextProviding {

  // Only the reference is handed back to the session, the window itself is never accessed here.
  private let anchor: UncheckedSendableBox<ASPresentationAnchor>

  fileprivate init(
    anchor: ASPresentationAnchor
  ) {
    self.anchor = .init(anchor)
    super.init()
  }

  fileprivate nonisolated func presentationAnchor(
    for session: ASWebAuthenticationSession
  ) -> ASPresentationAnchor {
    self.anchor.value
  }
}

// MARK: - Server contract

internal enum WebauthnCeremony {

  /// Matches `WebauthnDelegatedGetController::REDIRECT_URI` (`passbolt://mfa/webauthn/callback`) on the server side.
  /// The callback carries no instance address, so none is compiled into the app.
  internal static let callbackURLScheme: String = "passbolt"
  private static let callbackURLHost: String = "mfa"
  private static let callbackURLPath: String = "/webauthn/callback"

  private static let ceremonyPath: String = "/mfa/verify/webauthn/delegated"
  private static let stateQueryItemName: String = "mfa_delegated_state"
  private static let localeQueryItemName: String = "locale"
  private static let delegatedTokenQueryItemName: String = "mfa_delegated_token"
  private static let errorQueryItemName: String = "error"
  private static let cancelledErrorValue: String = "cancelled"
  private static let browserUnsupportedErrorValue: String = "browser_unsupported"
  private static let unknownErrorValue: String = "unknown"

  /// Locales of `passbolt.plugins.locale.options` on the server side,
  /// keyed by the language of the application localization.
  private static let serverLocales: Dictionary<String, String> = [
    "cs": "cs-CZ",
    "de": "de-DE",
    "en": "en-UK",
    "es": "es-ES",
    "fr": "fr-FR",
    "it": "it-IT",
    "ja": "ja-JP",
    "ko": "ko-KR",
    "lt": "lt-LT",
    "nl": "nl-NL",
    "pl": "pl-PL",
    "pt": "pt-BR",
    "ro": "ro-RO",
    "ru": "ru-RU",
    "sl": "sl-SI",
    "sv": "sv-SE",
    "uk": "uk-UA",
  ]

  /// Language the application strings are displayed in,
  /// so the ceremony page matches the rest of the application.
  internal static var applicationLanguage: String? {
    Bundle.localization.preferredLocalizations.first
  }

  /// The instance address always comes from the account, it is never
  /// part of the application configuration.
  /// Parameters:
  ///  - language: Language of the application localization. The ceremony page
  ///   is requested in the matching server locale, without one the server falls back
  ///   to the locale of the user or the organization.
  /// - Returns: Address of the ceremony page for the given instance and state.
  /// - Throws: `WebauthnAuthorizationFailure` if the domain or the resulting address is invalid.
  internal static func url(
    domain: URLString,
    state: String,
    language: String?
  ) throws -> URL {
    guard var components: URLComponents = .init(string: domain.rawValue)
    else {
      throw
        WebauthnAuthorizationFailure
        .error("Invalid account domain")
    }

    // the domain can carry a trailing slash or a subfolder path
    let basePath: String =
      components.path.hasSuffix("/")
      ? String(components.path.dropLast())
      : components.path
    components.path = basePath.appending(ceremonyPath)
    var queryItems: Array<URLQueryItem> = [
      .init(
        name: stateQueryItemName,
        value: state
      )
    ]
    if let locale: String = serverLocale(for: language) {
      queryItems.append(
        .init(
          name: localeQueryItemName,
          value: locale
        )
      )
    }  // else NOP
    components.queryItems = queryItems

    guard let url: URL = components.url
    else {
      throw
        WebauthnAuthorizationFailure
        .error("Failed to prepare the passkey ceremony url")
    }

    return url
  }

  // localizations can be named with a region (`pt-BR`, `en_GB`),
  // only the language selects the server locale
  private static func serverLocale(
    for language: String?
  ) -> String? {
    guard
      let languageCode: Substring = language?
        .split(whereSeparator: { $0 == "-" || $0 == "_" })
        .first
    else { return .none }

    return serverLocales[languageCode.lowercased()]
  }

  /// - Returns: `Cancelled` if the user closed the ceremony page, the given error otherwise.
  internal static func mappedError(
    _ error: Error
  ) -> Error {
    if let error: ASWebAuthenticationSessionError = error as? ASWebAuthenticationSessionError,
      error.code == .canceledLogin
    {
      return Cancelled.error()
    }
    else {
      return error
    }
  }

  /// Reads the result of the ceremony from its callback.
  /// - Returns: Delegated token if the callback carries a token and no error.
  /// - Throws: `Cancelled` if the user cancelled the ceremony (`cancelled`),
  ///   `WebauthnAuthorizationFailure.browserUnsupported()` if the system can't perform the ceremony
  ///   (`browser_unsupported`), `WebauthnAuthorizationFailure.verificationFailed()` if the passkey
  ///   verification failed (`unknown`), `WebauthnAuthorizationFailure` for an unexpected callback address,
  ///   a missing or empty token, a token reported together with an error, or any other error.
  internal static func delegatedToken(
    from callbackURL: URL
  ) throws -> String {
    guard
      let components: URLComponents = .init(
        url: callbackURL,
        resolvingAgainstBaseURL: false
      ),
      components.scheme == callbackURLScheme,
      components.host == callbackURLHost,
      components.path == callbackURLPath
    else {
      throw
        WebauthnAuthorizationFailure
        .error("Unexpected passkey ceremony callback url")
    }

    let queryItems: Array<URLQueryItem> = components.queryItems ?? .init()
    let delegatedToken: String? =
      queryItems
      .first(where: { $0.name == delegatedTokenQueryItemName })?
      .value
    let error: String? =
      queryItems
      .first(where: { $0.name == errorQueryItemName })?
      .value

    if let delegatedToken: String, !delegatedToken.isEmpty, error == .none {
      return delegatedToken
    }
    else if delegatedToken == .none, error == cancelledErrorValue {
      throw Cancelled.error()
    }
    else if delegatedToken == .none, error == browserUnsupportedErrorValue {
      throw
        WebauthnAuthorizationFailure
        .browserUnsupported()
    }
    else if delegatedToken == .none, error == unknownErrorValue {
      throw
        WebauthnAuthorizationFailure
        .verificationFailed()
    }
    else {
      throw
        WebauthnAuthorizationFailure
        .error("The passkey ceremony did not provide a delegated token")
    }
  }
}
