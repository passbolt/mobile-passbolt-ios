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
import UICommons

internal struct MainSettingsView: ControlledView {

  private let controller: MainSettingsViewController
  @State private var signOutConfirmationPresented: Bool = false

  internal init(
    controller: MainSettingsViewController
  ) {
    self.controller = controller
  }

  internal var body: some View {
    ScreenView(
      title: "settings.main.title",
      contentView: {
        self.content
      }
    )
  }

  @ViewBuilder @MainActor private var content: some View {
    CommonPlainList {
      SettingsActionRowView(
        icon: .settings,
        title: "settings.main.item.application.title",
        navigation: self.controller.navigateToApplicationSettings
      )
      .accessibilityIdentifier("settings.main.item.application.title")

      SettingsActionRowView(
        icon: .people,
        title: "settings.main.item.accounts.title",
        navigation: self.controller.navigateToAccountsSettings
      )
      .accessibilityIdentifier("settings.main.item.accounts.title")

      SettingsActionRowView(
        icon: .info,
        title: "settings.main.item.terms.and.licenses.title",
        navigation: self.controller.navigateToTermsAndLicenses
      )
      .accessibilityIdentifier("settings.main.item.terms.and.licenses.title")

      SettingsActionRowView(
        icon: .bug,
        title: "settings.main.item.troubleshooting.title",
        navigation: self.controller.navigateToTroubleshooting
      )

      SettingsActionRowView(
        icon: .exit,
        title: "settings.main.item.sign.out.title",
        action: {
          self.signOutConfirmationPresented = true
        }
      )
      .accessibilityIdentifier("settings.main.item.sign.out.title")
      .alert(
        isPresented: self.$signOutConfirmationPresented,
        title: "settings.main.sign.out.alert.title",
        message: "settings.main.sign.out.alert.message",
        actions: {
          AsyncButton(
            role: .destructive,
            action: self.controller.signOut,
            regularLabel: {
              Text(displayable: "settings.main.sign.out.alert.confirm.title")
            }
          )
          .accessibilityIdentifier("settings.main.sign.out.alert.confirm.title")

          Button(
            displayable: .localized(key: .cancel),
            role: .cancel,
            action: { /* NOP */  }
          )
          .accessibilityIdentifier("settings.main.sign.out.alert.cancel.button")
        }
      )
    }
  }
}
