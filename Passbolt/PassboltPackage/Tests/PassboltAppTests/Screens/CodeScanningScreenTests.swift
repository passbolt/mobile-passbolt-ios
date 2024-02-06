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

import AccountSetup
import Combine
import Features
import TestExtensions
import UIComponents
import XCTest

@testable import PassboltApp

// swift-format-ignore: AlwaysUseLowerCamelCase, NeverUseImplicitlyUnwrappedOptionals
@MainActor
final class CodeScanningScreenTests: MainActorTestCase {

  func test_exitConfirmation_isPresented_whenCallingPresent() async throws {
    features.patch(
      \AccountImport.progressPublisher,
      with: always(
        Just(.configuration)
          .eraseErrorType()
          .eraseToAnyPublisher()
      )
    )
    let controller: CodeScanningController = try await testController()
    var result: Bool!

    controller.exitConfirmationPresentationPublisher()
      .receive(on: ImmediateScheduler.shared)
      .sink { presented in
        result = presented
      }
      .store(in: cancellables)

    controller.presentExitConfirmation()

    XCTAssertTrue(result)
  }

  func test_help_isPresented_whenCallingPresent() async throws {
    features.patch(
      \AccountImport.progressPublisher,
      with: always(
        Just(.configuration)
          .eraseErrorType()
          .eraseToAnyPublisher()
      )
    )
    let controller: CodeScanningController = try await testController()
    var result: Bool!

    controller.helpPresentationPublisher()
      .receive(on: ImmediateScheduler.shared)
      .sink { presented in
        result = presented
      }
      .store(in: cancellables)

    controller.presentHelp()

    XCTAssertTrue(result)
  }

  func test_initialProgress_isEmpty() async throws {
    features.patch(
      \AccountImport.progressPublisher,
      with: always(
        Just(.configuration)
          .eraseErrorType()
          .eraseToAnyPublisher()
      )
    )
    let controller: CodeScanningController = try await testController()
    var result: Double!

    controller.progressPublisher()
      .replaceError(with: 0)  // ignore error but fail test
      .receive(on: ImmediateScheduler.shared)
      .sink { progress in
        result = progress
      }
      .store(in: cancellables)

    XCTAssertEqual(result, 0)
    XCTAssertLessThan(result, 1)
  }
}
