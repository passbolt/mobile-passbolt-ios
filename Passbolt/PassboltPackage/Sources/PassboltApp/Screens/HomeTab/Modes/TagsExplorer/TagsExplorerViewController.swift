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
import FeatureScopes
import Metadata
import OSFeatures
import Resources
import Session
import SessionData
import SharedUIComponents

internal final class TagsExplorerViewController: ViewController {

  internal typealias Context = ResourceTag?

  internal struct ViewState: Equatable {

    internal var title: DisplayableString
    internal let resourceTagID: ResourceTag.ID?
    internal var tags: Array<ResourceTagListItemDSV> = .init()
    internal var resources: Array<ResourceListItemDSV> = .init()
  }

  nonisolated let viewState: ViewStateSource<ViewState>
  internal let searchController: ResourceSearchDisplayController

  fileprivate let features: Features
  fileprivate let sessionData: SessionData

  fileprivate let navigationToTagContent: NavigationToTagContent
  fileprivate let navigationToResourceDetails: NavigationToResourceDetails

  init(context: Context, features: Features) throws {
    self.features = features
    self.sessionData = try features.instance()

    self.navigationToTagContent = try features.instance()
    self.navigationToResourceDetails = try features.instance()

    let navigationToAccountMenu: NavigationToAccountMenu = try features.instance()
    let navigationToHomePresentationMenu: NavigationToHomePresentationMenu = try features.instance()

    let resources: ResourcesController = try features.instance()
    let resourceTags: ResourceTags = try features.instance()

    self.searchController = try features.instance(
      context: .init(
        searchPrompt: .localized(key: "resources.search.placeholder"),
        onPresentationMenuTap: {
          await consumingErrors {
            try await navigationToHomePresentationMenu.perform()
          }
        },
        onAvatarTap: {
          await consumingErrors {
            try await navigationToAccountMenu.perform()
          }
        }
      )
    )

    if let resourceTag = context {
      // Initialized with a tag, show resources with this tag
      self.viewState = .init(
        initial: .init(
          title: .raw(resourceTag.slug.rawValue),
          resourceTagID: resourceTag.id
        ),
        updateFrom: ComputedVariable(combined: resources.lastUpdate, with: searchController.searchText),
        update: { updateState, updates in
          let filter: ResourcesFilter = .init(
            sorting: .nameAlphabetically,
            text: try updates.value.1,
            tags: [resourceTag.id]
          )
          let resources: Array<ResourceListItemDSV> = try await resources.filteredResourcesList(filter)
          updateState { state in
            state.resources = resources
          }
        }
      )
    }
    else {
      // Initialized without a tag, show all tags
      self.viewState = .init(
        initial: .init(
          title: .localized(key: "home.presentation.mode.tags.explorer.title"),
          resourceTagID: .none
        ),
        updateFrom: ComputedVariable(combined: sessionData.lastUpdate, with: searchController.searchText),
        update: { updateState, updates in
          let searchText: String = try updates.value.1
          let tagList: Array<ResourceTagListItemDSV> = try await resourceTags.filteredTagsList(searchText)
          updateState { state in
            state.tags = tagList
          }
        }
      )
    }
  }
}

extension TagsExplorerViewController {

  func refreshIfNeeded() async {
    await consumingErrors {
      try await sessionData
        .refreshIfNeeded()
    }
  }

  func presentTagContent(_ tag: ResourceTag) async {
    await consumingErrors {
      try await navigationToTagContent.perform(context: tag)
    }
  }

  func presentResourceDetails(_ resourceID: Resource.ID) async {
    await consumingErrors {
      try await navigationToResourceDetails.perform(context: resourceID)
    }
  }

  func presentResourceMenu(_ resourceID: Resource.ID) async {
    await consumingErrors {
      let features: Features =
        try features
        .branchIfNeeded(
          scope: ResourceScope.self,
          context: resourceID
        )
      let navigationToResourceMenu: NavigationToResourceContextualMenu = try features.instance()
      try await navigationToResourceMenu.perform(context: .init())
    }
  }
}
