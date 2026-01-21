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
      \AccountImport.progressPublisher,
      with: { Empty().eraseToAnyPublisher() }
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

  func test_viewState_progress_updatesFromPublisher() async throws {
    let progressSubject = PassthroughSubject<AccountImport.Progress, Error>()
    patch(
      \AccountImport.progressPublisher,
      with: { progressSubject.eraseToAnyPublisher() }
    )

    let tested: CodeScanningViewController = try self.testedInstance(
      context: ()
    )

    progressSubject.send(.scanningProgress(0.5))

    let currentState: CodeScanningViewController.ViewState = await tested.viewState.current

    XCTAssertEqual(0.5, currentState.progress)
  }

  func test_viewState_progress_reachesOne_whenScanningFinished() async throws {
    let progressSubject = PassthroughSubject<AccountImport.Progress, Error>()
    patch(
      \NavigationToGenericResult.performAnimated,
      with: always(self.mockExecuted())
    )
    patch(
      \AccountImport.progressPublisher,
      with: { progressSubject.eraseToAnyPublisher() }
    )

    let tested: CodeScanningViewController = try self.testedInstance(
      context: ()
    )

    progressSubject.send(.scanningFinished)

    let currentState: CodeScanningViewController.ViewState = await tested.viewState.current
    XCTAssertEqual(1.0, currentState.progress)
    try await verifyIf(
      self.mockWasExecuted,
      eventuallyEquals: true
    )
  }

  func test_viewState_progress_reachesOne_onError() async throws {
    let progressSubject = PassthroughSubject<AccountImport.Progress, Error>()
    patch(
      \NavigationToGenericResult.performAnimated,
      with: always(())
    )
    patch(
      \AccountImport.progressPublisher,
      with: { progressSubject.eraseToAnyPublisher() }
    )
    patch(
      \NavigationToGenericResult.performAnimated,
      with: always(Void())
    )

    let tested: CodeScanningViewController = try self.testedInstance(
      context: ()
    )

    progressSubject.send(completion: .failure(MockIssue.error()))
    let currentState: CodeScanningViewController.ViewState = await tested.viewState.current

    XCTAssertEqual(1.0, currentState.progress)

  }
}
