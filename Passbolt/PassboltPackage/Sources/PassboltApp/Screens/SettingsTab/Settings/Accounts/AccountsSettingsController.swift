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

internal struct AccountsSettingsController {

  @Stateless internal var viewState

  internal var navigateToManageAccounts: () -> Void
  internal var navigateToAccountExport: () -> Void
}

extension AccountsSettingsController: ViewController {

  #if DEBUG
  internal static var placeholder: Self {
    .init(
      navigateToManageAccounts: unimplemented0(),
      navigateToAccountExport: unimplemented0()
    )
  }
  #endif
}

// MARK: - Implementation

extension AccountsSettingsController {

  @MainActor fileprivate static func load(
    features: Features
  ) throws -> Self {
    try features.ensureScope(SettingsScope.self)
    try features.ensureScope(SessionScope.self)

    let diagnostics: OSDiagnostics = features.instance()
    let asyncExecutor: AsyncExecutor = try features.instance()

    let navigationToManageAccounts: NavigationToManageAccounts = try features.instance()
    let navigationToAccountExport: NavigationToAccountExport = try features.instance()

    nonisolated func navigateToManageAccounts() {
      asyncExecutor.schedule(.reuse) {
        do {
          try await navigationToManageAccounts.perform()
        }
        catch {
          diagnostics
            .log(
              error:
                error
                .asTheError()
                .pushing(
                  .message("Navigation to manage accounts failed!")
                )
            )
        }
      }
    }

    nonisolated func navigateToAccountExport() {
      asyncExecutor.schedule(.reuse) {
        do {
          try await navigationToAccountExport.perform()
        }
        catch {
          diagnostics
            .log(
              error:
                error
                .asTheError()
                .pushing(
                  .message("Navigation to account export failed!")
                )
            )
        }
      }
    }

    return .init(
      navigateToManageAccounts: navigateToManageAccounts,
      navigateToAccountExport: navigateToAccountExport
    )
  }
}

extension FeaturesRegistry {

  internal mutating func useLiveAccountsSettingsController() {
    self.use(
      .disposable(
        AccountsSettingsController.self,
        load: AccountsSettingsController.load(features:)
      ),
      in: SettingsScope.self
    )
  }
}
