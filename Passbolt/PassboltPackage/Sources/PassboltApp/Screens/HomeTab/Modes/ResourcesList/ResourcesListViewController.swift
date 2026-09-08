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
import SessionData
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
            let resourceCreatePreparation: ResourceCreatePreparation = try await features.instance()
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
              try await features
              .branchIfNeeded(
                scope: ResourceScope.self,
                context: resourceID
              )

            let navigationToResourceContextualMenu: NavigationToResourceContextualMenu = try await features.instance()
            try await navigationToResourceContextualMenu.perform(
              context: .init()
            )
          },
          backAction: .none
        )
      ),
      features: features
    )
  }
}

#if DEBUG

extension ResourcesListViewController {

  internal static func previewDependencies(_ features: inout PreviewFeaturesContainer) {
    features.set(
      SessionScope.self,
      context: .init(
        account: .ada,
        configuration: .default
      )
    )
    features.patch(
      \AccountDetails.avatarImage,
      with: { nil }
    )
    features.patch(
      \SessionData.refreshProgress,
      with: Constant(Optional<Double>.none).asAnyUpdatable()
    )
    features.patch(
      \SessionData.lastUpdate,
      with: Constant(Timestamp(rawValue: 0)).asAnyUpdatable()
    )
    features.patch(
      \ResourcesController.filteredResourcesList,
      with: { _ in
        [
          ResourceListItemDSV(
            id: .init(),
            type: .init(id: .init(), slug: .passwordWithDescription),
            permission: .owner,
            parentFolderID: nil,
            name: "Password",
            username: "ada@passbolt.com",
            url: "https://example.com",
            icon: .none
          ),
          ResourceListItemDSV(
            id: .init(),
            type: .init(id: .init(), slug: .passwordWithDescription),
            permission: .read,
            parentFolderID: nil,
            name: "Communicator",
            username: "ada@passbolt.com",
            url: "https://im.passbolt.com",
            icon: .init(type: .none, value: "20", backgroundColor: "#FFAABB")
          ),
          ResourceListItemDSV(
            id: .init(),
            type: .init(id: .init(), slug: .passwordWithDescription),
            permission: .write,
            parentFolderID: nil,
            name: "Settings",
            username: .none,
            url: nil,
            isExpired: true,
            icon: .init(type: .none, value: "40", backgroundColor: "#BBAADD")
          ),
          ResourceListItemDSV(
            id: .init(),
            type: .init(id: .init(), slug: .v5CustomFields),
            permission: .write,
            parentFolderID: nil,
            name: "Custom fields",
            username: .none,
            url: nil,
            isExpired: false,
            icon: .none
          ),
          ResourceListItemDSV(
            id: .init(),
            type: .init(id: .init(), slug: .v5StandaloneNote),
            permission: .write,
            parentFolderID: nil,
            name: "Note",
            username: .none,
            url: nil,
            isExpired: false,
            icon: .none
          ),
          ResourceListItemDSV(
            id: .init(),
            type: .init(id: .init(), slug: .v5PinCode),
            permission: .write,
            parentFolderID: nil,
            name: "Custom fields",
            username: .none,
            url: nil,
            isExpired: false,
            icon: .none
          ),
        ]
      }
    )
  }
}
#endif
