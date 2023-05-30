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
import OSFeatures

internal final class ApplicationSettingsController: ViewController {

  internal nonisolated let viewState: MutableViewState<ViewState>

  private let currentAccount: Account
  private let diagnostics: OSDiagnostics
  private let asyncExecutor: AsyncExecutor
  private let navigationToAutofillSettings: NavigationToAutofillSettings
  private let navigationToDefaultModeSettings: NavigationToDefaultPresentationModeSettings
  private let osBiometry: OSBiometry
  private let accountPreferences: AccountPreferences

  internal init(
    context: Void,
    features: Features
  ) throws {
    try features.ensureScope(SettingsScope.self)
    try features.ensureScope(SessionScope.self)

    self.currentAccount = try features.sessionAccount()
    self.diagnostics = features.instance()
    self.asyncExecutor = try features.instance()
    self.navigationToAutofillSettings = try features.instance()
    self.navigationToDefaultModeSettings = try features.instance()
    self.osBiometry = features.instance()
    self.accountPreferences = try features.instance(context: currentAccount)

    self.viewState = .init(
      initial: .init(
        biometicsAuthorizationAvailability: .unavailable
      )
    )
  }
}

extension ApplicationSettingsController {

  internal struct ViewState: Equatable {

    internal var biometicsAuthorizationAvailability: BiometricsAuthorizationAvailability
  }
}

extension ApplicationSettingsController {

	@Sendable internal func activate() async {
		await self.diagnostics
			.withLogCatch(
				info: .message("Application settings updates broken!")
			) {
				for try await _ in self.accountPreferences.updates {
					self.updateViewState()
				}
			}
	}

	internal func updateViewState() {
		switch self.osBiometry.availability() {
		case .unavailable, .unconfigured:
			self.viewState.update(
				\.biometicsAuthorizationAvailability,
				to: .unavailable
			)

		case .touchID:
			self.viewState.update(
				\.biometicsAuthorizationAvailability,
				to: self.accountPreferences.isPassphraseStored()
					? .enabledTouchID
					: .disabledTouchID
			)
		case .faceID:
			self.viewState.update(
				\.biometicsAuthorizationAvailability,
				to: self.accountPreferences.isPassphraseStored()
					? .enabledFaceID
					: .disabledFaceID
			)
		}
	}

  internal final func setBiometricsAuthorizationEnabled(
    _ enabled: Bool
  ) {
    self.asyncExecutor.scheduleCatchingWith(
      self.diagnostics,
      failMessage: "Toggling biometric authorization failed!",
      behavior: .reuse
    ) { [accountPreferences] in
      try await accountPreferences.storePassphrase(enabled)
    }
  }

  nonisolated func navigateToAutofillSettings() {
    self.asyncExecutor
      .scheduleCatchingWith(
        self.diagnostics,
        failMessage: "Navigation to autofill settings failed!",
        behavior: .reuse
      ) { [navigationToAutofillSettings] in
        try await navigationToAutofillSettings.perform()
      }
  }

  nonisolated func navigateToDefaultPresentationModeSettings() {
    self.asyncExecutor
      .scheduleCatchingWith(
        self.diagnostics,
        failMessage: "Navigation to default presentation mode failed!",
        behavior: .reuse
      ) { [navigationToDefaultModeSettings] in
        try await navigationToDefaultModeSettings.perform()
      }
  }
}
