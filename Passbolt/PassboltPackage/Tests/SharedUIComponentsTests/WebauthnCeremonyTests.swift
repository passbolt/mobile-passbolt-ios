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
import TestExtensions

import struct Foundation.URL

@testable import SharedUIComponents

// swift-format-ignore: AlwaysUseLowerCamelCase
final class WebauthnCeremonyTests: TestCase {

  // MARK: - ceremony url

  func test_url_usesCeremonyPath_withPlainDomain() throws {
    let url: URL = try WebauthnCeremony.url(
      domain: "https://passbolt.example.com",
      ceremonyToken: "ceremony-token"
    )

    XCTAssertEqual(
      url.absoluteString,
      "https://passbolt.example.com/mfa/verify/webauthn/delegated?ceremony_token=ceremony-token"
    )
  }

  func test_url_dropsTrailingSlash_withDomainEndingWithSlash() throws {
    let url: URL = try WebauthnCeremony.url(
      domain: "https://passbolt.example.com/",
      ceremonyToken: "ceremony-token"
    )

    XCTAssertEqual(
      url.absoluteString,
      "https://passbolt.example.com/mfa/verify/webauthn/delegated?ceremony_token=ceremony-token"
    )
  }

  func test_url_keepsSubfolder_withDomainUsingSubfolder() throws {
    let url: URL = try WebauthnCeremony.url(
      domain: "https://example.com/passbolt/",
      ceremonyToken: "ceremony-token"
    )

    XCTAssertEqual(
      url.absoluteString,
      "https://example.com/passbolt/mfa/verify/webauthn/delegated?ceremony_token=ceremony-token"
    )
  }

  // MARK: - callback parsing

  func test_exchangeCode_providesCode_withCodeInCallback() throws {
    let callbackURL: URL = try XCTUnwrap(
      URL(string: "passbolt://mfa/webauthn?exchange_code=exchange-code")
    )

    let exchangeCode: String = try WebauthnCeremony.exchangeCode(from: callbackURL)

    XCTAssertEqual(exchangeCode, "exchange-code")
  }

  func test_exchangeCode_throwsCancelled_withUserCancelledInCallback() throws {
    let callbackURL: URL = try XCTUnwrap(
      URL(string: "passbolt://mfa/webauthn?error=user_cancelled")
    )

    XCTAssertThrowsError(
      try WebauthnCeremony.exchangeCode(from: callbackURL)
    ) { (error: Error) in
      XCTAssertTrue(error is Cancelled)
    }
  }

  func test_exchangeCode_throwsFailure_withEmptyCodeInCallback() throws {
    let callbackURL: URL = try XCTUnwrap(
      URL(string: "passbolt://mfa/webauthn?exchange_code=")
    )

    XCTAssertThrowsError(
      try WebauthnCeremony.exchangeCode(from: callbackURL)
    ) { (error: Error) in
      XCTAssertTrue(error is WebauthnAuthorizationFailure)
    }
  }

  func test_exchangeCode_throwsFailure_withoutQueryInCallback() throws {
    let callbackURL: URL = try XCTUnwrap(
      URL(string: "passbolt://mfa/webauthn")
    )

    XCTAssertThrowsError(
      try WebauthnCeremony.exchangeCode(from: callbackURL)
    ) { (error: Error) in
      XCTAssertTrue(error is WebauthnAuthorizationFailure)
    }
  }

  func test_exchangeCode_throwsFailure_withCodeAndErrorInCallback() throws {
    let callbackURL: URL = try XCTUnwrap(
      URL(string: "passbolt://mfa/webauthn?exchange_code=exchange-code&error=user_cancelled")
    )

    XCTAssertThrowsError(
      try WebauthnCeremony.exchangeCode(from: callbackURL)
    ) { (error: Error) in
      XCTAssertTrue(error is WebauthnAuthorizationFailure)
    }
  }

  func test_exchangeCode_throwsFailure_withOtherSchemeInCallback() throws {
    let callbackURL: URL = try XCTUnwrap(
      URL(string: "https://passbolt.example.com/mfa/webauthn?exchange_code=exchange-code")
    )

    XCTAssertThrowsError(
      try WebauthnCeremony.exchangeCode(from: callbackURL)
    ) { (error: Error) in
      XCTAssertTrue(error is WebauthnAuthorizationFailure)
    }
  }
}
