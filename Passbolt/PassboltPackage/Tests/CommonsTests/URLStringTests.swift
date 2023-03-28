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
import Foundation
import TestExtensions
import XCTest

// swift-format-ignore: AlwaysUseLowerCamelCase, NeverUseImplicitlyUnwrappedOptionals
final class URLStringTests: XCTestCase {

  func test_serverURLString_hasCorrectValue_whenProvided_withValidURL() {
    XCTAssertEqual(
      URL(
        string: "https://passbolt.com:443"
      )!
      .serverURLString,
      "https://passbolt.com:443"
    )
  }

  func test_serverURLString_hasCorrectValue_whenProvided_withValidURL_containingAllUnnecessaryComponents() {
    XCTAssertEqual(
      URL(
        string: "https://user@passbolt.com:443/path?query=1#fragment"
      )!
      .serverURLString,
      "https://passbolt.com:443"
    )
  }

  func test_serverURLString_doesNotContainUser_whenProvided_withValidURL_containingUser() {
    XCTAssertEqual(
      URL(
        string: "https://user@passbolt.com:443"
      )!
      .serverURLString,
      "https://passbolt.com:443"
    )
  }

  func test_serverURLString_doesNotContainPath_whenProvided_withValidURL_containingPath() {
    XCTAssertEqual(
      URL(
        string: "https://passbolt.com:443/path"
      )!
      .serverURLString,
      "https://passbolt.com:443"
    )
  }

  func test_serverURLString_doesNotContainQuery_whenProvided_withValidURL_containingQuery() {
    XCTAssertEqual(
      URL(
        string: "https://passbolt.com:443?query=1"
      )!
      .serverURLString,
      "https://passbolt.com:443"
    )
  }

  func test_serverURLString_doesNotContainFragment_whenProvided_withValidURL_containingQuery() {
    XCTAssertEqual(
      URL(
        string: "https://passbolt.com:443#fragment"
      )!
      .serverURLString,
      "https://passbolt.com:443"
    )
  }
}
