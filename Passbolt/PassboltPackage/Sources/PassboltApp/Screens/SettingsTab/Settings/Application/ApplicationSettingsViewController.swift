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
import Display
import FeatureScopes
import OSFeatures

internal final class ApplicationSettingsViewController: ViewController {

  internal struct ViewState: Equatable {

    internal var biometicsAuthorizationAvailability: BiometricsAuthorizationAvailability
    internal var snackBarMessage: SnackBarMessage?
  }

  internal let viewState: ViewStateSource<ViewState>

  private let navigationToAutofillSettings: NavigationToAutofillSettings
  private let navigationToDefaultModeSettings: NavigationToDefaultPresentationModeSettings
  private let accountPreferences: AccountPreferences

  internal init(
    context: Void,
    features: Features
  ) throws {
    try features.ensureScope(SettingsScope.self)
    try features.ensureScope(SessionScope.self)

    let currentAccount: Account = try features.sessionAccount()

    let osBiometry: OSBiometry = features.instance()

    self.navigationToAutofillSettings = try features.instance()
    self.navigationToDefaultModeSettings = try features.instance()

    self.accountPreferences = try features.instance(context: currentAccount)

    self.viewState = .init(
      initial: .init(
        biometicsAuthorizationAvailability: .unavailable,
        snackBarMessage: .none
      ),
      updateFrom: self.accountPreferences.updates,
      update: { [accountPreferences] (updateState, _) in
        switch osBiometry.availability() {
        case .unavailable, .unconfigured:
          await updateState { (viewState: inout ViewState) in
            viewState.biometicsAuthorizationAvailability = .unavailable
          }

        case .touchID:
          await updateState { (viewState: inout ViewState) in
            viewState.biometicsAuthorizationAvailability =
              accountPreferences.isPassphraseStored()
              ? .enabledTouchID
              : .disabledTouchID
          }

        case .faceID:
          await updateState { (viewState: inout ViewState) in
            viewState.biometicsAuthorizationAvailability =
              accountPreferences.isPassphraseStored()
              ? .enabledFaceID
              : .disabledFaceID
          }
        }
      }
    )
  }
}

extension ApplicationSettingsViewController {

  internal final func setBiometricsAuthorization(
    enabled: Bool
  ) async {
    await withLogCatch(
      failInfo: "Toggling biometric authorization failed!",
      fallback: { (error: Error) async in
        self.viewState.update(\.snackBarMessage, to: .error(error))
      }
    ) {
      try await self.accountPreferences.storePassphrase(enabled)
    }
  }

  nonisolated func navigateToAutofillSettings() async {
    await self.navigationToAutofillSettings.performCatching()
  }

  nonisolated func navigateToDefaultPresentationModeSettings() async {
    await self.navigationToDefaultModeSettings.performCatching()
  }
}
