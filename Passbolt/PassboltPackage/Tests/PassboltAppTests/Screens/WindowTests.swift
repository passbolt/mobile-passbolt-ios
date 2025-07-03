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
import TestExtensions
import UIComponents
import XCTest

@testable import Accounts
@testable import PassboltApp

// swift-format-ignore: AlwaysUseLowerCamelCase, NeverUseImplicitlyUnwrappedOptionals
@MainActor
final class WindowTests: MainActorTestCase {

  func
    test_screenStateDispositionSequence_returnsRequestPassphrase_whenRequestedPassphrase()
    async throws
  {
    let controller: WindowController = try await testController()

    SessionStateChangeEvent.send(.requestedPassphrase(for: .mock_ada))

    let result: WindowController.ScreenStateDisposition? = try await controller.screenStateDispositionSequence().first()

    guard case .requestPassphrase(let account, let message) = result
    else { return XCTFail() }
    XCTAssertEqual(account, Account.mock_ada)
    XCTAssertNil(message)
  }

  func
    test_screenStateDispositionSequence_returnsRequestMFA_whenRequestedMFA()
    async throws
  {
    let controller: WindowController = try await testController()

    SessionStateChangeEvent.send(.requestedMFA(for: .mock_ada, providers: []))

    let result: WindowController.ScreenStateDisposition? = try await controller.screenStateDispositionSequence().first()

    guard case .requestMFA(let account, let providers) = result
    else { return XCTFail() }
    XCTAssertEqual(account, Account.mock_ada)
    XCTAssertEqual(providers, [])
  }

  func test_screenStateDispositionSequence_returnsUseAuthorizedScreenState_whenAuthorized()
    async throws
  {
    let controller: WindowController = try await testController()

    SessionStateChangeEvent.send(.authorized(.mock_ada))

    let result: WindowController.ScreenStateDisposition? = try await controller.screenStateDispositionSequence().first()

    guard case .useAuthorizedScreenState(let account) = result
    else { return XCTFail() }
    XCTAssertEqual(account, Account.mock_ada)
  }

  func test_screenStateDispositionSequence_returnsUseInitialScreenState_whenSessionCloses()
    async throws
  {
    let controller: WindowController = try await testController()

    SessionStateChangeEvent.send(.closed)

    let result: WindowController.ScreenStateDisposition? = try await controller.screenStateDispositionSequence().first()

    guard case .useInitialScreenState = result
    else { return XCTFail() }
  }
}
