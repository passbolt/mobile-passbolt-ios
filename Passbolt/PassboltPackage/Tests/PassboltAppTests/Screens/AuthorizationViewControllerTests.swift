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

import Accounts
import FeatureScopes
import SharedUIComponents
import TestExtensions

@testable import Display
@testable import PassboltApp

// swift-format-ignore: AlwaysUseLowerCamelCase, NeverUseImplicitlyUnwrappedOptionals
final class AuthorizationViewControllerTests: FeaturesTestCase {

  override func commonPrepare() {
    super.commonPrepare()
    set(
      AccountScope.self,
      context: .mock_ada
    )
    patch(
      \AccountDetails.profile,
      with: always(.mock_ada)
    )
    patch(
      \AccountDetails.updates,
      with: Constant(()).asAnyUpdatable()
    )
    patch(
      \OSBiometry.availability,
      with: always(.unavailable)
    )
    patch(
      \AccountDetails.isPassphraseStored,
      with: always(false)
    )
    patch(
      \MediaDownloadNetworkOperation.execute,
      with: { _ in Data() }
    )
  }

  func test_viewState_initialValues_matchAccountDetails() async throws {
    let tested: AuthorizationViewController = try self.testedInstance(
      context: .mock_ada
    )
    let _ = await tested.viewState.current

    XCTAssertEqual(
      AccountWithProfile.mock_ada.label,
      tested.viewState.value.label
    )
    XCTAssertEqual(
      AccountWithProfile.mock_ada.username,
      tested.viewState.value.username
    )
    XCTAssertEqual(
      AccountWithProfile.mock_ada.domain.rawValue,
      tested.viewState.value.domain
    )
  }

  func test_viewState_biometricsAvailability_isUnavailable_initially() async throws {
    let tested: AuthorizationViewController = try self.testedInstance(
      context: .mock_ada
    )

    XCTAssertEqual(
      .unavailable,
      tested.viewState.value.biometricsAvailability
    )
  }

  func test_viewState_biometricsAvailability_isFaceID_whenAvailableAndPassphraseStored() async throws {
    patch(
      \OSBiometry.availability,
      with: always(.faceID)
    )
    patch(
      \AccountDetails.isPassphraseStored,
      with: always(true)
    )

    let tested: AuthorizationViewController = try self.testedInstance(
      context: .mock_ada
    )

    let _ = await tested.viewState.current

    XCTAssertEqual(
      .faceID,
      tested.viewState.value.biometricsAvailability
    )
  }

  func test_viewState_biometricsAvailability_isTouchID_whenAvailableAndPassphraseStored() async throws {
    patch(
      \OSBiometry.availability,
      with: always(.touchID)
    )
    patch(
      \AccountDetails.isPassphraseStored,
      with: always(true)
    )

    let tested: AuthorizationViewController = try self.testedInstance(
      context: .mock_ada
    )

    let _ = await tested.viewState.current

    XCTAssertEqual(
      .touchID,
      tested.viewState.value.biometricsAvailability
    )
  }

  func test_viewState_biometricsAvailability_isUnavailable_whenFaceIDAvailableButPassphraseNotStored() async throws {
    patch(
      \OSBiometry.availability,
      with: always(.faceID)
    )

    let tested: AuthorizationViewController = try self.testedInstance(
      context: .mock_ada
    )

    let _ = await tested.viewState.current

    XCTAssertEqual(
      .unavailable,
      tested.viewState.value.biometricsAvailability
    )
  }

  func test_loadAvatar_updatesAvatarData_whenSuccessful() async throws {
    // swift-format-ignore: NeverForceUnwrap
    let testData: Data = "test_avatar".data(using: .utf8)!
    patch(
      \MediaDownloadNetworkOperation.execute,
      with: { _ in testData }
    )

    let tested: AuthorizationViewController = try self.testedInstance(
      context: .mock_ada
    )

    await tested.loadAvatar()

    XCTAssertEqual(testData, tested.viewState.value.avatarData)
  }

  func test_signIn_callsSessionAuthorize_withPassphrase() async throws {
    let authorizedWithPassphrase: CriticalState<Bool> = .init(false)
    patch(
      \Session.authorize,
      with: { method in
        if case .passphrase = method {
          authorizedWithPassphrase.set(true)
        }
      }
    )

    let tested: AuthorizationViewController = try self.testedInstance(
      context: .mock_ada
    )

    await tested.signIn()

    XCTAssertTrue(authorizedWithPassphrase.get())
  }

  func test_biometricSignIn_callsSessionAuthorize_withBiometrics() async throws {
    let authorizedWithBiometrics: CriticalState<Bool> = .init(false)
    patch(
      \Session.authorize,
      with: { method in
        if case .biometrics = method {
          authorizedWithBiometrics.set(true)
        }
      }
    )

    let tested: AuthorizationViewController = try self.testedInstance(
      context: .mock_ada
    )

    await tested.biometricSignIn()

    XCTAssertTrue(authorizedWithBiometrics.get())
  }

  func test_tryBiometricSignIn_doesNothing_whenBiometricsUnavailable() async throws {
    let authorizeCalled: CriticalState<Bool> = .init(false)
    patch(
      \Session.authorize,
      with: { _ in
        authorizeCalled.set(true)
      }
    )

    let tested: AuthorizationViewController = try self.testedInstance(
      context: .mock_ada
    )

    await tested.tryBiometricSignIn()

    XCTAssertFalse(authorizeCalled.get())
  }

