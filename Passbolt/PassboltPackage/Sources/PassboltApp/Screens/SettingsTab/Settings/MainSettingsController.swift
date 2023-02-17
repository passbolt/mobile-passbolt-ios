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

import Display
import OSFeatures
import Session

// MARK: - Interface

internal struct MainSettingsController {

  internal var viewState: MutableViewState<ViewState>

  internal var navigateToApplicationSettings: () -> Void
  internal var navigateToAccountsSettings: () -> Void
  internal var navigateToTermsAndLicenses: () -> Void
  internal var navigateToTroubleshooting: () -> Void
  internal var signOut: () -> Void
}

extension MainSettingsController: ViewController {

  internal typealias ViewState = Stateless

  #if DEBUG
  internal static var placeholder: Self {
    .init(
      viewState: .placeholder(),
      navigateToApplicationSettings: unimplemented0(),
      navigateToAccountsSettings: unimplemented0(),
      navigateToTermsAndLicenses: unimplemented0(),
      navigateToTroubleshooting: unimplemented0(),
      signOut: unimplemented0()
    )
  }
  #endif
}

// MARK: - Implementation

extension MainSettingsController {

  @MainActor fileprivate static func load(
    features: Features
  ) throws -> Self {
    try features.ensureScope(SessionScope.self)
    let features: FeaturesContainer = features.branch(
      scope: SettingsScope.self
    )

    let currentAccount: Account = try features.sessionAccount()

    let diagnostics: OSDiagnostics = features.instance()

    let asyncExecutor: AsyncExecutor = try features.instance()

    let session: Session = try features.instance()

    let navigationToApplicationSettings: NavigationToApplicationSettings = try features.instance()
    let navigationToAccountsSettings: NavigationToAccountsSettings = try features.instance()
    let navigationToTermsAndLicenses: NavigationToTermsAndLicensesSettings = try features.instance()
    let navigationToTroubleshooting: NavigationToTroubleshootingSettings = try features.instance()

    let viewState: MutableViewState<ViewState> = .init(
      extendingLifetimeOf: features
    )

    nonisolated func navigateToApplicationSettings() {
      asyncExecutor.schedule(.reuse) {
        do {
          try await navigationToApplicationSettings.perform()
        }
        catch {
          diagnostics
            .log(
              error:
                error
                .asTheError()
                .pushing(
                  .message("Navigation to application settings failed!")
                )
            )
        }
      }
    }

    nonisolated func navigateToAccountsSettings() {
      asyncExecutor.schedule(.reuse) {
        do {
          try await navigationToAccountsSettings.perform()
        }
        catch {
          diagnostics
            .log(
              error:
                error
                .asTheError()
                .pushing(
                  .message("Navigation to accounts settings failed!")
                )
            )
        }
      }
    }

    nonisolated func navigateToTermsAndLicenses() {
      asyncExecutor.schedule(.reuse) {
        do {
          try await navigationToTermsAndLicenses.perform()
        }
        catch {
          diagnostics
            .log(
              error:
                error
                .asTheError()
                .pushing(
                  .message("Navigation to terms and licenses failed!")
                )
            )
        }
      }
    }

    nonisolated func navigateToTroubleshooting() {
      asyncExecutor.schedule(.reuse) {
        do {
          try await navigationToTroubleshooting.perform()
        }
        catch {
          diagnostics
            .log(
              error:
                error
                .asTheError()
                .pushing(
                  .message("Navigation to debug and logs failed!")
                )
            )
        }
      }
    }

    nonisolated func signOut() {
      asyncExecutor.schedule(.reuse) {
        await session.close(currentAccount)
      }
    }

    return .init(
      viewState: viewState,
      navigateToApplicationSettings: navigateToApplicationSettings,
      navigateToAccountsSettings: navigateToAccountsSettings,
      navigateToTermsAndLicenses: navigateToTermsAndLicenses,
      navigateToTroubleshooting: navigateToTroubleshooting,
      signOut: signOut
    )
  }
}

extension FeaturesRegistry {

  internal mutating func useLiveMainSettingsController() {
    self.use(
      .disposable(
        MainSettingsController.self,
        load: MainSettingsController.load(features:)
      ),
      in: SessionScope.self
    )
  }
}
