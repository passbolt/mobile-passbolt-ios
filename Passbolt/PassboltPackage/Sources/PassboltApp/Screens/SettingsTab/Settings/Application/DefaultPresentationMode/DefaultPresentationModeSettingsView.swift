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

internal struct DefaultPresentationModeSettingsView: ControlledView {

  private let controller: DefaultPresentationModeSettingsController

  internal init(
    controller: DefaultPresentationModeSettingsController
  ) {
    self.controller = controller
  }

  internal var body: some View {
    ScreenView(
      titleIcon: .filter,
      title: .localized(
        key: "settings.application.default.mode.title"
      ),
      contentView: {
        WithViewState(from: self.controller) { (state) in
          List {
            ListRowView(
              title: .localized(
                key: "settings.application.default.mode.option.last.used.title"
              ),
              leftAccessory: {
                Image(named: .filter)
                  .frame(width: 20, height: 20)
                  .padding(4)
              },
              contentAction: {
                self.controller.selectMode(.none)
              },
              rightAccessory: {
                Image(
                  named: state.selectedMode == .none
                    ? .circleSelected
                    : .circleUnselected
                )
                .frame(width: 20, height: 20)
                .padding(4)
                .foregroundColor(
                  state.selectedMode == .none
                    ? .passboltPrimaryBlue
                    : .passboltIcon
                )
              }
            )
            ForEach(state.availableModes) { mode in
              ListRowView(
                title: mode.title,
                leftAccessory: {
                  Image(named: mode.iconName)
                    .frame(width: 20, height: 20)
                    .padding(4)
                },
                contentAction: {
                  self.controller.selectMode(mode)
                },
                rightAccessory: {
                  Image(
                    named: state.selectedMode == mode
                      ? .circleSelected
                      : .circleUnselected
                  )
                  .frame(width: 20, height: 20)
                  .padding(4)
                  .foregroundColor(
                    state.selectedMode == mode
                      ? .passboltPrimaryBlue
                      : .passboltIcon
                  )
                }
              )
            }
          }
          .listStyle(.plain)
        }
      }
    )
  }
}
