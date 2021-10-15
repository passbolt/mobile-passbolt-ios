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
import TestExtensions
import UIComponents
import XCTest

@testable import SharedUIComponents

// swift-format-ignore: AlwaysUseLowerCamelCase, NeverUseImplicitlyUnwrappedOptionals
final class ServerNotReachableControllerTests: TestCase {

  func test_serverURL_hasCorrectValue_whenProvided_withValidURL() {
    let controller: ServerNotReachableController = testInstance(
      context: .init(string: "https://passbolt.com:443")
    )

    XCTAssertEqual(controller.serverURL, "https://passbolt.com:443")
  }

  func test_serverURL_hasCorrectValue_whenProvided_withValidURL_containingAllUnnecessaryComponents() {
    let controller: ServerNotReachableController = testInstance(
      context: .init(string: "https://user@passbolt.com:443/path?query=1#fragment")
    )

    XCTAssertEqual(controller.serverURL, "https://passbolt.com:443")
  }

  func test_serverURL_doesNotContainUser_whenProvided_withValidURL_containingUser() {
    let controller: ServerNotReachableController = testInstance(
      context: .init(string: "https://user@passbolt.com:443")
    )

    XCTAssertEqual(controller.serverURL, "https://passbolt.com:443")
  }

  func test_serverURL_doesNotContainPath_whenProvided_withValidURL_containingPath() {
    let controller: ServerNotReachableController = testInstance(
      context: .init(string: "https://passbolt.com:443/path")
    )

    XCTAssertEqual(controller.serverURL, "https://passbolt.com:443")
  }

  func test_serverURL_doesNotContainQuery_whenProvided_withValidURL_containingQuery() {
    let controller: ServerNotReachableController = testInstance(
      context: .init(string: "https://passbolt.com:443?query=1")
    )

    XCTAssertEqual(controller.serverURL, "https://passbolt.com:443")
  }

  func test_serverURL_doesNotContainFragment_whenProvided_withValidURL_containingQuery() {
    let controller: ServerNotReachableController = testInstance(
      context: .init(string: "https://passbolt.com:443#fragment")
    )

    XCTAssertEqual(controller.serverURL, "https://passbolt.com:443")
  }

  func test_serverURL_isEmpty_whenProvided_withInvalidURL() {
    let controller: ServerNotReachableController = testInstance(
      context: .init(string: ":)//passboltcom/?fragment")
    )

    XCTAssertTrue(controller.serverURL?.rawValue.isEmpty ?? false)
  }
}
