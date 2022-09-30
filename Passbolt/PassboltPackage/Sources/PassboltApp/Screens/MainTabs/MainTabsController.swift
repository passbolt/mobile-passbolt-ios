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
import Features
import OSFeatures
import Session
import UIComponents

internal struct MainTabsController {

  internal var setActiveTab: @MainActor (MainTab) -> Void
  // temporary solution to avoid blinking after authorization
  internal var tabComponents: @MainActor () -> Array<AnyUIComponent>
  internal var activeTabPublisher: @MainActor () -> AnyPublisher<MainTab, Never>
  internal var initialModalPresentation: @MainActor () -> AnyPublisher<ModalPresentation?, Never>
}

extension MainTabsController {

  internal enum ModalPresentation {

    case biometricsInfo
    case biometricsSetup
    case autofillSetup
  }
}

extension MainTabsController: UIController {

  internal typealias Context = Void

  internal static func instance(
    in context: Context,
    with features: FeatureFactory,
    cancellables: Cancellables
  ) async throws -> Self {
    let currentAccount: Account = try await features.instance(of: Session.self).currentAccount()
    let accountInitialSetup: AccountInitialSetup = try await features.instance(context: currentAccount)
    let osBiometry: OSBiometry = features.instance()

    let activeTabSubject: CurrentValueSubject<MainTab, Never> = .init(.home)
    // temporary solution to avoid blinking after authorization
    // preload tabs so after presenting view all will be in place
    let tabs: Array<AnyUIComponent> = [
      try await UIComponentFactory(features: features).instance(of: HomeTabNavigationViewController.self),
      try await UIComponentFactory(features: features).instance(of: SettingsTabViewController.self),
    ]

    func setActiveTab(_ tab: MainTab) {
      activeTabSubject.send(tab)
    }

    func tabComponents() -> Array<AnyUIComponent> {
      tabs
    }

    func activeTabPublisher() -> AnyPublisher<MainTab, Never> {
      activeTabSubject.eraseToAnyPublisher()
    }

    func initialModalPresentation() -> AnyPublisher<ModalPresentation?, Never> {
      Future<ModalPresentation?, Never> { promise in
        Task {
          let unfinishedSetupElements: Set<AccountInitialSetup.SetupElement> =
            await accountInitialSetup.unfinishedSetupElements()

          if unfinishedSetupElements.contains(.biometrics) {
            switch osBiometry.availability() {
            case .unconfigured:
              promise(.success(.biometricsInfo))

            case .faceID, .touchID:
              promise(.success(.biometricsSetup))

            case .unavailable:
              promise(.success(.none))
            }
          }
          else if unfinishedSetupElements.contains(.autofill) {
            promise(.success(.autofillSetup))
          }
          else {
            promise(.success(.none))
          }
        }
      }
      .eraseToAnyPublisher()
    }

    return Self(
      setActiveTab: setActiveTab,
      tabComponents: tabComponents,
      activeTabPublisher: activeTabPublisher,
      initialModalPresentation: initialModalPresentation
    )
  }
}
