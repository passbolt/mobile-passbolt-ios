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
import Session
import SessionData

internal struct HomePresentation {

  internal var currentPresentationModePublisher: @MainActor () -> AnyPublisher<HomePresentationMode, Never>
  internal var setPresentationMode: @MainActor (HomePresentationMode) -> Void
  internal var availableHomePresentationModes: @MainActor () -> OrderedSet<HomePresentationMode>
}

extension HomePresentation: LoadableFeature {
  
  public typealias Context = ContextlessLoadableFeatureContext

  @MainActor internal static func load(
    using features: Features,
    cancellables: Cancellables
  ) throws -> Self {
    let currentAccount: Account = try features.sessionAccount()
    let sessionConfiguration: SessionConfiguration = try features.sessionConfiguration()

    let accountPreferences: AccountPreferences = try features.instance(context: currentAccount)

    var useLastUsedHomePresentationAsDefault: StateBinding<Bool> = accountPreferences
      .useLastHomePresentationAsDefault
    var defaultHomePresentation: StateBinding<HomePresentationMode> = accountPreferences.defaultHomePresentation

    let availablePresentationModes: OrderedSet<HomePresentationMode> = {
      // order is preserved on display
      var availableModes: OrderedSet<HomePresentationMode> = [
        .plainResourcesList,
        .favoriteResourcesList,
        .modifiedResourcesList,
        .sharedResourcesList,
        .ownedResourcesList,
      ]

      if sessionConfiguration.foldersEnabled {
        availableModes.append(.foldersExplorer)
      }  // else NOP

      if sessionConfiguration.tagsEnabled {
        availableModes.append(.tagsExplorer)
      }  // else NOP

      availableModes.append(.resourceUserGroupsExplorer)

      return availableModes
    }()

    let initialPresentationMode: HomePresentationMode = {
      let defaultMode: HomePresentationMode = accountPreferences
        .defaultHomePresentation
        .get(\.self)
      if availablePresentationModes.contains(defaultMode) {
        return defaultMode
      }
      else {
        return .plainResourcesList
      }
    }()

    let currentPresentationModeSubject: CurrentValueSubject<HomePresentationMode, Never> =
      .init(
        initialPresentationMode
      )

    @MainActor func currentPresentationModePublisher() -> AnyPublisher<HomePresentationMode, Never> {
      currentPresentationModeSubject
        .removeDuplicates()
        .eraseToAnyPublisher()
    }

    @MainActor func setPresentationMode(_ mode: HomePresentationMode) {
      currentPresentationModeSubject.send(mode)
      if useLastUsedHomePresentationAsDefault.get() {
        defaultHomePresentation.set(to: mode)
      }
      else { /* NOP */
      }
    }

    @MainActor func availableHomePresentationModes() -> OrderedSet<HomePresentationMode> {
      return availablePresentationModes
    }

    return Self(
      currentPresentationModePublisher: currentPresentationModePublisher,
      setPresentationMode: setPresentationMode(_:),
      availableHomePresentationModes: availableHomePresentationModes
    )
  }
}

extension HomePresentation {

  internal var featureUnload: @MainActor () async throws -> Void { {} }
}

#if DEBUG
extension HomePresentation {

  static var placeholder: Self {
    Self(
      currentPresentationModePublisher: unimplemented0(),
      setPresentationMode: unimplemented1(),
      availableHomePresentationModes: unimplemented0()
    )
  }
}
#endif

extension FeaturesRegistry {

  public mutating func usePassboltHomePresentation() {
    self.use(
      .lazyLoaded(
        HomePresentation.self,
        load: HomePresentation.load(using:cancellables:)
      ),
      in: SessionScope.self
    )
  }
}
