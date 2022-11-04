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
import SessionData

// MARK: - Interface

internal struct ResourceTagsListDisplayController {

  @IID internal var id
  internal var viewState: ViewStateBinding<ViewState>
  internal var viewActions: ViewActions
}

extension ResourceTagsListDisplayController: ViewController {

  internal struct Context: LoadableFeatureContext {
    // feature is disposable, we don't care about ID
    internal let identifier: AnyHashable = IID()

    internal var filter: StateView<String>
    internal var selectTag: (ResourceTag.ID) -> Void
    internal var showMessage: (SnackBarMessage?) -> Void
  }

  internal struct ViewState: Hashable {

    internal var resourceTags: Array<ResourceTagListItemDSV>
  }

  internal struct ViewActions: ViewControllerActions {

    internal var activate: @Sendable () async -> Void
    internal var refresh: @Sendable () async -> Void
    internal var selectTag: (ResourceTag.ID) -> Void

    #if DEBUG
    internal static var placeholder: Self {
      .init(
        activate: { unimplemented() },
        refresh: { unimplemented() },
        selectTag: { _ in unimplemented() }
      )
    }
    #endif
  }

  #if DEBUG
  nonisolated static var placeholder: Self {
    .init(
      viewState: .placeholder,
      viewActions: .placeholder
    )
  }
  #endif
}

// MARK: - Implementation

extension ResourceTagsListDisplayController {

  @MainActor fileprivate static func load(
    features: FeatureFactory,
    context: Context
  ) async throws -> Self {
    let diagnostics: Diagnostics = features.instance()
    let asyncExecutor: AsyncExecutor = features.instance(of: AsyncExecutor.self).detach()
    let sessionData: SessionData = try await features.instance()
    let resourceTags: ResourceTags = try await features.instance()

    let state: StateBinding<ViewState> = .variable(
      initial: .init(
        resourceTags: .init()
      )
    )
    let viewState: ViewStateBinding<ViewState> = .init(
      stateSource: state
    )

    context
      .filter
      .sink { (filter: String) in
        updateDisplayedResourceTags(filter)
      }
      .store(in: viewState.cancellables)

    @Sendable nonisolated func activate() async {
      do {
        try await sessionData
          .updatesSequence
          .forEach {
            updateDisplayedResourceTags(context.filter.get())
          }
      }
      catch {
        diagnostics.log(
          error: error,
          info: .message(
            "Resource tags list updates broken!"
          )
        )
        context.showMessage(.error(error))
      }
    }

    @Sendable nonisolated func refresh() async {
      do {
        try await sessionData.refreshIfNeeded()
      }
      catch {
        diagnostics.log(
          error: error,
          info: .message(
            "Failed to refresh session data."
          )
        )
        context.showMessage(.error(error))
      }
    }

    @Sendable nonisolated func updateDisplayedResourceTags(
      _ filter: String
    ) {
      asyncExecutor.schedule(.replace) {
        do {
          try Task.checkCancellation()

          let filteredResourceTags: Array<ResourceTagListItemDSV> =
            try await resourceTags.filteredTagsList(filter)

          try Task.checkCancellation()

          viewState.resourceTags = filteredResourceTags
        }
        catch {
          diagnostics.log(
            error: error,
            info: .message(
              "Failed to access resource tags list."
            )
          )
          context.showMessage(.error(error))
        }
      }
    }

    return .init(
      viewState: viewState,
      viewActions: .init(
        activate: activate,
        refresh: refresh,
        selectTag: context.selectTag
      )
    )
  }
}

extension FeatureFactory {

  @MainActor public func usePassboltResourceTagsListDisplayController() {
    self.use(
      .disposable(
        ResourceTagsListDisplayController.self,
        load: ResourceTagsListDisplayController.load(features:context:)
      )
    )
  }
}
