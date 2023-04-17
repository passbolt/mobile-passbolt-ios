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
import DatabaseOperations
import Features
import OSFeatures
import Session
import SessionData
import UIComponents

internal struct MainTabsController {

  internal var setActiveTab: @MainActor (MainTab) -> Void
  internal var activeTabPublisher: @MainActor () -> AnyPublisher<MainTab, Never>
  internal var initialModalPresentation: @MainActor () -> AnyPublisher<ModalPresentation?, Never>
  internal var otpTabAvailable: () async -> Bool
}

extension MainTabsController {

  internal enum ModalPresentation {

    case biometricsInfo
    case biometricsSetup
    case autofillSetup
  }
}

extension MainTabsController: UIController {

  internal typealias Context = SessionScope.Context

  internal static func instance(
    in context: Context,
    with features: inout Features,
    cancellables: Cancellables
  ) throws -> Self {
    features =
      features
      .branch(
        scope: SessionScope.self,
        context: context
      )
    let features: Features = features
    let currentAccount: Account = try features.sessionAccount()

    let accountInitialSetup: AccountInitialSetup = try features.instance(context: currentAccount)
    let osBiometry: OSBiometry = features.instance()
    let sessionData: SessionData = try features.instance()
    let resourceTypesFetchDatabaseOperation: ResourceTypesFetchDatabaseOperation = try features.instance()

    let activeTabSubject: CurrentValueSubject<MainTab, Never> = .init(.home)

    func setActiveTab(_ tab: MainTab) {
      activeTabSubject.send(tab)
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

    func otpTabAvailable() async -> Bool {
      do {
        try await sessionData.refreshIfNeeded()
        let availableResourceTypes: Array<ResourceType> = try await resourceTypesFetchDatabaseOperation()
        return
          availableResourceTypes
          .contains(where: { $0.slug == .totp || $0.slug == .hotp })
      }
      catch {
        return false
      }
    }

    return Self(
      setActiveTab: setActiveTab,
      activeTabPublisher: activeTabPublisher,
      initialModalPresentation: initialModalPresentation,
      otpTabAvailable: otpTabAvailable
    )
  }
}
