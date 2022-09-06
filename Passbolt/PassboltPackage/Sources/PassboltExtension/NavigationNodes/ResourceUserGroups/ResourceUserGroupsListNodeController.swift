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
import Resources
import Session
import SessionData
import SharedUIComponents
import Users

internal struct ResourceUserGroupsListNodeController {

  internal var viewState: DisplayViewState<ViewState>
  internal var searchController: ResourceSearchDisplayController
  internal var contentController: ResourceUserGroupsListDisplayController
  internal var closeExtension: () -> Void
}

extension ResourceUserGroupsListNodeController: NavigationNodeController {

  internal struct Context: LoadableFeatureContext {
    // feature is disposable, we don't care about ID
    internal let identifier: AnyHashable = IID()

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

  #if DEBUG
  nonisolated static var placeholder: Self {
    .init(
      viewState: .placeholder,
      searchController: .placeholder,
      contentController: .placeholder,
      closeExtension: unimplemented()
    )
  }
  #endif
}

extension ResourceUserGroupsListNodeController {

  @MainActor fileprivate static func load(
    features: FeatureFactory,
    context: Context
  ) async throws -> Self {
    let diagnostics: Diagnostics = features.instance()
    let asyncExecutor: AsyncExecutor = features.instance(of: AsyncExecutor.self).detach()
    let navigationTree: NavigationTree = features.instance()
    let autofillContext: AutofillExtensionContext = features.instance()
    let session: Session = try await features.instance()
    let currentAccount: Account = try await session.currentAccount()

    let state: StateBinding<ViewState> = .variable(
      initial: .init(
        title: context.title,
        titleIconName: context.titleIconName,
        snackBarMessage: .none
      )
    )

    let viewState: DisplayViewState<ViewState> = .init(stateSource: state)

    let searchController: ResourceSearchDisplayController = try await features.instance(
      context: .init(
        searchPrompt: context.searchPrompt,
        showMessage: { (message: SnackBarMessage?) in
          state.set(\.snackBarMessage, to: message)
        }
      )
    )

    let contentController: ResourceUserGroupsListDisplayController = try await features.instance(
      context: .init(
        filter: searchController
          .searchText
          .convert { (text: String) -> UserGroupsFilter in
            .init(
              userID: currentAccount.userID,
              text: text
            )
          },
        selectGroup: selectUserGroup(_:),
        showMessage: { (message: SnackBarMessage?) in
          state.set(\.snackBarMessage, to: message)
        }
      )
    )

    @Sendable nonisolated func selectUserGroup(
      _ userGroupID: UserGroup.ID
    ) {
      asyncExecutor.schedule(.replace) {
        do {
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

          navigationTree
            .push(
              ResourcesListNodeView.self,
              controller: nodeController
            )
        }
        catch {
          diagnostics.log(
            error: error,
            info: .message(
              "Failed to handle user group selection."
            )
          )
          state.set(\.snackBarMessage, to: .error(error))
        }
      }
    }

    nonisolated func closeExtension() {
      asyncExecutor.schedule(.reuse) {
        await autofillContext.cancelAndCloseExtension()
      }
    }

    return .init(
      viewState: viewState,
      searchController: searchController,
      contentController: contentController,
      closeExtension: closeExtension
    )
  }
}

extension FeatureFactory {

  @MainActor public func usePassboltResourceUserGroupsListNodeController() {
    self.use(
      .disposable(
        ResourceUserGroupsListNodeController.self,
        load: ResourceUserGroupsListNodeController.load(features:context:)
      )
    )
  }
}
