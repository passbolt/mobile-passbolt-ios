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
  /// - Returns: Single use exchange code issued after a successful assertion.
  internal func authorize(
    domain: URLString,
    ceremonyToken: String
  ) async throws -> String {
    guard let anchor: ASPresentationAnchor = self.anchor
    else {
      throw
        WebauthnAuthorizationFailure
        .error("Missing passkey ceremony presentation anchor")
    }

    let url: URL = try WebauthnCeremony.url(
      domain: domain,
      ceremonyToken: ceremonyToken
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

    return try WebauthnCeremony.exchangeCode(from: callbackURL)
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

  /// Matches `WebauthnDelegatedGetController::REDIRECT_SCHEME_URI` on the server side.
  /// The scheme carries no host, so no instance address is compiled into the app.
  internal static let callbackURLScheme: String = "passbolt"

  private static let ceremonyPath: String = "/mfa/verify/webauthn/delegated"
  private static let ceremonyTokenQueryItemName: String = "ceremony_token"
  private static let exchangeCodeQueryItemName: String = "exchange_code"
  private static let errorQueryItemName: String = "error"
  private static let userCancelledErrorValue: String = "user_cancelled"

  /// The instance address always comes from the account, it is never
  /// part of the application configuration.
  internal static func url(
    domain: URLString,
    ceremonyToken: String
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
    components.queryItems = [
      .init(
        name: ceremonyTokenQueryItemName,
        value: ceremonyToken
      )
    ]

    guard let url: URL = components.url
    else {
      throw
        WebauthnAuthorizationFailure
        .error("Failed to prepare the passkey ceremony url")
    }

    return url
  }

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

  internal static func exchangeCode(
    from callbackURL: URL
  ) throws -> String {
    guard
      let components: URLComponents = .init(
        url: callbackURL,
        resolvingAgainstBaseURL: false
      ),
      components.scheme == callbackURLScheme
    else {
      throw
        WebauthnAuthorizationFailure
        .error("Unexpected passkey ceremony callback url")
    }

    let queryItems: Array<URLQueryItem> = components.queryItems ?? .init()
    let exchangeCode: String? =
      queryItems
      .first(where: { $0.name == exchangeCodeQueryItemName })?
      .value
    let error: String? =
      queryItems
      .first(where: { $0.name == errorQueryItemName })?
      .value

    // a callback carrying both an exchange code and an error is ambiguous - reject.
    if let exchangeCode: String, !exchangeCode.isEmpty, error == .none {
      return exchangeCode
    }
    else if exchangeCode == .none, error == userCancelledErrorValue {
      throw Cancelled.error()
    }
    else {
      throw
        WebauthnAuthorizationFailure
        .error("The passkey ceremony did not provide an exchange code")
    }
  }
}
