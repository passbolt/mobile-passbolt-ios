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

// MARK: - Interface

internal struct ApplicationSettingsController {

  internal var viewState: MutableViewState<ViewState>

  internal var setBiometricsAuthorizationEnabled: (Bool) -> Void
  internal var navigateToAutofillSettings: () -> Void
  internal var navigateToDefaultPresentationModeSettings: () -> Void
}

extension ApplicationSettingsController: ViewController {

  internal struct ViewState: Equatable {

    internal var biometicsAuthorizationAvailability: BiometricsAuthorizationAvailability
  }

  #if DEBUG
  internal static var placeholder: Self {
    .init(
      viewState: .placeholder(),
      setBiometricsAuthorizationEnabled: unimplemented1(),
      navigateToAutofillSettings: unimplemented0(),
      navigateToDefaultPresentationModeSettings: unimplemented0()
    )
  }
  #endif
}

// MARK: - Implementation

extension ApplicationSettingsController {

  @MainActor fileprivate static func load(
    features: Features
  ) throws -> Self {
    try features.ensureScope(SettingsScope.self)
    try features.ensureScope(SessionScope.self)
    let currentAccount: Account = try features.sessionAccount()

    let diagnostics: OSDiagnostics = features.instance()
    let asyncExecutor: AsyncExecutor = try features.instance()

    let navigationToAutofillSettings: NavigationToAutofillSettings = try features.instance()
    let navigationToDefaultModeSettings: NavigationToDefaultPresentationModeSettings = try features.instance()

    let osBiometry: OSBiometry = features.instance()
    let accountPreferences: AccountPreferences = try features.instance(context: currentAccount)

    let viewState: MutableViewState<ViewState> = .init(
      initial: .init(
        biometicsAuthorizationAvailability: .unavailable
      )
    )

    asyncExecutor.schedule {
      for await _ in accountPreferences.updates {
        switch osBiometry.availability() {
        case .unavailable, .unconfigured:
          await viewState.update(
            \.biometicsAuthorizationAvailability,
            to: .unavailable
          )

        case .touchID:
          await viewState.update(
            \.biometicsAuthorizationAvailability,
            to: accountPreferences.isPassphraseStored()
              ? .enabledTouchID
              : .disabledTouchID
          )
        case .faceID:
          await viewState.update(
            \.biometicsAuthorizationAvailability,
            to: accountPreferences.isPassphraseStored()
              ? .enabledFaceID
              : .disabledFaceID
          )
        }
      }
    }

    nonisolated func setBiometricsAuthorizationEnabled(
      _ enabled: Bool
    ) {
      asyncExecutor.schedule(.reuse) {
        do {
          try await accountPreferences.storePassphrase(enabled)
        }
        catch {
          diagnostics
            .log(
              error:
                error
                .asTheError()
                .pushing(
                  .message("Enabling/Disabling biometric authorization failed!")
                )
            )
        }
      }
    }

    nonisolated func navigateToAutofillSettings() {
      asyncExecutor.schedule(.reuse) {
        do {
          try await navigationToAutofillSettings.perform()
        }
        catch {
          diagnostics
            .log(
              error:
                error
                .asTheError()
                .pushing(
                  .message("Navigation to autofill settings failed!")
                )
            )
        }
      }
    }

    nonisolated func navigateToDefaultPresentationModeSettings() {
      asyncExecutor.schedule(.reuse) {
        do {
          try await navigationToDefaultModeSettings.perform()
        }
        catch {
          diagnostics
            .log(
              error:
                error
                .asTheError()
                .pushing(
                  .message("Navigation to default presentation mode failed!")
                )
            )
        }
      }
    }

    return .init(
      viewState: viewState,
      setBiometricsAuthorizationEnabled: setBiometricsAuthorizationEnabled(_:),
      navigateToAutofillSettings: navigateToAutofillSettings,
      navigateToDefaultPresentationModeSettings: navigateToDefaultPresentationModeSettings
    )
  }
}

extension FeaturesRegistry {

  internal mutating func useLiveApplicationSettingsController() {
    self.use(
      .disposable(
        ApplicationSettingsController.self,
        load: ApplicationSettingsController.load(features:)
      ),
      in: SettingsScope.self
    )
  }
}
