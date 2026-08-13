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

import Resources
import TestExtensions

@testable import Display
@testable import PassboltApp

/// The alert only asks the question - removing the TOTP is performed by the screen that opened it, because that
/// removal may open the permission confirmation and an alert cannot own the flow behind it.
// swift-format-ignore: AlwaysUseLowerCamelCase
final class ResourceOTPDeleteAlertControllerTests: FeaturesTestCase {

  func test_deleteAction_performsTheConfirmedRemoval() async throws {
    let removalPerformed: XCTestExpectation =
      self.expectation(description: "Confirmed removal should be performed")

    let tested: ResourceOTPDeleteAlertController = try self.testedInstance(
      context: .init(
        onConfirmed: {
          removalPerformed.fulfill()
        }
      )
    )

    guard let testedAction: AlertAction = tested.actions.last
    else { return XCTFail("Missing action") }

    testedAction.action()

    await fulfillment(of: [removalPerformed], timeout: 1.0)
  }

  func test_cancelAction_performsNothing() async throws {
    let tested: ResourceOTPDeleteAlertController = try self.testedInstance(
      context: .init(
        onConfirmed: {
          XCTFail("Cancelling must leave the resource untouched")
        }
      )
    )

    guard let testedAction: AlertAction = tested.actions.first
    else { return XCTFail("Missing action") }

    testedAction.action()
  }
}
