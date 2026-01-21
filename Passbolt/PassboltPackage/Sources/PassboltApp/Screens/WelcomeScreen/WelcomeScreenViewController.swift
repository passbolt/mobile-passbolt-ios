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
import SharedUIComponents

internal final class WelcomeScreenViewController: ViewController {

  internal struct ViewState: Equatable {
    internal var alert: AlertViewModel? = .none
  }

  internal nonisolated let viewState: ViewStateSource<ViewState>

  private let navigationToHelpMenu: NavigationToHelpMenu
  private let navigationToAccountImportInfo: NavigationToAccountImportInfo

  internal init(context: Void, features: Features) throws {
    self.navigationToHelpMenu = try features.instance()
    self.navigationToAccountImportInfo = try features.instance()
    self.viewState = .init(initial: .init())
  }

  internal func openHelpMenu() async {
    await consumingErrors {
      try await navigationToHelpMenu.perform(context: .init())
    }
  }

  internal func showNoAccountAlert() {
    self.viewState.update(\.alert, to: .noAccountAlert())
  }

  internal func goToScanning() async {
    await consumingErrors {
      try await navigationToAccountImportInfo.perform()
    }
  }
}

extension AlertViewModel {

  fileprivate static func noAccountAlert() -> AlertViewModel {
    .init(
      title: "welcome.no.account.alert.title",
      message: "welcome.no.account.alert.text",
      actions: [
        .regular(
          id: .init(),
          title: .localized(key: .gotIt),
          perform: {
            /** no-op */
          }
        )
      ]
    )
  }
}
