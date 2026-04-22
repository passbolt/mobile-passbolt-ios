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

internal struct MainTabsView: ControlledView {

  internal let controller: MainTabsViewController

  internal init(controller: MainTabsViewController) {
    self.controller = controller
  }

  internal var body: some View {
    TabView {
      Tab<HomeView>(
        title: "tab.home",
        iconName: .home,
        controllerProvider: self.controller.homeController
      )
      when(\.isOTPTabAvailable) {
        Tab<OTPResourcesListView>(
          title: "tab.otp",
          iconName: .otp,
          controllerProvider: self.controller.otpController
        )
      }
      Tab<MainSettingsView>(
        title: "tab.settings",
        iconName: .settings,
        controllerProvider: self.controller.settingsController
      )
    }
    .tint(.passboltPrimaryBlue)
    .task(self.controller.activate)
  }
}

private struct Tab<TabView: ControlledView>: View {

  private let title: DisplayableString
  private let iconName: ImageNameConstant
  private let controllerProvider: () -> TabView.Controller

  fileprivate init(
    title: DisplayableString,
    iconName: ImageNameConstant,
    controllerProvider: @autoclosure @escaping () -> TabView.Controller
  ) {
    self.title = title
    self.iconName = iconName
    self.controllerProvider = controllerProvider
  }

  fileprivate var body: some View {
    NavigationStack {
      TabView(controller: self.controllerProvider())
        .overlay(alignment: .bottom) {
          if #available(iOS 26, *) {
            // skip the overlay on iOS 26 and later as the new tab bar style doesn't require it
          }
          else {
            Rectangle()
              .frame(height: 10)
              .foregroundStyle(
                LinearGradient(
                  colors: [.black.opacity(0), .black.opacity(0.05)],
                  startPoint: .top,
                  endPoint: .bottom
                )
              )
          }
        }
    }
    .tabItem {
      TabItemView(
        title: title,
        iconName: iconName
      )
    }
  }
}

private struct TabItemView: View {

  private let title: DisplayableString
  private let iconName: ImageNameConstant

  fileprivate init(title: DisplayableString, iconName: ImageNameConstant) {
    self.title = title
    self.iconName = iconName
  }

  fileprivate var body: some View {
    Label(
      title: {
        Text(displayable: title)
      },
      icon: {
        Image(named: iconName)
      }
    )
  }
}
