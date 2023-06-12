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
    patch(
      \AccountPreferences.isPassphraseStored,
      context: .mock_ada,
      with: always(true)
    )
    patch(
      \OSBiometry.availability,
      with: always(.faceID)
    )
    await withInstance(
      of: ApplicationSettingsController.self,
      returns: BiometricsAuthorizationAvailability.enabledFaceID
    ) { feature in
      await feature.updateViewState()
      return await feature.viewState.biometicsAuthorizationAvailability
    }
  }

  func
    test_viewState_biometicsAuthorizationAvailability_isDisabledInitially_whenPassphraseIsNotStoredAndBiometryAvailable()
    async
  {
    let accountPreferencesUpdates: UpdatesSequenceSource = .init()
    patch(
      \AccountPreferences.isPassphraseStored,
      context: .mock_ada,
      with: always(false)
    )
    patch(
      \OSBiometry.availability,
      with: always(.faceID)
    )
    await withInstance(
      of: ApplicationSettingsController.self,
      returns: BiometricsAuthorizationAvailability.disabledFaceID
    ) { feature in
      await feature.updateViewState()
      return await feature.viewState.biometicsAuthorizationAvailability
    }
  }

  func test_viewState_biometicsAuthorizationAvailability_isUnavailableInitially_whenBiometryIsNotAvailable() async {
    let accountPreferencesUpdates: UpdatesSequenceSource = .init()
    patch(
      \AccountPreferences.updates,
      context: .mock_ada,
      with: accountPreferencesUpdates.updatesSequence
    )
    patch(
      \OSBiometry.availability,
      with: always(.unavailable)
    )
    await withInstance(
      of: ApplicationSettingsController.self,
      returns: BiometricsAuthorizationAvailability.unavailable
    ) { feature in
      await self.asyncExecutionControl.addTask {
        accountPreferencesUpdates.endUpdates()
      }
      await self.asyncExecutionControl.executeAll()
      return await feature.viewState.biometicsAuthorizationAvailability
    }
  }

  func test_navigateToAutofillSettings_performsNavigation() async {
    patch(
      \NavigationToAutofillSettings.mockPerform,
      with: always(self.mockExecuted())
    )
    await withInstance(
      of: ApplicationSettingsController.self,
      mockExecuted: 1
    ) { feature in
      feature.navigateToAutofillSettings()
      await self.asyncExecutionControl.executeAll()
    }
  }

  func test_navigateToDefaultPresentationModeSettings_performsNavigation() async {
    patch(
      \NavigationToDefaultPresentationModeSettings.mockPerform,
      with: always(self.mockExecuted())
    )
    await withInstance(
      of: ApplicationSettingsController.self,
      mockExecuted: 1
    ) { feature in
      feature.navigateToDefaultPresentationModeSettings()
      await self.asyncExecutionControl.executeAll()
    }
  }

  func test_setBiometricsAuthorizationEnabled_updatesAccountPreferences() async {
    patch(
      \AccountPreferences.storePassphrase,
      context: .mock_ada,
      with: self.mockExecuted(with:)
    )

    await withInstance(
      of: ApplicationSettingsController.self,
      mockExecutedWith: true
    ) { feature in
      await feature.setBiometricsAuthorizationEnabled(true)
      await self.asyncExecutionControl.executeAll()
    }

    await withInstance(
      of: ApplicationSettingsController.self,
      mockExecutedWith: false
    ) { feature in
      await feature.setBiometricsAuthorizationEnabled(false)
      await self.asyncExecutionControl.executeAll()
    }
  }
}
