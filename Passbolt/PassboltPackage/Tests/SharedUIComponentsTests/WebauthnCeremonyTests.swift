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
import Localization
import TestExtensions

import class Foundation.Bundle
import struct Foundation.URL

@testable import SharedUIComponents

// swift-format-ignore: AlwaysUseLowerCamelCase
final class WebauthnCeremonyTests: TestCase {

  // MARK: - ceremony url

  func test_url_usesCeremonyPath_withPlainDomain() throws {
    let url: URL = try WebauthnCeremony.url(
      domain: "https://passbolt.example.com",
      state: "delegated-state",
      language: .none
    )

    XCTAssertEqual(
      url.absoluteString,
      "https://passbolt.example.com/mfa/verify/webauthn/delegated?mfa_delegated_state=delegated-state"
    )
  }

  func test_url_dropsTrailingSlash_withDomainEndingWithSlash() throws {
    let url: URL = try WebauthnCeremony.url(
      domain: "https://passbolt.example.com/",
      state: "delegated-state",
      language: .none
    )

    XCTAssertEqual(
      url.absoluteString,
      "https://passbolt.example.com/mfa/verify/webauthn/delegated?mfa_delegated_state=delegated-state"
    )
  }

  func test_url_keepsSubfolder_withDomainUsingSubfolder() throws {
    let url: URL = try WebauthnCeremony.url(
      domain: "https://example.com/passbolt/",
      state: "delegated-state",
      language: .none
    )

    XCTAssertEqual(
      url.absoluteString,
      "https://example.com/passbolt/mfa/verify/webauthn/delegated?mfa_delegated_state=delegated-state"
    )
  }

  func test_url_addsServerLocale_withApplicationLanguage() throws {
    let url: URL = try WebauthnCeremony.url(
      domain: "https://passbolt.example.com",
      state: "delegated-state",
      language: "pl"
    )

    XCTAssertEqual(
      url.absoluteString,
      "https://passbolt.example.com/mfa/verify/webauthn/delegated?mfa_delegated_state=delegated-state&locale=pl-PL"
    )
  }

  func test_url_addsServerLocale_withLanguageWithoutMatchingServerRegion() throws {
    // the server names the english locale `en-UK`, the portuguese one `pt-BR`
    let englishURL: URL = try WebauthnCeremony.url(
      domain: "https://passbolt.example.com",
      state: "delegated-state",
      language: "en"
    )
    let portugueseURL: URL = try WebauthnCeremony.url(
      domain: "https://passbolt.example.com",
      state: "delegated-state",
      language: "pt"
    )

    XCTAssertEqual(
      englishURL.absoluteString,
      "https://passbolt.example.com/mfa/verify/webauthn/delegated?mfa_delegated_state=delegated-state&locale=en-UK"
    )
    XCTAssertEqual(
      portugueseURL.absoluteString,
      "https://passbolt.example.com/mfa/verify/webauthn/delegated?mfa_delegated_state=delegated-state&locale=pt-BR"
    )
  }

  func test_url_addsServerLocale_withLanguageNamedWithRegion() throws {
    let url: URL = try WebauthnCeremony.url(
      domain: "https://passbolt.example.com",
      state: "delegated-state",
      language: "de_AT"
    )

    XCTAssertEqual(
      url.absoluteString,
      "https://passbolt.example.com/mfa/verify/webauthn/delegated?mfa_delegated_state=delegated-state&locale=de-DE"
    )
  }

  func test_url_omitsLocale_withUnsupportedLanguage() throws {
    let url: URL = try WebauthnCeremony.url(
      domain: "https://passbolt.example.com",
      state: "delegated-state",
      language: "zh-Hans"
    )

    XCTAssertEqual(
      url.absoluteString,
      "https://passbolt.example.com/mfa/verify/webauthn/delegated?mfa_delegated_state=delegated-state"
    )
  }

  func test_url_addsServerLocale_forEveryApplicationLocalization() throws {
    // a localization added to the application has to be mapped to its server locale
    let localizations: Array<String> = Bundle.localization.localizations.filter { $0 != "Base" }
    XCTAssertFalse(localizations.isEmpty)

    for localization: String in localizations {
      let url: URL = try WebauthnCeremony.url(
        domain: "https://passbolt.example.com",
        state: "delegated-state",
        language: localization
      )

      XCTAssertTrue(
        url.absoluteString.contains("&locale="),
        "Missing server locale for \(localization)"
      )
    }
  }

  // MARK: - callback parsing

  func test_delegatedToken_providesToken_withTokenInCallback() throws {
    let callbackURL: URL = try XCTUnwrap(
      URL(string: "passbolt://mfa/webauthn/callback?mfa_delegated_token=delegated-token")
    )

    let delegatedToken: String = try WebauthnCeremony.delegatedToken(from: callbackURL)

    XCTAssertEqual(delegatedToken, "delegated-token")
  }

  func test_delegatedToken_throwsCancelled_withCancelledInCallback() throws {
    let callbackURL: URL = try XCTUnwrap(
      URL(string: "passbolt://mfa/webauthn/callback?error=cancelled")
    )

    XCTAssertThrowsError(
      try WebauthnCeremony.delegatedToken(from: callbackURL)
    ) { (error: Error) in
      XCTAssertTrue(error is Cancelled)
    }
  }

