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

internal struct ResourceTagsListNodeController {

  @IID internal var id
  @NavigationNodeID public var nodeID
  internal var viewState: ViewStateBinding<ViewState>
  internal var viewActions: ViewActions
  internal var searchController: ResourceSearchDisplayController
  internal var contentController: ResourceTagsListDisplayController
}

extension ResourceTagsListNodeController: ViewNodeController {

  internal struct Context: LoadableFeatureContext {
    // feature is disposable, we don't care about ID
    internal let identifier: AnyHashable = IID()

    internal var title: DisplayableString = .localized(key: "home.presentation.mode.tags.explorer.title")
    internal var searchPrompt: DisplayableString = .localized(key: "resources.search.placeholder")
    internal var titleIconName: ImageNameConstant = .tag
  }

  internal struct ViewState: Hashable {

    internal var title: DisplayableString
    internal var titleIconName: ImageNameConstant
    internal var snackBarMessage: SnackBarMessage?
  }

  internal struct ViewActions: ViewControllerActions {

    internal var closeExtension: () -> Void

    #if DEBUG
    internal static var placeholder: Self {
      .init(
        closeExtension: { unimplemented() }
      )
    }
    #endif
  }

  #if DEBUG
  nonisolated static var placeholder: Self {
    .init(
      viewState: .placeholder,
      viewActions: .placeholder,
      searchController: .placeholder,
      contentController: .placeholder
    )
  }
  #endif
}

extension ResourceTagsListNodeController {

  @MainActor fileprivate static func load(
    features: FeatureFactory,
    context: Context
  ) async throws -> Self {
    let diagnostics: Diagnostics = features.instance()
    let asyncExecutor: AsyncExecutor = features.instance(of: AsyncExecutor.self).detach()
    let navigationTree: NavigationTree = features.instance()
    let autofillContext: AutofillExtensionContext = features.instance()
    let resourceTags: ResourceTags = try await features.instance()

    let state: StateBinding<ViewState> = .variable(
      initial: .init(
        title: context.title,
        titleIconName: context.titleIconName,
        snackBarMessage: .none
      )
    )

    let viewState: ViewStateBinding<ViewState> = .init(stateSource: state)

    let searchController: ResourceSearchDisplayController = try await features.instance(
      context: .init(
        searchPrompt: context.searchPrompt,
        showMessage: { (message: SnackBarMessage?) in
          state.set(\.snackBarMessage, to: message)
        }
      )
    )

    let contentController: ResourceTagsListDisplayController = try await features.instance(
      context: .init(
        filter: searchController.searchText,
        selectTag: selectResourceTag(_:),
        showMessage: { (message: SnackBarMessage?) in
          state.set(\.snackBarMessage, to: message)
        }
      )
    )

    @Sendable nonisolated func selectResourceTag(
      _ resourceTagID: ResourceTag.ID
    ) {
      asyncExecutor.schedule(.replace) {
        do {
          let tagDetails: ResourceTagDSV = try await resourceTags.details(resourceTagID)

          let nodeController: ResourcesListNodeController =
            try await features
            .instance(
              of: ResourcesListNodeController.self,
              context: .init(
                title: .raw(tagDetails.slug.rawValue),
                titleIconName: .tag,
                baseFilter: .init(
                  sorting: .nameAlphabetically,
                  tags: [resourceTagID]
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
              "Failed to handle resource tag selection."
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
      viewActions: .init(
        closeExtension: closeExtension
      ),
      searchController: searchController,
      contentController: contentController
    )
  }
}

extension FeatureFactory {

  @MainActor public func usePassboltResourceTagsListNodeController() {
    self.use(
      .disposable(
        ResourceTagsListNodeController.self,
        load: ResourceTagsListNodeController.load(features:context:)
      )
    )
  }
}