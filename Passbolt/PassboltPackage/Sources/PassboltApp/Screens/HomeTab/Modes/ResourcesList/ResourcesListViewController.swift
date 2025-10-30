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
import Display
import Resources
import SharedUIComponents

internal final class ResourcesListViewController: ViewController {

  internal let resourcesListViewController: SharedUIComponents.ResourcesListViewController

  internal struct Context {

    internal let mode: HomePresentationMode
  }

  internal init(context: Context, features: Features) throws {
    let navigationToResourceContextualMenu: NavigationToResourceCreateMenu = try features.instance()
    let navigationToResourceDetails: NavigationToResourceDetails = try features.instance()
    let navigationToAccountMenu: NavigationToAccountMenu = try features.instance()
    let navigationToHomePresentation: NavigationToHomePresentationMenu = try features.instance()

    resourcesListViewController = try .init(
      context: .init(
        title: context.mode.title,
        titleIconName: context.mode.iconName,
        baseFilter: context.mode.baseFilter,
        appModeContext: .init(
          onPresentationMenuTap: {
            try await navigationToHomePresentation.perform()
          },
          onAvatarTap: {
            try await navigationToAccountMenu.perform()
          },
          createResource: {
            let resourceCreatePreparation: ResourceCreatePreparation = try features.instance()
            let context: ResourceCreatingContext = try await resourceCreatePreparation.prepare()

            try await navigationToResourceContextualMenu
              .perform(
                context: .init(
                  resourceCreatingContext: context,
                  folderID: .none,
                  allowFolderCreation: false
                )
              )
          },
          selectResource: { resourceId in
            try await navigationToResourceDetails.perform(context: resourceId)
          },
          contextualMenuAction: { resourceID in
            let features: Features =
              try features
              .branchIfNeeded(
                scope: ResourceScope.self,
                context: resourceID
              )

            let navigationToResourceContextualMenu: NavigationToResourceContextualMenu = try features.instance()
            try await navigationToResourceContextualMenu.perform(
              context: .init()
            )
          }
        )
      ),
      features: features
    )
  }
}