  func test_tryBiometricSignIn_authorizes_whenBiometricsAvailableAndPassphraseStored() async throws {
    let authorizeCalled: CriticalState<Bool> = .init(false)
    patch(
      \OSBiometry.availability,
      with: always(.faceID)
    )
    patch(
      \AccountDetails.isPassphraseStored,
      with: always(true)
    )
    patch(
      \Session.authorize,
      with: { _ in
        authorizeCalled.set(true)
      }
    )

    let tested: AuthorizationViewController = try self.testedInstance(
      context: .mock_ada
    )

    // Wait for async account details loading
    try await Task.sleep(nanoseconds: 100_000_000)
    await tested.tryBiometricSignIn()

    XCTAssertTrue(authorizeCalled.get())
  }

  func test_signIn_showsLoadingOverlay_duringAuthorization() async throws {
    let expectation = XCTestExpectation(description: "Loading overlay shown")
    patch(
      \Session.authorize,
      with: { _ in
        try await Task.sleep(nanoseconds: 100_000_000)
      }
    )

    let tested: AuthorizationViewController = try self.testedInstance(
      context: .mock_ada
    )

    Task {
      await tested.signIn()
    }

    // Wait briefly for loading to start
    try await Task.sleep(nanoseconds: 50_000_000)
    if tested.viewState.value.showLoadingOverlay {
      expectation.fulfill()
    }

    await fulfillment(of: [expectation], timeout: 1.0)
  }

  func test_signIn_hidesLoadingOverlay_afterAuthorization() async throws {
    patch(
      \Session.authorize,
      with: { _ in }
    )

    let tested: AuthorizationViewController = try self.testedInstance(
      context: .mock_ada
    )

    await tested.signIn()

    XCTAssertFalse(tested.viewState.value.showLoadingOverlay)
  }

  func test_signIn_navigatesToServerFingerprintInvalid_onFingerprintError() async throws {
    patch(
      \Session.authorize,
      with: alwaysThrow(
        ServerPGPFingeprintInvalid.error(
          account: .mock_ada,
          fingerprint: "test_fingerprint"
        )
      )
    )
    patch(
      \NavigationToServerFingerprintInvalid.performAnimated,
      with: always(self.mockExecuted())
    )

    let tested: AuthorizationViewController = try self.testedInstance(
      context: .mock_ada
    )

    await tested.signIn()

    XCTAssertTrue(self.mockWasExecuted)
  }

  func test_signIn_showsAlert_onServerConnectionIssue() async throws {
    patch(
      \Session.authorize,
      with: alwaysThrow(
        ServerConnectionIssue.error(
          serverURL: "https://test.passbolt.com"
        )
      )
    )

    let tested: AuthorizationViewController = try self.testedInstance(
      context: .mock_ada
    )

    await tested.signIn()

    XCTAssertNotNil(tested.viewState.value.alert)
    XCTAssertEqual(
      "server.not.reachable.alert.title",
      tested.viewState.value.alert?.title
    )
  }

  func test_signIn_showsAlert_onServerResponseTimeout() async throws {
    patch(
      \Session.authorize,
      with: alwaysThrow(
        ServerResponseTimeout.error(
          serverURL: "https://test.passbolt.com"
        )
      )
    )

    let tested: AuthorizationViewController = try self.testedInstance(
      context: .mock_ada
    )

    await tested.signIn()

    XCTAssertNotNil(tested.viewState.value.alert)
    XCTAssertEqual(
      "server.not.reachable.alert.title",
      tested.viewState.value.alert?.title
    )
  }

  func test_signIn_sendsSnackBarMessage_onGenericError() async throws {
    patch(
      \Session.authorize,
      with: alwaysThrow(MockIssue.error())
    )

    let messagesSubscription = SnackBarMessageEvent.subscribe()

    let tested: AuthorizationViewController = try self.testedInstance(
      context: .mock_ada
    )

    await tested.signIn()

    let payload: SnackBarMessageEvent.Payload? = try await messagesSubscription.nextEvent()
    XCTAssertNotNil(payload)
  }

  func test_forgotPassword_showsAlert() async throws {
    let tested: AuthorizationViewController = try self.testedInstance(
      context: .mock_ada
    )

    await tested.forgotPassword()

    XCTAssertNotNil(tested.viewState.value.alert)
    XCTAssertEqual(
      "authorization.forgot.passphrase.alert.title",
      tested.viewState.value.alert?.title
    )
  }

  func test_back_revertsNavigation() async throws {
    patch(
      \NavigationToAuthorization.revertAnimated,
      with: always(self.mockExecuted())
    )

    let tested: AuthorizationViewController = try self.testedInstance(
      context: .mock_ada
    )

    await tested.back()

    XCTAssertTrue(self.mockWasExecuted)
  }

  func test_presentHelp_navigatesToHelpMenu() async throws {
    patch(
      \NavigationToHelpMenu.performAnimated,
      with: always(self.mockExecuted())
    )

    let tested: AuthorizationViewController = try self.testedInstance(
      context: .mock_ada
    )

    await tested.presentHelp()

    XCTAssertTrue(self.mockWasExecuted)
  }
}
