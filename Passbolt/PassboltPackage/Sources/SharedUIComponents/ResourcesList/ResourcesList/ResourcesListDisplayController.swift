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

public final class ResourcesListDisplayController: ViewController {

  public nonisolated let viewState: ViewStateSource<ViewState>

  private let sessionData: SessionData
  private let resources: ResourcesController

  private let context: Context
  private let features: Features

  public init(
    context: Context,
    features: Features
  ) throws {
    try features.ensureScope(SessionScope.self)

    self.context = context
    self.features = features

    self.sessionData = try features.instance()
    self.resources = try features.instance()

    let pageSize = context.pageSize

    self.viewState = .init(
      initial: .init(
        suggested: .none,
        resources: .init(),
        isLoadingMore: false,
        hasMoreData: true,
        contentResetToken: 0,
        lastFilterText: ""
      ),
      updateFrom: ComputedVariable(
        combined: context.filterTextSource,
        with: sessionData.lastUpdate,
        combine: { (update: (Update<String>, Update<Timestamp>)) in
          try update.0.value
        }
      ),
      update: { [resources, pageSize] (updateState, update: Update<String>) in
        do {
          var filter: ResourcesFilter = context.baseFilter
          filter.text = try update.value
          filter.limit = pageSize
          filter.offset = 0
          let filteredResources: Array<ResourceListItemDSV> = try await resources.filteredResourcesList(filter)
          updateState { (viewState: inout ViewState) in
            let suggested: Array<ResourceListItemDSV> = filteredResources.filter(context.suggestionFilter)
            viewState.suggested = suggested.isEmpty ? .none : suggested
            viewState.resources = filteredResources
            viewState.hasMoreData = filteredResources.count >= pageSize
            viewState.isLoadingMore = false
            if viewState.lastFilterText != filter.text {
              viewState.contentResetToken += 1
            }
            viewState.lastFilterText = filter.text
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

  public struct Context {

    internal var baseFilter: ResourcesFilter
    internal var filterTextSource: AnyUpdatable<String>
    internal var suggestionFilter: (ResourceListItemDSV) -> Bool
    internal var createResource: (() async throws -> Void)?
    internal var selectResource: (Resource.ID) async throws -> Void
    internal var resourceMenuAction: (@Sendable (Resource.ID) async throws -> Void)?
    internal var pageSize: Int

    public init(
      baseFilter: ResourcesFilter,
      filterTextSource: AnyUpdatable<String>,
      suggestionFilter: @escaping (ResourceListItemDSV) -> Bool,
      createResource: (() async throws -> Void)? = nil,
      selectResource: @escaping (Resource.ID) async throws -> Void,
      resourceMenuAction: (@Sendable (Resource.ID) async throws -> Void)?,
      pageSize: Int = 50
    ) {
      self.baseFilter = baseFilter
      self.filterTextSource = filterTextSource
      self.suggestionFilter = suggestionFilter
      self.createResource = createResource
      self.selectResource = selectResource
      self.resourceMenuAction = resourceMenuAction
      self.pageSize = pageSize
    }
  }

  public struct ViewState: Equatable, Sendable {

    internal var suggested: Array<ResourceListItemDSV>?
    internal var resources: Array<ResourceListItemDSV>
    internal var isLoadingMore: Bool
    internal var hasMoreData: Bool
    internal var contentResetToken: Int
    internal var lastFilterText: String
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

  @MainActor internal final func loadMore() async {

    let currentState: ViewState = await viewState.current
    let hasMore: Bool = currentState.hasMoreData
    let isLoading: Bool = currentState.isLoadingMore

    guard hasMore, !isLoading else { return }

    self.viewState.update { state in
      state.isLoadingMore = true
    }

    do {
      let pageSize: Int = self.context.pageSize
      var filter: ResourcesFilter = self.context.baseFilter
      filter.text = try await self.context.filterTextSource.value
      filter.limit = pageSize
      filter.offset = currentState.resources.count

      let nextPageResources: Array<ResourceListItemDSV> = try await self.resources.filteredResourcesList(filter)

      self.viewState.update { state in
        state.resources.append(contentsOf: nextPageResources)
        state.hasMoreData = nextPageResources.count >= pageSize
        state.isLoadingMore = false
      }
    }
    catch {
      error.consume(context: "Failed to load more resources.")
      self.viewState.update { state in
        state.isLoadingMore = false
      }
    }
  }

  internal final func createResource() async throws {
    try await self.context.createResource?()
  }

  internal final func selectResource(
    _ id: Resource.ID
  ) async throws {
    try await self.context.selectResource(id)
  }

  internal var showResourceMenuCallback: (@Sendable (Resource.ID) async throws -> Void)? {
    self.context.resourceMenuAction
  }
}
