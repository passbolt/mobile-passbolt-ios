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

  private let controller: ApplicationSettingsController
  @State private var disableBiometricsConfirmationPresented: Bool = false

  internal init(
    controller: ApplicationSettingsController
  ) {
    self.controller = controller
  }

  internal var body: some View {
    ScreenView(
      title: .localized(
        key: "settings.application.title"
      ),
      contentView: {
        self.content
      }
    )
    .task(self.controller.activate)
  }

  @ViewBuilder @MainActor private var content: some View {
    CommonList {
      WithViewState(
        from: self.controller,
        at: \.biometicsAuthorizationAvailability
      ) { availablility in
        SettingsItemRowView(
          icon: availablility.iconName,
          title: availablility.title,
          accessory: {
            Toggle(
              isOn: .init(
                get: { availablility.enabled },
                set: { (newValue: Bool) in
                  if newValue {
                    self.controller.setBiometricsAuthorizationEnabled(true)
                  }
                  else {
                    self.disableBiometricsConfirmationPresented = true
                  }
                }
              ),
              label: EmptyView.init
            )
            .accessibilityIdentifier("settings.application.biometrics.disabled.toggle")
          }
        )
        .alert(
          isPresented: self.$disableBiometricsConfirmationPresented,
          title: .localized(
            key: "settings.application.biometrics.disable.alert.title"
          ),
          message: .localized(
            key: "settings.application.biometrics.disable.alert.message",
            arguments: [availablility.title.string()]
          ),
          actions: {
            Button(
              displayable: .localized(
                key: .confirm
              ),
              role: .destructive,
              action: {
                self.controller.setBiometricsAuthorizationEnabled(false)
              }
            )
            Button(
              displayable: .localized(
                key: .cancel
              ),
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
        action: self.controller.navigateToAutofillSettings,
        accessory: {
          Image(named: .disclosureIndicator)
            .frame(
              width: 24,
              height: 24
            )
            .accessibilityIdentifier("settings.application.item.autofill.disclosure.indicator")
        }
      )
      .accessibilityIdentifier("settings.application.item.autofill.title")

      SettingsActionRowView(
        icon: .filter,
        title: .localized(
          key: "settings.application.item.default.mode.title"
        ),
        action: self.controller.navigateToDefaultPresentationModeSettings,
        accessory: {
          Image(named: .disclosureIndicator)
            .frame(
              width: 24,
              height: 24
            )
            .accessibilityIdentifier("settings.application.item.filter.disclosure.indicator")
        }
      )
      .accessibilityIdentifier("settings.application.item.default.mode.title")
    }
  }
}
