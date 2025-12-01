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
import CommonModels
import Commons
import Display
import FeatureScopes
import Session
import SessionData

// MARK: - Interface
// TODO: Merge with APP
internal struct HomePresentation {

  internal var currentMode: StoredVariable<HomePresentationMode>
  internal var setPresentationMode: @MainActor (HomePresentationMode) -> Void

  internal var availableModes: @Sendable () -> OrderedSet<HomePresentationMode>
}

extension HomePresentation: LoadableFeature {

  #if DEBUG
  internal nonisolated static var placeholder: Self {
    .init(
      currentMode: .placeholder,
      setPresentationMode: unimplemented1(),
      availableModes: unimplemented0()
    )
  }
  #endif
}

// MARK: - Implementation

extension HomePresentation {

  @MainActor fileprivate static func load(
    features: Features
  ) throws -> Self {
    let sessionConfiguration: SessionConfiguration = try features.sessionConfiguration()

    let accountPreferences: AccountPreferences = try features.instance()

    let useLastUsedHomePresentationAsDefault: StoredVariable<Bool> = accountPreferences
      .useLastHomePresentationAsDefault
    let defaultHomePresentation: StoredVariable<HomePresentationMode> = accountPreferences.defaultHomePresentation

    let availablePresentationModes: OrderedSet<HomePresentationMode> = {
      // order is preserved on display
      var availableModes: OrderedSet<HomePresentationMode> = [
        .plainResourcesList,
        .favoriteResourcesList,
        .modifiedResourcesList,
        .sharedResourcesList,
        .ownedResourcesList,
        .expiredResourcesList,
      ]

      if sessionConfiguration.folders.enabled {
        availableModes.append(.foldersExplorer)
      }  // else NOP

      if sessionConfiguration.tags.enabled {
        availableModes.append(.tagsExplorer)
      }  // else NOP

      availableModes.append(.resourceUserGroupsExplorer)

      return availableModes
    }()

    let initialPresentationMode: HomePresentationMode = {
      let defaultMode: HomePresentationMode = accountPreferences
        .defaultHomePresentation
        .value

      if availablePresentationModes.contains(defaultMode) {
        return defaultMode
      }
      else {
        return .plainResourcesList
      }
    }()

    // Create a StoredVariable that saves to preferences on changes
    let currentModeVariable = StoredVariable<HomePresentationMode>(
      fetch: { initialPresentationMode },
      store: { newMode in
        if useLastUsedHomePresentationAsDefault.value {
          defaultHomePresentation.assign(newMode)
        }
      }
    )

    @Sendable nonisolated func availableModes() -> OrderedSet<HomePresentationMode> {
      availablePresentationModes
    }

    @MainActor func setPresentationMode(_ mode: HomePresentationMode) {
      currentModeVariable.assign(mode)
      if useLastUsedHomePresentationAsDefault.value {
        defaultHomePresentation.assign(mode)
      }
      else { /* NOP */
      }
    }

    return Self(
      currentMode: currentModeVariable,
      setPresentationMode: setPresentationMode,
      availableModes: availableModes
    )
  }
}

extension FeaturesRegistry {

  public mutating func usePassboltHomePresentation() {
    self.use(
      .lazyLoaded(
        HomePresentation.self,
        load: HomePresentation.load(features:)
      ),
      in: SessionScope.self
    )
  }
}
