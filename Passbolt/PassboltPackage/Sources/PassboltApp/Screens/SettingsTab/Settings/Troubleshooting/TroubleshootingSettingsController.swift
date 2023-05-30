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

internal final class TroubleshootingSettingsController: ViewController {

  private let diagnostics: OSDiagnostics
  private let linkOpener: OSLinkOpener
  private let asyncExecutor: AsyncExecutor
  private let navigationToLogs: NavigationToLogs

  internal init(
    context: Void,
    features: Features
  ) throws {
    try features.ensureScope(SettingsScope.self)
    try features.ensureScope(SessionScope.self)

    self.diagnostics = features.instance()
    self.linkOpener = features.instance()
    self.asyncExecutor = try features.instance()
    self.navigationToLogs = try features.instance()
  }
}

extension TroubleshootingSettingsController {

  internal final func navigateToLogs() {
    self.asyncExecutor
      .scheduleCatchingWith(
        self.diagnostics,
        failMessage: "Navigation to logs failed!",
        behavior: .reuse
      ) { [navigationToLogs] in
        try await navigationToLogs.perform()
      }
  }

  internal final func navigateToHelpSite() {
    self.asyncExecutor
      .scheduleCatchingWith(
        self.diagnostics,
        failMessage: "Navigation to help site failed!",
        behavior: .reuse
      ) { [linkOpener] in
        try await linkOpener.openURL("https://help.passbolt.com/")
      }
  }
}
