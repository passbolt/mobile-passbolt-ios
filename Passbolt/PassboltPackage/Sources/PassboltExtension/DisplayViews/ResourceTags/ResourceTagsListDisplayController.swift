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
import SessionData

internal final class ResourceTagsListDisplayController: ViewController {

  internal nonisolated let viewState: ViewStateSource<ViewState>

  private let sessionData: SessionData
  private let resourceTags: ResourceTags

  private let context: Context
  private let features: Features

  internal init(
    context: Context,
    features: Features
  ) throws {
    try features.ensureScope(SessionScope.self)
    self.context = context
    self.features = features

    self.sessionData = try features.instance()
    self.resourceTags = try features.instance()

    self.viewState = .init(
      initial: .init(
        resourceTags: .init()
      ),
      updateFrom: ComputedVariable(
        combined: context.filter,
        with: self.sessionData.lastUpdate
      ),
      update: { [resourceTags] (updateView, update) in
        await consumingErrors {
          let filteredResourceTags: Array<ResourceTagListItemDSV> = try await resourceTags.filteredTagsList(
            update.value.0
          )

          await updateView { viewState in
            viewState.resourceTags = filteredResourceTags
          }
        }
      }
    )
  }
}

extension ResourceTagsListDisplayController {

  internal struct Context {

    internal var filter: AnyUpdatable<String>
    internal var selectTag: (ResourceTag.ID) async throws -> Void
  }

  internal struct ViewState: Equatable {

    internal var resourceTags: Array<ResourceTagListItemDSV>
  }
}

extension ResourceTagsListDisplayController {

  internal final func refresh() async {
    do {
      try await self.sessionData.refreshIfNeeded()
    }
    catch {
      error.consume(
        context: "Failed to refresh session data."
      )
    }
  }

  internal final func selectTag(
    _ id: ResourceTag.ID
  ) async throws {
    try await self.context.selectTag(id)
  }
}
