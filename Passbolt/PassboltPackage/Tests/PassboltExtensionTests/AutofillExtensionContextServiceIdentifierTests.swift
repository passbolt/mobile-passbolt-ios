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

import XCTest

@testable import PassboltExtension

// swift-format-ignore: AlwaysUseLowerCamelCase, NeverUseImplicitlyUnwrappedOptionals
final class AutofillExtensionContextServiceIdentifierTests: XCTestCase {

  typealias Identifier = AutofillExtensionContext.ServiceIdentifier

  func test_matches_returnsFalse_withEmptyDomains() async throws {
    XCTAssertFalse(("" as Identifier).matches(url: "passbolt.com"))
    XCTAssertFalse(("passbolt.com" as Identifier).matches(url: ""))
  }

  func test_matches_returnsTrue_withMatchingDomains() async throws {
    XCTAssertTrue(("http://www.passbolt.com" as Identifier).matches(url: "http://www.passbolt.com"))
    XCTAssertTrue(("https://www.passbolt.com" as Identifier).matches(url: "https://www.passbolt.com"))
    XCTAssertTrue(("https://www.passbolt.com:443" as Identifier).matches(url: "https://www.passbolt.com:443"))
    XCTAssertTrue(("https://email" as Identifier).matches(url: "https://email"))
    XCTAssertTrue(
      ("https://àáâãäåæçèéêëìíîïðñòóôõöøùúûüýþÿ.com" as Identifier)
        .matches(
          url: "https://àáâãäåæçèéêëìíîïðñòóôõöøùúûüýþÿ.com"
        )
    )
    XCTAssertTrue(("https://الش.com" as Identifier).matches(url: "https://الش.com"))
    XCTAssertTrue(("https://Ид.com" as Identifier).matches(url: "https://Ид.com"))
    XCTAssertTrue(("https://完善.com" as Identifier).matches(url: "https://完善.com"))
    XCTAssertTrue(("https://www.passbolt.com" as Identifier).matches(url: "www.passbolt.com"))
    XCTAssertTrue(("https://www.passbolt.com/path" as Identifier).matches(url: "www.passbolt.com/path"))
    XCTAssertTrue(("https://www.passbolt.com" as Identifier).matches(url: "www.passbolt.com/path"))
    XCTAssertTrue(("https://www.passbolt.com/path" as Identifier).matches(url: "www.passbolt.com"))
  }

  func test_matches_returnsTrue_withMatchingIPs() async throws {
    XCTAssertTrue(("http://[0:0:0:0:0:0:0:1]" as Identifier).matches(url: "http://[0:0:0:0:0:0:0:1]"))
    XCTAssertTrue(("http://127.0.0.1" as Identifier).matches(url: "http://127.0.0.1"))
    XCTAssertTrue(("https://127.0.0.1" as Identifier).matches(url: "https://127.0.0.1"))
    XCTAssertTrue(("https://[0:0:0:0:0:0:0:1]:443" as Identifier).matches(url: "https://[0:0:0:0:0:0:0:1]:443"))
    XCTAssertTrue(("https://127.0.0.1:443" as Identifier).matches(url: "https://127.0.0.1:443"))
    XCTAssertTrue(("http://127.0.0.1" as Identifier).matches(url: "127.0.0.1"))
    XCTAssertTrue(("http://127.0.0.1/path" as Identifier).matches(url: "127.0.0.1/path"))
    XCTAssertTrue(("[::1]" as Identifier).matches(url: "[::1]"))
    XCTAssertTrue(("http://[::1]" as Identifier).matches(url: "http://[::1]"))
    XCTAssertTrue(("127.1" as Identifier).matches(url: "127.1"))
    XCTAssertTrue(("http:127.1" as Identifier).matches(url: "http:127.1"))
  }

  func test_matches_returnsTrue_withMatchingWithoutPort() async throws {
    XCTAssertTrue(("http://passbolt.com:8080" as Identifier).matches(url: "passbolt.com"))
    XCTAssertTrue(("http://[0:0:0:0:0:0:0:1]:8080" as Identifier).matches(url: "[0:0:0:0:0:0:0:1]"))
    XCTAssertTrue(("http://127.0.0.1:8080" as Identifier).matches(url: "127.0.0.1"))
  }

  func test_matches_returnsTrue_withMatchingSubdomains() async throws {
    XCTAssertTrue(("https://www.passbolt.com" as Identifier).matches(url: "passbolt.com"))
    XCTAssertTrue(("https://www.passbolt.com" as Identifier).matches(url: "https://passbolt.com"))
    XCTAssertTrue(("https://www.passbolt.com/path" as Identifier).matches(url: "https://passbolt.com/path"))
    XCTAssertTrue(("https://billing.admin.passbolt.com" as Identifier).matches(url: "passbolt.com"))
  }

