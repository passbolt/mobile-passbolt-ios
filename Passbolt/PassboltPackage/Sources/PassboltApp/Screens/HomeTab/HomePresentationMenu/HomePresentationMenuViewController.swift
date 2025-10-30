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
import FeatureScopes
import SharedUIComponents

internal final class HomePresentationMenuViewController: ViewController {

  internal struct ViewState: Equatable {

    internal var currentMode: HomePresentationMode
    internal var availableModes: Array<ModeGroup>
  }

  internal nonisolated let viewState: ViewStateSource<ViewState>
  private let context: Context

  fileprivate let navigationToSelf: NavigationToHomePresentationMenu
  fileprivate let homePresentation: HomePresentation

  internal init(
    context: Context,
    features: Features
  ) throws {
    self.context = context
    self.navigationToSelf = try features.instance()
    self.homePresentation = try features.instance()

    self.viewState = .init(
      initial: .init(
        currentMode: .plainResourcesList,
        availableModes: .init()
      ),
      updateFrom: homePresentation.currentPresentationModeUpdatable(),
      update: { [homePresentation] (updateState, update: Update<HomePresentationMode>) in
        updateState { (state: inout ViewState) in
          do {
            state.currentMode = try update.value
            state.availableModes = homePresentation.availableHomePresentationModes().grouped()
          }
          catch {
            error.consume(context: "Failed to get presentation mode value.")
          }
        }
      }
    )
  }
}

extension HomePresentationMenuViewController {

  internal func dismiss() async {
    await self.navigationToSelf.revertCatching()
  }

  internal func selectMode(
    _ mode: HomePresentationMode
  ) async {
    homePresentation.setPresentationMode(mode)
    await navigationToSelf.revertCatching()
  }
}

extension OrderedSet where Element == HomePresentationMode {

  fileprivate func grouped() -> Array<ModeGroup> {
    var resourcesGroupItems: OrderedSet<HomePresentationMode> = .init()
    var otherGroupItems: OrderedSet<HomePresentationMode> = .init()

    for item in self {
      switch item {
      case .plainResourcesList,
        .favoriteResourcesList,
        .modifiedResourcesList,
        .sharedResourcesList,
        .ownedResourcesList,
        .expiredResourcesList:
        resourcesGroupItems.append(item)
      case .foldersExplorer,
        .tagsExplorer,
        .resourceUserGroupsExplorer:
        otherGroupItems.append(item)
      }
    }

    return [
      ModeGroup(items: resourcesGroupItems),
      ModeGroup(items: otherGroupItems),
    ]
    .filter { !$0.isEmpty }
  }
}

internal struct ModeGroup: Equatable {

  internal var items: OrderedSet<HomePresentationMode>

  internal var isEmpty: Bool {
    self.items.isEmpty
  }
}
