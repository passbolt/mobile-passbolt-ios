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
import UICommons
import UIComponents

internal final class HomeTabNavigationViewController: NavigationViewController, UIComponent {

  internal typealias Controller = HomeTabNavigationController

  internal static func instance(
    using controller: Controller,
    with components: UIComponentFactory,
    cancellables: Cancellables
  ) -> Self {
    Self(
      using: controller,
      with: components,
      cancellables: cancellables
    )
  }

  internal let components: UIComponentFactory
  private let controller: Controller

  internal init(
    using controller: Controller,
    with components: UIComponentFactory,
    cancellables: Cancellables
  ) {
    self.controller = controller
    self.components = components
    super.init(
      cancellables: cancellables
    )
  }

  internal func setup() {
    mut(tabBarItem) {
      .combined(
        .title(.localized(key: "tab.home")),
        .image(named: .homeTab, from: .uiCommons)
      )
    }
    setupSubscriptions()
  }

  private func setupSubscriptions() {
    self.controller
      .currentHomePresentationModePublisher()
      .sink { [weak self] mode in
        self?.cancellables.executeOnMainActor { [weak self] in
          guard let self = self else { return }
          switch mode {
          case .plainResourcesList:
            await self.replaceNavigationRoot(
              with: PlainResourcesListViewController.self,
              animated: false
            )

          case .favoriteResourcesList:
            await self.replaceNavigationRoot(
              with: FavoriteResourcesListViewController.self,
              animated: false
            )

          case .modifiedResourcesList:
            await self.replaceNavigationRoot(
              with: ModifiedResourcesListViewController.self,
              animated: false
            )

          case .sharedResourcesList:
            await self.replaceNavigationRoot(
              with: SharedResourcesListViewController.self,
              animated: false
            )

          case .ownedResourcesList:
            await self.replaceNavigationRoot(
              with: OwnedResourcesListViewController.self,
              animated: false
            )

          case .foldersExplorer:
            await self.replaceNavigationRoot(
              with: FoldersExplorerView.self,
              in: nil,  // root folder
              animated: false
            )

          case .tagsExplorer:
            await self.replaceNavigationRoot(
              with: TagsExplorerView.self,
              in: nil,  // tag list
              animated: false
            )

          case .resourceUserGroupsExplorer:
            await self.replaceNavigationRoot(
              with: ResourceUserGroupsExplorerView.self,
              in: nil,  // user group list
              animated: false
            )
          }
        }
      }
      .store(in: self.cancellables)
  }
}
