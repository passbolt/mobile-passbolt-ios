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
final class AccountExportAuthorizationControllerTests: FeaturesTestCase {

  override func commonPrepare() {
    super.commonPrepare()
    set(
      SessionScope.self,
      context: .init(
        account: .mock_ada,
        configuration: .mock_default
      )
    )
    patch(
      \AccountDetails.profile,
      with: always(.mock_ada)
    )
    patch(
      \AccountDetails.avatarImage,
      with: always(.none)
    )
    patch(
      \OSBiometry.availability,
      with: always(.unconfigured)
    )
    patch(
      \AccountPreferences.isPassphraseStored,
      with: always(false)
    )
  }

  func test_viewState_equalsMockedData_initially() async throws {
    let tested: AccountExportAuthorizationController = try self.testedInstance()

    XCTAssertEqual(
      AccountExportAuthorizationController.ViewState(
        accountLabel: AccountWithProfile.mock_ada.label,
        accountUsername: AccountWithProfile.mock_ada.username,
        accountDomain: AccountWithProfile.mock_ada.domain.rawValue,
        accountAvatarImage: .none,
        biometricsAvailability: .unavailable,
        passphrase: .valid("")
      ),
      tested.viewState.value
    )
  }

  func test_viewState_biometrics_isUnavailable_whenBiometricsAvailableAndPassphraseNotStored() async throws {
    patch(
      \OSBiometry.availability,
      with: always(.faceID)
    )
    patch(
      \AccountPreferences.isPassphraseStored,
      with: always(false)
    )

    let tested: AccountExportAuthorizationController = try self.testedInstance()

    XCTAssertEqual(
      .unavailable,
      tested.viewState.value.biometricsAvailability
    )
  }

  func test_viewState_biometrics_isAvailable_whenBiometricsAvailableAndPassphraseStored() async throws {
    patch(
      \OSBiometry.availability,
      with: always(.faceID)
    )
    patch(
      \AccountPreferences.isPassphraseStored,
      with: always(true)
    )

    let tested: AccountExportAuthorizationController = try self.testedInstance()

    XCTAssertEqual(
      .faceID,
      tested.viewState.value.biometricsAvailability
    )
  }

  func test_setPassphrase_updatesViewState() async throws {
    let tested: AccountExportAuthorizationController = try self.testedInstance()

    tested.setPassphrase("updated_passphrase")
    XCTAssertEqual(
      "updated_passphrase",
      tested.viewState.value.passphrase.value.rawValue
    )
  }

  func test_setPassphrase_validatesPassphrase() async throws {
    let tested: AccountExportAuthorizationController = try self.testedInstance()


    tested.setPassphrase("valid_passphrase")
    XCTAssertEqual(
      Validated<Passphrase>.valid("valid_passphrase"),
      tested.viewState.value.passphrase
    )

    tested.setPassphrase("")
    XCTAssertEqual(
      Validated<Passphrase>
        .invalid(
          "",
          error:
            InvalidValue
            .empty(
              value: "",
              displayable: .localized(
                key: "authorization.passphrase.error"
              )
            )
        ),
      tested.viewState.value.passphrase
    )
  }

	func test_authorizeWithBiometrics_failsWithMessage_whenAuthorizationFails() async throws {
		patch(
			\AccountChunkedExport.authorize,
			 with: alwaysThrow(MockIssue.error())
		)

		var messagesSubscription = SnackBarMessageEvent.subscribe()

		let tested: AccountExportAuthorizationController = try self.testedInstance()

		try await tested.authorizeWithBiometrics()


    let payload: SnackBarMessageEvent.Payload? = try await messagesSubscription.nextEvent()
		XCTAssertEqual(
      SnackBarMessageEvent.Payload.show(SnackBarMessage.error("generic.error")),
      payload
		)
	}

	func test_authorizeWithBiometrics_succeeds_whenAuthorizationSucceeds() async throws {
#warning("TODO: there should be test that checks if navigation was triggered, but that requires update in app navigation to be verified")
		patch(
			\AccountChunkedExport.authorize,
			 with: always(Void())
		)

		let tested: AccountExportAuthorizationController = try self.testedInstance()

		await tested.authorizeWithBiometrics()
		

		// Temporary fix for pending tasks on queue, will be removed after using proper navigation
		
	}

  func test_authorizeWithPassphrase_failsWithMessage_whenPassphraseIsInvalid() async throws {
    patch(
      \AccountChunkedExport.authorize,
      with: alwaysThrow(MockIssue.error())
    )

		var messagesSubscription = SnackBarMessageEvent.subscribe()

    let tested: AccountExportAuthorizationController = try self.testedInstance()


    await tested.authorizeWithPassphrase()

		let payload: SnackBarMessageEvent.Payload? = try await messagesSubscription.nextEvent()
    XCTAssertEqual(
      SnackBarMessageEvent.Payload.show(SnackBarMessage
        .error(
          .localized(
            key: "authorization.passphrase.error"
          )
        )),
      payload
    )
  }

  func test_authorizeWithPassphrase_failsWithMessage_whenAuthorizationFails() async throws {
    patch(
      \AccountChunkedExport.authorize,
      with: alwaysThrow(MockIssue.error())
    )

		var messagesSubscription = SnackBarMessageEvent.subscribe()

    let tested: AccountExportAuthorizationController = try self.testedInstance()


    tested.setPassphrase("valid_passphrase")
    try await tested.authorizeWithPassphrase()

		let payload: SnackBarMessageEvent.Payload? = try await messagesSubscription.nextEvent()
    XCTAssertEqual(
      SnackBarMessageEvent.Payload.show(SnackBarMessage.error("generic.error")),
      payload
    )
  }

  func test_authorizeWithPassphrase_succeeds_whenAuthorizationSucceeds() async throws {
    #warning("TODO: there should be test that checks if navigation was triggered, but that requires update in app navigation to be verified")
    patch(
      \AccountChunkedExport.authorize,
      with: always(Void())
    )

    let tested: AccountExportAuthorizationController = try self.testedInstance()

    tested.setPassphrase("valid_passphrase")
    await tested.authorizeWithBiometrics()

    // Temporary fix for pending tasks on queue, will be removed after using proper navigation
  }
}
