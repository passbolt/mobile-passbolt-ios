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

@available(iOS 16.0.0, *)
final class ApplicationSettingsControllerTests: FeaturesTestCase {

  override func commonPrepare() {
    super.commonPrepare()
    set(
      SessionScope.self,
      context: .init(
        account: .mock_ada,
        configuration: .mock_default
      )
    )
    set(SettingsScope.self)
  }

  func test_viewState_biometicsAuthorizationAvailability_isEnabledInitially_whenPassphraseIsStoredAndBiometryAvailable()
    async
  {
    let accountPreferencesUpdates: Updates = .init()
    patch(
      \AccountPreferences.updates,
      with: accountPreferencesUpdates.asAnyUpdatable()
    )
    patch(
      \AccountPreferences.isPassphraseStored,
      with: always(true)
    )
    patch(
      \OSBiometry.availability,
      with: always(.faceID)
    )
    await withInstance(
      of: ApplicationSettingsViewController.self,
      returns: BiometricsAuthorizationAvailability.enabledFaceID
    ) { feature in
      return await feature.viewState.current.biometicsAuthorizationAvailability
    }
  }

  func
    test_viewState_biometicsAuthorizationAvailability_isDisabledInitially_whenPassphraseIsNotStoredAndBiometryAvailable()
    async
  {
    let accountPreferencesUpdates: Updates = .init()
    patch(
      \AccountPreferences.updates,
      with: accountPreferencesUpdates.asAnyUpdatable()
    )
    patch(
      \AccountPreferences.isPassphraseStored,
      with: always(false)
    )
    patch(
      \OSBiometry.availability,
      with: always(.faceID)
    )
    await withInstance(
      of: ApplicationSettingsViewController.self,
      returns: BiometricsAuthorizationAvailability.disabledFaceID
    ) { feature in
      await feature.viewState.updateIfNeeded()
      return await feature.viewState.current.biometicsAuthorizationAvailability
    }
  }

  func test_viewState_biometicsAuthorizationAvailability_isUnavailableInitially_whenBiometryIsNotAvailable() async {
    let accountPreferencesUpdates: Updates = .init()
    patch(
      \AccountPreferences.updates,
      with: accountPreferencesUpdates.asAnyUpdatable()
    )
    patch(
      \OSBiometry.availability,
      with: always(.unavailable)
    )
    await withInstance(
      of: ApplicationSettingsViewController.self,
      returns: BiometricsAuthorizationAvailability.unavailable
    ) { feature in
      
      return await feature.viewState.current.biometicsAuthorizationAvailability
    }
  }

  func test_navigateToAutofillSettings_performsNavigation() async {
    patch(
      \NavigationToAutofillSettings.mockPerform,
      with: always(self.mockExecuted())
    )
    await withInstance(
      of: ApplicationSettingsViewController.self,
      mockExecuted: 1
    ) { feature in
      await feature.navigateToAutofillSettings()
      
    }
  }

  func test_navigateToDefaultPresentationModeSettings_performsNavigation() async {
    patch(
      \NavigationToDefaultPresentationModeSettings.mockPerform,
      with: always(self.mockExecuted())
    )
    await withInstance(
      of: ApplicationSettingsViewController.self,
      mockExecuted: 1
    ) { feature in
      await feature.navigateToDefaultPresentationModeSettings()
      
    }
  }

  func test_setBiometricsAuthorizationEnabled_updatesAccountPreferences() async {
    patch(
      \AccountPreferences.storePassphrase,
      with: self.mockExecuted(with:)
    )

    await withInstance(
      of: ApplicationSettingsViewController.self,
      mockExecutedWith: true
    ) { feature in
      await feature.setBiometricsAuthorization(enabled: true)
      
    }

    await withInstance(
      of: ApplicationSettingsViewController.self,
      mockExecutedWith: false
    ) { feature in
      await feature.setBiometricsAuthorization(enabled: false)
      
    }
  }
}
