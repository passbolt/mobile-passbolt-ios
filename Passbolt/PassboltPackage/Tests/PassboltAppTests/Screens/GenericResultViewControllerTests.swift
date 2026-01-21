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

import FeatureScopes
import TestExtensions

@testable import Display
@testable import PassboltApp

// swift-format-ignore: AlwaysUseLowerCamelCase, NeverUseImplicitlyUnwrappedOptionals
final class GenericResultViewControllerTests: FeaturesTestCase {

  func test_viewState_matchesContext_initially() async throws {
    let context = GenericResultViewController.Context(
      icon: .successMark,
      title: "test.title",
      message: "test.message",
      buttonTitle: "test.button",
      buttonAction: {}
    )

    let tested: GenericResultViewController = try self.testedInstance(
      context: context
    )

    XCTAssertEqual(.successMark, tested.viewState.value.icon)
    XCTAssertEqual("test.title", tested.viewState.value.title)
    XCTAssertEqual("test.message", tested.viewState.value.message)
    XCTAssertEqual("test.button", tested.viewState.value.buttonTitle)
  }

  func test_viewState_message_canBeNil() async throws {
    let context = GenericResultViewController.Context(
      icon: .successMark,
      title: "test.title",
      message: .none,
      buttonTitle: "test.button",
      buttonAction: {}
    )

    let tested: GenericResultViewController = try self.testedInstance(
      context: context
    )

    XCTAssertNil(tested.viewState.value.message)
  }

  func test_handleButtonTap_executesAction() async throws {
    var actionExecuted: Bool = false
    let context = GenericResultViewController.Context(
      icon: .successMark,
      title: "test.title",
      buttonTitle: "test.button",
      buttonAction: {
        actionExecuted = true
      }
    )

    let tested: GenericResultViewController = try self.testedInstance(
      context: context
    )

    try await tested.handleButtonTap()

    XCTAssertTrue(actionExecuted)
  }

  func test_handleButtonTap_throwsError_whenActionFails() async throws {
    let context = GenericResultViewController.Context(
      icon: .failureMark,
      title: "test.title",
      buttonTitle: "test.button",
      buttonAction: {
        throw MockIssue.error()
      }
    )

    let tested: GenericResultViewController = try self.testedInstance(
      context: context
    )

    do {
      try await tested.handleButtonTap()
      XCTFail("Expected error to be thrown")
    }
    catch {
      // Expected
    }
  }

  func test_contextForError_setsCorrectValues() async throws {
    let error = MockIssue.error()
    let context = GenericResultViewController.Context.for(
      error: error,
      confirmation: {}
    )

    XCTAssertEqual(.failureMark, context.icon)
    XCTAssertEqual("generic.error", context.title)
    XCTAssertEqual("generic.try.again", context.buttonTitle)
    XCTAssertNotNil(context.message)
  }

  func test_contextForError_executesConfirmationAction() async throws {
    let confirmationExecuted: CriticalState<Bool> = .init(false)
    let context = GenericResultViewController.Context.for(
      error: MockIssue.error(),
      confirmation: {
        confirmationExecuted.set(true)
      }
    )

    let tested: GenericResultViewController = try self.testedInstance(
      context: context
    )

    try await tested.handleButtonTap()

    XCTAssertTrue(confirmationExecuted.get())
  }
}