  func test_delegatedToken_throwsBrowserUnsupported_withBrowserUnsupportedInCallback() throws {
    let callbackURL: URL = try XCTUnwrap(
      URL(string: "passbolt://mfa/webauthn/callback?error=browser_unsupported")
    )

    XCTAssertThrowsError(
      try WebauthnCeremony.delegatedToken(from: callbackURL)
    ) { (error: Error) in
      XCTAssertEqual(
        (error as? WebauthnAuthorizationFailure)?.displayableMessage,
        WebauthnAuthorizationFailure.browserUnsupported().displayableMessage
      )
    }
  }

  func test_delegatedToken_throwsVerificationFailed_withUnknownInCallback() throws {
    let callbackURL: URL = try XCTUnwrap(
      URL(string: "passbolt://mfa/webauthn/callback?error=unknown")
    )

    XCTAssertThrowsError(
      try WebauthnCeremony.delegatedToken(from: callbackURL)
    ) { (error: Error) in
      XCTAssertEqual(
        (error as? WebauthnAuthorizationFailure)?.displayableMessage,
        WebauthnAuthorizationFailure.verificationFailed().displayableMessage
      )
    }
  }

  func test_delegatedToken_throwsFailure_withTokenAndBrowserUnsupportedInCallback() throws {
    let callbackURL: URL = try XCTUnwrap(
      URL(string: "passbolt://mfa/webauthn/callback?mfa_delegated_token=delegated-token&error=browser_unsupported")
    )

    XCTAssertThrowsError(
      try WebauthnCeremony.delegatedToken(from: callbackURL)
    ) { (error: Error) in
      XCTAssertTrue(error is WebauthnAuthorizationFailure)
    }
  }

  func test_delegatedToken_throwsFailure_withEmptyTokenInCallback() throws {
    let callbackURL: URL = try XCTUnwrap(
      URL(string: "passbolt://mfa/webauthn/callback?mfa_delegated_token=")
    )

    XCTAssertThrowsError(
      try WebauthnCeremony.delegatedToken(from: callbackURL)
    ) { (error: Error) in
      XCTAssertTrue(error is WebauthnAuthorizationFailure)
    }
  }

  func test_delegatedToken_throwsFailure_withoutQueryInCallback() throws {
    let callbackURL: URL = try XCTUnwrap(
      URL(string: "passbolt://mfa/webauthn/callback")
    )

    XCTAssertThrowsError(
      try WebauthnCeremony.delegatedToken(from: callbackURL)
    ) { (error: Error) in
      XCTAssertTrue(error is WebauthnAuthorizationFailure)
    }
  }

  func test_delegatedToken_throwsFailure_withTokenAndErrorInCallback() throws {
    let callbackURL: URL = try XCTUnwrap(
      URL(string: "passbolt://mfa/webauthn/callback?mfa_delegated_token=delegated-token&error=cancelled")
    )

    XCTAssertThrowsError(
      try WebauthnCeremony.delegatedToken(from: callbackURL)
    ) { (error: Error) in
      XCTAssertTrue(error is WebauthnAuthorizationFailure)
    }
  }

  func test_delegatedToken_throwsFailure_withOtherSchemeInCallback() throws {
    let callbackURL: URL = try XCTUnwrap(
      URL(string: "https://passbolt.example.com/mfa/webauthn/callback?mfa_delegated_token=delegated-token")
    )

    XCTAssertThrowsError(
      try WebauthnCeremony.delegatedToken(from: callbackURL)
    ) { (error: Error) in
      XCTAssertTrue(error is WebauthnAuthorizationFailure)
    }
  }

  func test_delegatedToken_throwsFailure_withStateInvalidInCallback() throws {
    let callbackURL: URL = try XCTUnwrap(
      URL(string: "passbolt://mfa/webauthn/callback?error=state_invalid")
    )

    XCTAssertThrowsError(
      try WebauthnCeremony.delegatedToken(from: callbackURL)
    ) { (error: Error) in
      XCTAssertTrue(error is WebauthnAuthorizationFailure)
    }
  }

  func test_delegatedToken_throwsFailure_withCeremonyErrorMessageInCallback() throws {
    let callbackURL: URL = try XCTUnwrap(
      URL(string: "passbolt://mfa/webauthn/callback?error=The%20delegated%20state%20is%20not%20valid.")
    )

    XCTAssertThrowsError(
      try WebauthnCeremony.delegatedToken(from: callbackURL)
    ) { (error: Error) in
      XCTAssertTrue(error is WebauthnAuthorizationFailure)
    }
  }

  func test_delegatedToken_throwsFailure_withOtherHostInCallback() throws {
    let callbackURL: URL = try XCTUnwrap(
      URL(string: "passbolt://other/webauthn/callback?mfa_delegated_token=delegated-token")
    )

    XCTAssertThrowsError(
      try WebauthnCeremony.delegatedToken(from: callbackURL)
    ) { (error: Error) in
      XCTAssertTrue(error is WebauthnAuthorizationFailure)
    }
  }

  func test_delegatedToken_throwsFailure_withOtherPathInCallback() throws {
    let callbackURL: URL = try XCTUnwrap(
      URL(string: "passbolt://mfa/webauthn?mfa_delegated_token=delegated-token")
    )

    XCTAssertThrowsError(
      try WebauthnCeremony.delegatedToken(from: callbackURL)
    ) { (error: Error) in
      XCTAssertTrue(error is WebauthnAuthorizationFailure)
    }
  }
}
