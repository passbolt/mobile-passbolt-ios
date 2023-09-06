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

internal final class MainSettingsViewController: ViewController {

  private let currentAccount: Account

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
    let features: FeaturesContainer = try features.branch(
      scope: SettingsScope.self
    )
    self.features = features

    self.currentAccount = try features.sessionAccount()

    self.session = try features.instance()
    self.navigationToApplicationSettings = try features.instance()
    self.navigationToAccountsSettings = try features.instance()
    self.navigationToTermsAndLicenses = try features.instance()
    self.navigationToTroubleshooting = try features.instance()
  }
}

extension MainSettingsViewController {

  internal final func navigateToApplicationSettings() async {
    await self.navigationToApplicationSettings.performCatching()
  }

  internal final func navigateToAccountsSettings() async {
    await self.navigationToAccountsSettings.performCatching()
  }

  internal final func navigateToTermsAndLicenses() async {
    await self.navigationToTermsAndLicenses.performCatching()
  }

  internal final func navigateToTroubleshooting() async {
    await navigationToTroubleshooting.performCatching()
  }

  internal final func signOut() async {
    await session.close(currentAccount)
  }
}
