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
import OSFeatures
import Resources
import Session
import SessionData
import SharedUIComponents
import Users

internal final class ResourceUserGroupsListViewController: ViewController {

  internal nonisolated let viewState: ViewStateSource<ViewState>
  internal let searchController: ResourceSearchDisplayController
  // swift-format-ignore: NeverUseImplicitlyUnwrappedOptionals
  internal var contentController: ResourceUserGroupsListDisplayController!

  private let autofillContext: AutofillExtensionContext
  private let currentAccount: Account

  private let context: Context
  private let features: Features

  internal init(
    context: Context,
    features: Features
  ) throws {
    self.context = context
    self.features = features

    self.autofillContext = features.instance()
    self.currentAccount = try features.sessionAccount()
    let navigationToHomePresentationMenu: NavigationToHomePresentationMenu = try features.instance()

    let session: Session = try features.instance()

    self.viewState = .init(
      initial: .init(
        title: context.title,
        titleIconName: context.titleIconName
      )
    )

    self.searchController = try features.instance(
      context: .init(
        searchPrompt: context.searchPrompt,
        onPresentationMenuTap: {
          try await navigationToHomePresentationMenu.perform()
        },
        onAvatarTap: {
          await session.close(.none)
        }
      )
    )

    self.contentController = try features.instance(
      context: .init(
        filter: ComputedVariable(
          transformed: self.searchController
            .searchText
        ) { [currentAccount] update -> UserGroupsFilter in
          try .init(
            userID: currentAccount.userID,
            text: update.value
          )
        }
        .asAnyUpdatable(),
        selectGroup: { [weak self] in try await self?.selectUserGroup($0) }
      )
    )
  }
}

extension ResourceUserGroupsListViewController {

  internal struct Context {

    internal var title: DisplayableString = .localized(
      key: "home.presentation.mode.resource.user.groups.explorer.title"
    )
    internal var searchPrompt: DisplayableString = .localized(key: "resources.search.placeholder")
    internal var titleIconName: ImageNameConstant = .userGroup
  }

  internal struct ViewState: Equatable {

    internal var title: DisplayableString
    internal var titleIconName: ImageNameConstant
  }
}

extension ResourceUserGroupsListViewController {

  @Sendable internal nonisolated func selectUserGroup(
    _ userGroupID: UserGroup.ID
  ) async throws {
    let userGroup: UserGroupDetails = try await self.features
      .branch(
        scope: UserGroupScope.self,
        context: userGroupID
      )
      .instance()
    let userGroupDetails: UserGroupDetailsDSV = try await userGroup.details()
    let navigationToResourcesList: NavigationToResourcesList = try await features.instance()
    try await navigationToResourcesList.perform(
      context: .init(
        title: .raw(userGroupDetails.name),
        titleIconName: .userGroup,
        baseFilter: .init(
          sorting: .nameAlphabetically,
          userGroups: [userGroupID]
        ),
        appModeContext: .createExtensionContext(using: features, allowBack: true)
      )
    )
  }

  internal final func closeExtension() {
    self.autofillContext.cancelAndCloseExtension()
  }
}
