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

internal struct ApplicationSettingsView: ControlledView {

  internal let controller: ApplicationSettingsViewController
  @State private var disableBiometricsConfirmationPresented: Bool = false

  internal init(
    controller: ApplicationSettingsViewController
  ) {
    self.controller = controller
  }

  internal var body: some View {
    ScreenView(
      title: "settings.application.title",
      contentView: {
				self.content
      }
    )
  }

  @ViewBuilder @MainActor private var content: some View {
    CommonPlainList {
      WithViewState(
        from: self.controller,
        at: \.biometicsAuthorizationAvailability
      ) { availablility in
        SettingsItemRowView(
          icon: availablility.iconName,
          title: availablility.title,
          accessory: {
            AsyncToggle(
              state: availablility.enabled,
              toggle: { (newValue: Bool) in
                if newValue {
                  await self.controller.setBiometricsAuthorization(enabled: true)
                }
                else {
                  self.disableBiometricsConfirmationPresented = true
                }
              }
            )
            .enabled(availablility.available)
            .accessibilityIdentifier("settings.application.biometrics.disabled.toggle")
          }
        )
        .alert(
          isPresented: self.$disableBiometricsConfirmationPresented,
          title: "settings.application.biometrics.disable.alert.title",
          message: .localized(
            key: "settings.application.biometrics.disable.alert.message",
            arguments: [availablility.title.string()]
          ),
          actions: {
            AsyncButton(
              role: .destructive,
              action: {
                await self.controller.setBiometricsAuthorization(enabled: false)
              },
              regularLabel: {
                Text(displayable: .localized(key: .confirm))
              }
            )
            Button(
              displayable: .localized(key: .cancel),
              role: .cancel,
              action: { /* NOP */  }
            )
          }
        )
      }

      SettingsActionRowView(
        icon: .key,
        title: .localized(
          key: "settings.application.item.autofill.title"
        ),
        navigation: self.controller.navigateToAutofillSettings
      )
      .accessibilityIdentifier("settings.application.item.autofill.title")

      SettingsActionRowView(
        icon: .filter,
        title: "settings.application.item.default.mode.title",
        navigation: self.controller.navigateToDefaultPresentationModeSettings
      )
      .accessibilityIdentifier("settings.application.item.default.mode.title")
    }
  }
}
