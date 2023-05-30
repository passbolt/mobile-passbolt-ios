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
import OSFeatures
import Resources
import Session
import SessionData
import SharedUIComponents
import Users

internal final class ResourceUserGroupsListNodeController: ViewController {

  internal nonisolated let viewState: MutableViewState<ViewState>
  internal var searchController: ResourceSearchDisplayController
  internal var contentController: ResourceUserGroupsListDisplayController!  // lazy?

  private let diagnostics: OSDiagnostics
  private let asyncExecutor: AsyncExecutor
  private let navigationTree: NavigationTree
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

    self.diagnostics = features.instance()
    self.asyncExecutor = try features.instance()
    self.navigationTree = features.instance()
    self.autofillContext = features.instance()
    self.currentAccount = try features.sessionAccount()

    self.viewState = .init(
      initial: .init(
        title: context.title,
        titleIconName: context.titleIconName,
        snackBarMessage: .none
      )
    )

    self.searchController = try features.instance(
      context: .init(
        searchPrompt: context.searchPrompt,
        showMessage: { [viewState] (message: SnackBarMessage?) in
          viewState.update { viewState in
            viewState.snackBarMessage = message
          }
        }
      )
    )

    self.contentController = try features.instance(
      context: .init(
        filter: self.searchController
          .searchText
          .map { (text: String) -> UserGroupsFilter in
            .init(
              userID: self.currentAccount.userID,
              text: text
            )
          },
        selectGroup: self.selectUserGroup(_:),
        showMessage: { [viewState] (message: SnackBarMessage?) in
          viewState.update { viewState in
            viewState.snackBarMessage = message
          }
        }
      )
    )
  }
}

extension ResourceUserGroupsListNodeController {

  internal struct Context {

    internal var title: DisplayableString = .localized(
      key: "home.presentation.mode.resource.user.groups.explorer.title"
    )
    internal var searchPrompt: DisplayableString = .localized(key: "resources.search.placeholder")
    internal var titleIconName: ImageNameConstant = .userGroup
  }

  internal struct ViewState: Hashable {

    internal var title: DisplayableString
    internal var titleIconName: ImageNameConstant
    internal var snackBarMessage: SnackBarMessage?
  }
}

extension ResourceUserGroupsListNodeController {

  @Sendable internal nonisolated func selectUserGroup(
    _ userGroupID: UserGroup.ID
  ) {
    self.asyncExecutor.scheduleCatchingWith(
      self.diagnostics,
      failMessage: "Failed to handle user group selection.",
      failAction: { [viewState] (error: Error) in
        await viewState.update(\.snackBarMessage, to: .error(error))
      },
      behavior: .replace
    ) { [features, navigationTree] in
      let userGroup: UserGroupDetails = try await features.instance(context: userGroupID)
      let userGroupDetails: UserGroupDetailsDSV = try await userGroup.details()

      let nodeController: ResourcesListNodeController =
        try await features
        .instance(
          of: ResourcesListNodeController.self,
          context: .init(
            title: .raw(userGroupDetails.name),
            titleIconName: .userGroup,
            baseFilter: .init(
              sorting: .nameAlphabetically,
              userGroups: [userGroupID]
            )
          )
        )

      await navigationTree
        .push(
          ResourcesListNodeView.self,
          controller: nodeController
        )
    }
  }

  internal final func closeExtension() {
    self.asyncExecutor.schedule(.reuse) { [autofillContext] in
      await autofillContext.cancelAndCloseExtension()
    }
  }
}
