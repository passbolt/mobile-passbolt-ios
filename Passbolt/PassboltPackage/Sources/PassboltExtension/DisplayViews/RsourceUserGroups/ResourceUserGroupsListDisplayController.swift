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
import Users

// MARK: - Interface

internal struct ResourceUserGroupsListDisplayController {

  internal var viewState: ViewStateBinding<ViewState>
  internal var activate: @Sendable () async -> Void
  internal var refresh: @Sendable () async -> Void
  internal var selectGroup: (UserGroup.ID) -> Void
}

extension ResourceUserGroupsListDisplayController: ViewController {

  internal struct Context: LoadableFeatureContext {
    // feature is disposable, we don't care about ID
    internal let identifier: AnyHashable = IID()

    internal var filter: ViewStateView<UserGroupsFilter>
    internal var selectGroup: (UserGroup.ID) -> Void
    internal var showMessage: (SnackBarMessage?) -> Void
  }

  internal struct ViewState: Hashable {

    internal var userGroups: Array<ResourceUserGroupListItemDSV>
  }

  #if DEBUG
  nonisolated static var placeholder: Self {
    .init(
      viewState: .placeholder,
      activate: { unimplemented() },
      refresh: { unimplemented() },
      selectGroup: { _ in unimplemented() }
    )
  }
  #endif
}

// MARK: - Implementation

extension ResourceUserGroupsListDisplayController {

  @MainActor fileprivate static func load(
    features: FeatureFactory,
    context: Context
  ) async throws -> Self {
    let diagnostics: Diagnostics = features.instance()
    let asyncExecutor: AsyncExecutor = features.instance(of: AsyncExecutor.self).detach()
    let sessionData: SessionData = try await features.instance()
    let userGroups: UserGroups = try await features.instance()

    let viewState: ViewStateBinding<ViewState> = .init(
      initial: .init(
        userGroups: .init()
      )
    )

    context
      .filter
      .valuesPublisher()
      .sink { (filter: UserGroupsFilter) in
        updateDisplayedUserGroups(filter)
      }
      .store(in: viewState.cancellables)

    @Sendable nonisolated func activate() async {
      await sessionData
        .updatesSequence
        .forEach {
          await updateDisplayedUserGroups(context.filter.wrappedValue)
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

    @Sendable nonisolated func updateDisplayedUserGroups(
      _ filter: UserGroupsFilter
    ) {
      asyncExecutor.schedule(.replace) {
        do {
          try Task.checkCancellation()

          let filteredUserGroups: Array<ResourceUserGroupListItemDSV> =
            try await userGroups.filteredResourceUserGroups(filter)

          try Task.checkCancellation()

          await viewState.mutate { viewState in
            viewState.userGroups = filteredUserGroups
          }
        }
        catch {
          diagnostics.log(
            error: error,
            info: .message(
              "Failed to access resource user groups list."
            )
          )
          context.showMessage(.error(error))
        }
      }
    }

    return .init(
      viewState: viewState,
      activate: activate,
      refresh: refresh,
      selectGroup: context.selectGroup
    )
  }
}

extension FeatureFactory {

  @MainActor public func usePassboltResourceUserGroupsListDisplayController() {
    self.use(
      .disposable(
        ResourceUserGroupsListDisplayController.self,
        load: ResourceUserGroupsListDisplayController.load(features:context:)
      )
    )
  }
}
