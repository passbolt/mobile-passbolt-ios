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
final class CodeScanningViewControllerTests: FeaturesTestCase {

  override func commonPrepare() {
    super.commonPrepare()
    set(
      AccountTransferScope.self
    )
    patch(
      \AccountImport.updates,
      with: TestUpdatable<Void>().asAnyUpdatable()
    )
    patch(
      \AccountImport.progress,
      with: { .configuration }
    )
  }

  func test_viewState_progress_isZero_initially() async throws {
    let tested: CodeScanningViewController = try self.testedInstance(
      context: ()
    )

    XCTAssertEqual(0.0, tested.viewState.value.progress)
  }

  func test_viewState_alert_isNil_initially() async throws {
    let tested: CodeScanningViewController = try self.testedInstance(
      context: ()
    )

    XCTAssertNil(tested.viewState.value.alert)
  }

  func test_viewState_progress_updatesFromUpdatable() async throws {
    let stateVariable = Variable<Void>(initial: ())
    let currentProgress: AccountImport.Progress = .scanningProgress(0.5)
    patch(
      \AccountImport.updates,
      with: stateVariable.map { _ in () }.asAnyUpdatable()
    )
    patch(
      \AccountImport.progress,
      with: { currentProgress }
    )

    let tested: CodeScanningViewController = try self.testedInstance(
      context: ()
    )

    // Trigger an update
    stateVariable.assign(())

    // Allow async update to propagate
    try await Task.sleep(for: .milliseconds(100))

    let currentState: CodeScanningViewController.ViewState = await tested.viewState.current

    XCTAssertEqual(0.5, currentState.progress)
  }

  func test_viewState_progress_reachesOne_whenScanningFinished() async throws {
    let stateVariable = Variable<Void>(initial: ())
    let currentProgress: AccountImport.Progress = .scanningFinished
    patch(
      \NavigationToGenericResult.performAnimated,
      with: always(self.mockExecuted())
    )
    patch(
      \AccountImport.updates,
      with: stateVariable.map { _ in () }.asAnyUpdatable()
    )
    patch(
      \AccountImport.progress,
      with: { currentProgress }
    )

    let tested: CodeScanningViewController = try self.testedInstance(
      context: ()
    )

    // Trigger an update
    stateVariable.assign(())

    // Allow async update to propagate
    try await Task.sleep(for: .milliseconds(100))

    let currentState: CodeScanningViewController.ViewState = await tested.viewState.current
    XCTAssertEqual(1.0, currentState.progress)
    try await verifyIf(
      self.mockWasExecuted,
      eventuallyEquals: true
    )
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
