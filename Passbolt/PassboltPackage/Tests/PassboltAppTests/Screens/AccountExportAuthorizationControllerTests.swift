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

import TestExtensions

@testable import PassboltApp

// swift-format-ignore: AlwaysUseLowerCamelCase, NeverUseImplicitlyUnwrappedOptionals
final class AccountExportAuthorizationControllerTests: LoadableFeatureTestCase<AccountExportAuthorizationController> {

  override class var testedImplementationScope: any FeaturesScope.Type {
    SessionScope.self
  }

  override class func testedImplementationRegister(
    _ registry: inout FeaturesRegistry
  ) {
    registry.useAccountExportAuthorizationController()
  }

  override func prepare() throws {
    set(
      SessionScope.self,
      context: .init(
        account: .mock_ada,
        configuration: .mock_default
      )
    )
    patch(
      \AccountDetails.profile,
      context: .mock_ada,
      with: always(.mock_ada)
    )
    patch(
      \AccountDetails.avatarImage,
      context: .mock_ada,
      with: always(.none)
    )
    patch(
      \OSBiometry.availability,
      with: always(.unconfigured)
    )
    patch(
      \AccountPreferences.isPassphraseStored,
      context: .mock_ada,
      with: always(false)
    )
  }

  func test_viewState_equalsMockedData_initially() {
    withTestedInstanceReturnsEqual(
      AccountExportAuthorizationController.ViewState(
        accountLabel: AccountWithProfile.mock_ada.label,
        accountUsername: AccountWithProfile.mock_ada.username,
        accountDomain: AccountWithProfile.mock_ada.domain.rawValue,
        accountAvatarImage: .none,
        biometricsAvailability: .unavailable,
        passphrase: .valid(""),
        snackBarMessage: .none
      )
    ) { feature in
      await feature.viewState.wrappedValue
    }
  }

  func test_viewState_biometrics_isUnavailable_whenBiometricsAvailableAndPassphraseNotStored() {
    patch(
      \OSBiometry.availability,
      with: always(.faceID)
    )
    patch(
      \AccountPreferences.isPassphraseStored,
      context: Account.mock_ada,
      with: always(false)
    )

    withTestedInstanceReturnsEqual(
      .unavailable
    ) { feature in
      await feature.viewState.biometricsAvailability
    }
  }

  func test_viewState_biometrics_isAvailable_whenBiometricsAvailableAndPassphraseStored() {
    patch(
      \OSBiometry.availability,
      with: always(.faceID)
    )
    patch(
      \AccountPreferences.isPassphraseStored,
      context: Account.mock_ada,
      with: always(true)
    )

    withTestedInstanceReturnsEqual(
      .faceID
    ) { feature in
      await feature.viewState.biometricsAvailability
    }
  }

  func test_setPassphrase_updatesViewState() {
    withTestedInstanceReturnsEqual(
      "updated_passphrase"
    ) { feature in
      await feature.setPassphrase("updated_passphrase")
      return await feature.viewState.passphrase.value.rawValue
    }
  }

  func test_setPassphrase_validatesPassphrase() {
    withTestedInstanceReturnsEqual(
      Validated<Passphrase>.valid("valid_passphrase")
    ) { feature in
      await feature.setPassphrase("valid_passphrase")
      return await feature.viewState.passphrase
    }

    withTestedInstanceReturnsEqual(
      Validated<Passphrase>
        .invalid(
          "",
          errors:
            InvalidValue
            .empty(
              value: "",
              displayable: .localized(
                key: "authorization.passphrase.error"
              )
            )
        )
    ) { feature in
      await feature.setPassphrase("")
      return await feature.viewState.passphrase
    }
  }

  func test_authorizeWithBiometrics_failsWithMessage_whenAuthorizationFails() {
    patch(
      \AccountChunkedExport.authorize,
      with: alwaysThrow(MockIssue.error())
    )

    withTestedInstanceReturnsEqual(
      SnackBarMessage.error(.testMessage())
    ) { feature in
      feature.authorizeWithBiometrics()
      await self.mockExecutionControl.executeAll()
      return await feature.viewState.snackBarMessage
    }
  }

  func test_authorizeWithBiometrics_succeeds_whenAuthorizationSucceeds() {
    #warning("TODO: there should be test that checks if navigation was triggered, but that requires update in app navigation to be verified")
    patch(
      \AccountChunkedExport.authorize,
      with: always(Void())
    )

    withTestedInstanceReturnsNone { feature in
      feature.authorizeWithBiometrics()
      await self.mockExecutionControl.executeAll()
      return await feature.viewState.snackBarMessage
    }
  }

  func test_authorizeWithPassphrase_failsWithMessage_whenPassphraseIsInvalid() {
    patch(
      \AccountChunkedExport.authorize,
      with: alwaysThrow(MockIssue.error())
    )

    withTestedInstanceReturnsEqual(
      SnackBarMessage
        .error(
          .localized(
            key: "authorization.passphrase.error"
          )
        )
    ) { feature in
      feature.authorizeWithPassphrase()
      await self.mockExecutionControl.executeAll()
      return await feature.viewState.snackBarMessage
    }
  }

  func test_authorizeWithPassphrase_failsWithMessage_whenAuthorizationFails() {
    patch(
      \AccountChunkedExport.authorize,
      with: alwaysThrow(MockIssue.error())
    )

    withTestedInstanceReturnsEqual(
      SnackBarMessage.error(.testMessage())
    ) { feature in
      await feature.setPassphrase("valid_passphrase")
      feature.authorizeWithPassphrase()
      await self.mockExecutionControl.executeAll()
      return await feature.viewState.snackBarMessage
    }
  }

  func test_authorizeWithPassphrase_succeeds_whenAuthorizationSucceeds() {
    #warning("TODO: there should be test that checks if navigation was triggered, but that requires update in app navigation to be verified")
    patch(
      \AccountChunkedExport.authorize,
      with: always(Void())
    )

    withTestedInstanceReturnsNone { feature in
      await feature.setPassphrase("valid_passphrase")
      feature.authorizeWithBiometrics()
      await self.mockExecutionControl.executeAll()
      return await feature.viewState.snackBarMessage
    }
  }
}
