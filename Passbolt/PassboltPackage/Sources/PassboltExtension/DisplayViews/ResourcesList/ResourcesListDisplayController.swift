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

internal final class ResourcesListDisplayController: ViewController {

  internal nonisolated let viewState: ViewStateSource<ViewState>

  private let asyncExecutor: AsyncExecutor
  private let sessionData: SessionData
  private let resources: ResourcesController

  private let context: Context
  private let features: Features

  internal init(
    context: Context,
    features: Features
  ) throws {
    try features.ensureScope(SessionScope.self)

    self.context = context
    self.features = features

    self.asyncExecutor = try features.instance()
    self.sessionData = try features.instance()
    self.resources = try features.instance()

    self.viewState = .init(
      initial: .init(
        suggested: .init(),
        resources: .init()
      ),
      updateFrom: ComputedVariable(
        combined: context.filterTextSource,
        with: sessionData.lastUpdate,
        combine: { (update: (Update<String>, Update<Timestamp>)) in
          try update.0.value
        }
      ),
      update: { [resources] (updateState, update: Update<String>) in
        do {
          var filter: ResourcesFilter = context.baseFilter
          filter.text = try update.value
          let filteredResources: Array<ResourceListItemDSV> = try await resources.filteredResourcesList(filter)
          await updateState { (viewState: inout ViewState) in
            viewState.suggested = filteredResources.filter(context.suggestionFilter)
            viewState.resources = filteredResources
          }
        }
        catch {
					error.consume()
        }
      }
    )
  }
}

extension ResourcesListDisplayController {

  internal struct Context {

    internal var baseFilter: ResourcesFilter
    internal var filterTextSource: AnyUpdatable<String>
    internal var suggestionFilter: (ResourceListItemDSV) -> Bool
    internal var createResource: (() -> Void)?
    internal var selectResource: (Resource.ID) -> Void
  }

  internal struct ViewState: Equatable {

    internal var suggested: Array<ResourceListItemDSV>
    internal var resources: Array<ResourceListItemDSV>
  }
}

extension ResourcesListDisplayController {

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

  internal final func createResource() {
    self.context.createResource?()
  }

  internal final func selectResource(
    _ id: Resource.ID
  ) {
    self.context.selectResource(id)
  }
}
