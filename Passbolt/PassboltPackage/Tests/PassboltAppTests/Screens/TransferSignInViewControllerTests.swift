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
import FeatureScopes
import TestExtensions

@testable import Display
@testable import PassboltApp

// swift-format-ignore: AlwaysUseLowerCamelCase, NeverUseImplicitlyUnwrappedOptionals
final class TransferSignInViewControllerTests: FeaturesTestCase {

  override func commonPrepare() async throws {
    try await super.commonPrepare()
    patch(
      \AccountImport.updates,
      with: TestUpdatable<Void>().asAnyUpdatable()
    )
    patch(
      \AccountImport.accountDetails,
      with: { nil }
    )
    patch(
      \AccountImport.avatar,
      with: { nil }
    )
    patch(
      \AccountImport.progress,
      with: { .configuration }
    )
  }

  func test_viewState_account_isNil_initially() async throws {
    let tested: TransferSignInViewController = try self.testedInstance(
      context: ()
    )

    XCTAssertNil(tested.viewState.value.account)
  }

  func test_viewState_avatarData_isNil_initially() async throws {
    let tested: TransferSignInViewController = try self.testedInstance(
      context: ()
    )

    XCTAssertNil(tested.viewState.value.avatarData)
  }

  func test_viewState_passphrase_isValid_initially() async throws {
    let tested: TransferSignInViewController = try self.testedInstance(
      context: ()
    )

    XCTAssertEqual(Validated<String>.valid(""), tested.viewState.value.passphrase)
  }

  func test_viewState_isLoading_isFalse_initially() async throws {
    let tested: TransferSignInViewController = try self.testedInstance(
      context: ()
    )

    XCTAssertFalse(tested.viewState.value.isLoading)
  }

  func test_viewState_account_updatesFromUpdatable() async throws {
    let accountDetails = AccountImport.AccountDetails(
      domain: "passbolt.local",
      label: "Ada Lovelace",
      username: "ada@passbolt.com"
    )
    let stateVariable = Variable<Void>(initial: ())
    patch(
      \AccountImport.updates,
      with: stateVariable.map { _ in () }.asAnyUpdatable()
    )
    patch(
      \AccountImport.accountDetails,
      with: { accountDetails }
    )

    let tested: TransferSignInViewController = try self.testedInstance(
      context: ()
    )

    // Trigger an update
    stateVariable.assign(())

    // Allow async update to propagate
    try await Task.sleep(for: .milliseconds(100))

    let currentState = await tested.viewState.current
    XCTAssertNotNil(currentState.account)
    XCTAssertEqual("ada@passbolt.com", currentState.account?.username)
  }

  func test_viewState_avatarData_updatesFromUpdatable() async throws {
    // swift-format-ignore: NeverForceUnwrap
    let testAvatarData = "test_avatar".data(using: .utf8)!
    let stateVariable = Variable<Void>(initial: ())
    patch(
      \AccountImport.updates,
      with: stateVariable.map { _ in () }.asAnyUpdatable()
    )
    patch(
      \AccountImport.avatar,
      with: { testAvatarData }
    )

    let tested: TransferSignInViewController = try self.testedInstance(
      context: ()
    )

    // Trigger an update
    stateVariable.assign(())

    // Allow async update to propagate
    try await Task.sleep(for: .milliseconds(100))

    let currentState = await tested.viewState.current

    XCTAssertEqual(testAvatarData, currentState.avatarData)
  }
}

private final class TestUpdatable<Value: Sendable>: Updatable, @unchecked Sendable {

  var generation: UpdateGeneration { .uninitialized }

  func notify(
    _ awaiter: @escaping @Sendable (Update<Value>) -> Void,
    after generation: UpdateGeneration
  ) {
    // No-op for test placeholder
  }
}
