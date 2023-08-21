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

internal final class TroubleshootingSettingsViewController: ViewController {

  internal let viewState: ViewStateSource<SnackBarMessage?>
  private let linkOpener: OSLinkOpener
  private let navigationToLogs: NavigationToLogs

  internal init(
    context: Void,
    features: Features
  ) throws {
    try features.ensureScope(SettingsScope.self)
    try features.ensureScope(SessionScope.self)

    self.linkOpener = features.instance()
    self.navigationToLogs = try features.instance()
    self.viewState = .init(initial: .none)
  }
}

extension TroubleshootingSettingsViewController {

  internal final func navigateToLogs() async {
    await self.navigationToLogs.performCatching()
  }

  internal final func navigateToHelpSite() async {
    await withLogCatch(
      failInfo: "Failed to open help site!",
      fallback: { [viewState] (error: Error) async in
        viewState.update(\.self, to: .error(error))
      }
    ) {
      try await self.linkOpener.openURL("https://help.passbolt.com/")
    }
  }
}