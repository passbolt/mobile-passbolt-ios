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
import FeatureScopes
import OSFeatures
import Session

internal final class MainSettingsController: ViewController {

  private let currentAccount: Account
  private let diagnostics: OSDiagnostics
  private let asyncExecutor: AsyncExecutor
  private let session: Session
  private let navigationToApplicationSettings: NavigationToApplicationSettings
  private let navigationToAccountsSettings: NavigationToAccountsSettings
  private let navigationToTermsAndLicenses: NavigationToTermsAndLicensesSettings
  private let navigationToTroubleshooting: NavigationToTroubleshootingSettings

  private let features: Features

  internal init(
    context: Void,
    features: Features
  ) throws {
    try features.ensureScope(SessionScope.self)
    let features: FeaturesContainer = features.branch(
      scope: SettingsScope.self
    )
    self.features = features

    self.currentAccount = try features.sessionAccount()
    self.diagnostics = features.instance()
    self.asyncExecutor = try features.instance()
    self.session = try features.instance()
    self.navigationToApplicationSettings = try features.instance()
    self.navigationToAccountsSettings = try features.instance()
    self.navigationToTermsAndLicenses = try features.instance()
    self.navigationToTroubleshooting = try features.instance()
  }
}

extension MainSettingsController {

  internal final func navigateToApplicationSettings() {
    self.asyncExecutor
      .scheduleCatchingWith(
        self.diagnostics,
        failMessage: "Navigation to application settings failed!",
        behavior: .reuse
      ) { [navigationToApplicationSettings] in
        try await navigationToApplicationSettings.perform()
      }
  }

  internal final func navigateToAccountsSettings() {
    self.asyncExecutor
      .scheduleCatchingWith(
        self.diagnostics,
        failMessage: "Navigation to accounts settings failed!",
        behavior: .reuse
      ) { [navigationToAccountsSettings] in
        try await navigationToAccountsSettings.perform()
      }
  }

  internal final func navigateToTermsAndLicenses() {
    self.asyncExecutor
      .scheduleCatchingWith(
        self.diagnostics,
        failMessage: "Navigation to terms and licenses failed!",
        behavior: .reuse
      ) { [navigationToTermsAndLicenses] in
        try await navigationToTermsAndLicenses.perform()
      }
  }

  internal final func navigateToTroubleshooting() {
    self.asyncExecutor
      .scheduleCatchingWith(
        self.diagnostics,
        failMessage: "Navigation to troubleshooting failed!",
        behavior: .reuse
      ) { [navigationToTroubleshooting] in
        try await navigationToTroubleshooting.perform()
      }
  }

  internal final func signOut() {
    self.asyncExecutor.schedule(.reuse) { [session, currentAccount] in
      await session.close(currentAccount)
    }
  }
}
