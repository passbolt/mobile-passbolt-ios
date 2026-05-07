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
  @State private var selectedTab: TabIdentifier = .home

  internal init(controller: MainTabsViewController) {
    self.controller = controller
  }

  internal var body: some View {
    TabView(selection: $selectedTab) {
      Tab<HomeView>(
        title: "tab.home",
        iconName: .home,
        tabID: .home,
        selectedTab: $selectedTab,
        navigationStateRegistry: controller.navigationStateRegistry,
        rootNavigationState: controller.rootNavigationState,
        controllerProvider: self.controller.homeController
      )
      when(\.isOTPTabAvailable) {
        Tab<OTPResourcesListView>(
          title: "tab.otp",
          iconName: .otp,
          tabID: .otp,
          selectedTab: $selectedTab,
          navigationStateRegistry: controller.navigationStateRegistry,
          rootNavigationState: controller.rootNavigationState,
          controllerProvider: self.controller.otpController
        )
      }
      Tab<MainSettingsView>(
        title: "tab.settings",
        iconName: .settings,
        tabID: .settings,
        selectedTab: $selectedTab,
        navigationStateRegistry: controller.navigationStateRegistry,
        rootNavigationState: controller.rootNavigationState,
        controllerProvider: self.controller.settingsController
      )
    }
    .tint(.passboltPrimaryBlue)
    .task(self.controller.activate)
  }
}

private enum TabIdentifier: Hashable {
  case home
  case otp
  case settings
}

private struct Tab<TabView: ControlledView>: View {

  private let title: DisplayableString
  private let iconName: ImageNameConstant
  private let tabID: TabIdentifier
  @Binding private var selectedTab: TabIdentifier
  private let navigationStateRegistry: NavigationStateRegistry
  private let controllerProvider: () -> TabView.Controller
  @StateObject private var navigationState = NavigationState()
  @ObservedObject private var rootState: RootNavigationState

  fileprivate init(
    title: DisplayableString,
    iconName: ImageNameConstant,
    tabID: TabIdentifier,
    selectedTab: Binding<TabIdentifier>,
    navigationStateRegistry: NavigationStateRegistry,
    rootNavigationState: RootNavigationState,
    controllerProvider: @autoclosure @escaping () -> TabView.Controller
  ) {
    self.title = title
    self.iconName = iconName
    self.tabID = tabID
    self._selectedTab = selectedTab
    self.navigationStateRegistry = navigationStateRegistry
    self.rootState = rootNavigationState
    self.controllerProvider = controllerProvider
  }

  fileprivate var body: some View {
    NavigationContainer(navigationState: navigationState) {
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
    .tag(tabID)
    .tabItem {
      TabItemView(
        title: title,
        iconName: iconName
      )
    }
    .onAppear {
      // Only set active if this tab is currently selected
      if selectedTab == tabID {
        navigationStateRegistry.setActive(navigationState)
      }
    }
    .onChange(of: selectedTab) { newTab in
      if newTab == tabID {
        navigationStateRegistry.setActive(navigationState)
      }
    }
    .onChange(of: rootState.reactivationSignal) { _ in
      // Re-activate navigation state after root restoration
      if selectedTab == tabID {
        navigationStateRegistry.setActive(navigationState)
      }
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
