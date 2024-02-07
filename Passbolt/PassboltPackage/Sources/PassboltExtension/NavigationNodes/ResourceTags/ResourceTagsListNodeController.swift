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

internal final class ResourceTagsListNodeController: ViewController {

  internal nonisolated let viewState: ViewStateSource<ViewState>
  internal var searchController: ResourceSearchDisplayController!  // lazy?
  internal var contentController: ResourceTagsListDisplayController!  // lazy?

  private let navigationTree: NavigationTree
  private let autofillContext: AutofillExtensionContext
  private let resourceTags: ResourceTags

  private let context: Context
  private let features: Features

  internal init(
    context: Context,
    features: Features
  ) throws {
    self.context = context
    self.features = features

    self.navigationTree = features.instance()
    self.autofillContext = features.instance()
    self.resourceTags = try features.instance()

    self.viewState = .init(
      initial: .init(
        title: context.title,
        titleIconName: context.titleIconName
      )
    )

    self.searchController = try features.instance(
      context: .init(
        nodeID: context.nodeID,
        searchPrompt: context.searchPrompt
      )
    )

    self.contentController = try features.instance(
      context: .init(
        filter: self.searchController.searchText.asAnyUpdatable(),
        selectTag: self.selectResourceTag(_:)
      )
    )
  }
}

extension ResourceTagsListNodeController {

  internal struct Context {

    internal var nodeID: ViewNodeID
    internal var title: DisplayableString = .localized(key: "home.presentation.mode.tags.explorer.title")
    internal var searchPrompt: DisplayableString = .localized(key: "resources.search.placeholder")
    internal var titleIconName: ImageNameConstant = .tag
  }

  internal struct ViewState: Equatable {

    internal var title: DisplayableString
    internal var titleIconName: ImageNameConstant
  }
}

extension ResourceTagsListNodeController {

  internal final func selectResourceTag(
    _ resourceTagID: ResourceTag.ID
  ) async throws {
    let tagDetails: ResourceTag = try await self.resourceTags.details(resourceTagID)

    let nodeController: ResourcesListNodeController =
      try self.features
      .instance(
        of: ResourcesListNodeController.self,
        context: .init(
          nodeID: self.context.nodeID,
          title: .raw(tagDetails.slug.rawValue),
          titleIconName: .tag,
          baseFilter: .init(
            sorting: .nameAlphabetically,
            tags: [resourceTagID]
          )
        )
      )
    self.navigationTree
      .push(
        ResourcesListNodeView.self,
        controller: nodeController
      )
  }

  internal final func closeExtension() {
    self.autofillContext.cancelAndCloseExtension()
  }
}