  func test_matches_returnsFalse_withNonMatchingDomains() async throws {
    XCTAssertFalse(("https://www.not-passbolt.com" as Identifier).matches(url: "passbolt.com"))
    XCTAssertFalse(("https://www.not-passbolt.com/path" as Identifier).matches(url: "passbolt.com/path"))
    XCTAssertFalse(("https://bolt.com" as Identifier).matches(url: "passbolt.com"))
    XCTAssertFalse(("https://pass" as Identifier).matches(url: "passbolt.com"))
    XCTAssertFalse(("https://attacker-passbolt.com" as Identifier).matches(url: "passbolt.com"))
    XCTAssertFalse(("https://titan.email" as Identifier).matches(url: "email"))
    XCTAssertFalse(("https://email" as Identifier).matches(url: "http://email"))
    XCTAssertFalse(("https://titan.email" as Identifier).matches(url: "https://email"))
  }

  func test_matches_returnsFalse_withNonMatchingSubdomains() async throws {
    XCTAssertFalse(("https://passbolt.com" as Identifier).matches(url: "www.passbolt.com"))
    XCTAssertFalse(("https://passbolt.com" as Identifier).matches(url: "https://www.passbolt.com"))
    XCTAssertFalse(("https://passbolt.com/path" as Identifier).matches(url: "https://www.passbolt.com/path"))
    XCTAssertFalse(("https://www.passbolt.com.attacker.com" as Identifier).matches(url: "passbolt.com"))
    XCTAssertFalse(("https://www.passbolt.com-attacker.com" as Identifier).matches(url: "passbolt.com"))
  }

  func test_matches_returnsFalse_withNonMatchingIPs() async throws {
    XCTAssertFalse(("https://fake.127.0.0.1" as Identifier).matches(url: "127.0.0.1"))
    XCTAssertFalse(("https://127.127.0.0.1" as Identifier).matches(url: "127.0.0.1"))
    XCTAssertFalse(("https://[0:0:0:0:0:0:0:0:1]" as Identifier).matches(url: "https://[0:0:0:0:0:0:0:1]"))
    XCTAssertFalse(("https://[2001:4860:4860::8844]" as Identifier).matches(url: "[2001:4860:4860::8888]"))
    XCTAssertFalse(("https://127.0.0.1" as Identifier).matches(url: "127.0.0.2"))
    XCTAssertFalse(("https://127.1" as Identifier).matches(url: "127.2"))
  }

  func test_matches_returnsFalse_withMatchingPathOrQueryOrHashOrPort() async throws {
    XCTAssertFalse(("https://attacker.com?passbolt.com" as Identifier).matches(url: "passbolt.com"))
    XCTAssertFalse(("https://attacker.com/passbolt.com" as Identifier).matches(url: "passbolt.com"))
    XCTAssertFalse(("https://attacker.com#passbolt.com" as Identifier).matches(url: "passbolt.com"))
    XCTAssertFalse(("https://attacker.com:passbolt.com" as Identifier).matches(url: "passbolt.com"))
    XCTAssertFalse(("https://attacker.com?url=https://passbolt.com" as Identifier).matches(url: "passbolt.com"))
    XCTAssertFalse(("https://attacker.com#url=https://passbolt.com" as Identifier).matches(url: "passbolt.com"))
    XCTAssertFalse(("https://attacker.com/url=https://passbolt.com" as Identifier).matches(url: "passbolt.com"))
  }

  func test_matches_returnsFalse_whithNonMatchingScheme() async throws {
    XCTAssertFalse(("http://127.0.0.1" as Identifier).matches(url: "https://127.0.0.1"))
    XCTAssertFalse(("https://127.0.0.1" as Identifier).matches(url: "http://127.0.0.1"))
    XCTAssertFalse(("http://[::1]" as Identifier).matches(url: "https://[::1]"))
    XCTAssertFalse(("https://[::1]" as Identifier).matches(url: "http://[::1]"))
    XCTAssertFalse(("http://www.passbolt.com" as Identifier).matches(url: "https://www.passbolt.com"))
    XCTAssertFalse(("https://www.passbolt.com" as Identifier).matches(url: "http://www.passbolt.com"))
    XCTAssertFalse(("http://www.passbolt.com/path" as Identifier).matches(url: "https://www.passbolt.com/path"))
  }

  func test_matches_returnsFalse_withNonMatchingPort() async throws {
    XCTAssertFalse(("http://127.0.0.1" as Identifier).matches(url: "127.0.0.1:444"))
    XCTAssertFalse(("http://www.passbolt.com" as Identifier).matches(url: "www.passbolt.com:444"))
    XCTAssertFalse(("https://www.passbolt.com" as Identifier).matches(url: "www.passbolt.com:80"))
    XCTAssertFalse(("https://www.passbolt.com/path" as Identifier).matches(url: "www.passbolt.com:80/path"))
    XCTAssertFalse(("https://127.0.0.1:444" as Identifier).matches(url: "127.0.0.1:443"))
    XCTAssertFalse(("https://www.passbolt.com:444" as Identifier).matches(url: "www.passbolt.com:443"))
    XCTAssertFalse(("http://127.0.0.1" as Identifier).matches(url: "127.0.0.1:80"))
    XCTAssertFalse(("https://www.passbolt.com" as Identifier).matches(url: "www.passbolt.com:443"))
  }
}
