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
import FeatureScopes
import Session
import SessionData

public struct HomePresentation {

  public var currentPresentationModeUpdatable: @MainActor () -> AnyUpdatable<HomePresentationMode>
  public var setPresentationMode: @MainActor (HomePresentationMode) -> Void
  public var availableHomePresentationModes: @MainActor () -> OrderedSet<HomePresentationMode>
}

extension HomePresentation: LoadableFeature {

  @MainActor public static func load(
    using features: Features
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
        // fallback to default mode if the stored one is not available
        return .plainResourcesList
      }
    }()
    let currentPresentationModeVariable: Variable<HomePresentationMode> =
      .init(initial: initialPresentationMode)

    @MainActor func setPresentationMode(_ mode: HomePresentationMode) {
      currentPresentationModeVariable.assign(mode)
      if useLastUsedHomePresentationAsDefault.value {
        defaultHomePresentation.assign(mode)
      }
      else { /* NOP */
      }
    }

    @MainActor func availableHomePresentationModes() -> OrderedSet<HomePresentationMode> {
      availablePresentationModes
    }

    return Self(
      currentPresentationModeUpdatable: { currentPresentationModeVariable.asAnyUpdatable() },
      setPresentationMode: setPresentationMode(_:),
      availableHomePresentationModes: availableHomePresentationModes
    )
  }
}

#if DEBUG
extension HomePresentation {

  public static var placeholder: Self {
    Self(
      currentPresentationModeUpdatable: unimplemented0(),
      setPresentationMode: unimplemented1(),
      availableHomePresentationModes: unimplemented0()
    )
  }
}
#endif

extension FeaturesRegistry {

  internal mutating func useHomePresentation() {
    self.use(
      .lazyLoaded(
        HomePresentation.self,
        load: { try HomePresentation.load(using: $0) }
      ),
      in: SessionScope.self
    )
  }
}
