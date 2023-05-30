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
import SessionData
import Users

internal final class ResourceUserGroupsListDisplayController: ViewController {

  internal nonisolated let viewState: MutableViewState<ViewState>

  private let diagnostics: OSDiagnostics
  private let asyncExecutor: AsyncExecutor
  private let sessionData: SessionData
  private let userGroups: UserGroups

  private let context: Context
  private let features: Features

  internal init(
    context: Context,
    features: Features
  ) throws {
    try features.ensureScope(SessionScope.self)

    self.context = context
    self.features = features

    self.diagnostics = features.instance()
    self.asyncExecutor = try features.instance()
    self.sessionData = try features.instance()
    self.userGroups = try features.instance()

    self.viewState = .init(
      initial: .init(
        userGroups: .init()
      )
    )

    self.asyncExecutor.scheduleIteration(
      over: combineLatest(context.filter, sessionData.updatesSequence),
      catchingWith: self.diagnostics,
      failMessage: "User groups list updates broken!",
      failAction: { [context] (error: Error) in
        context.showMessage(.error(error))
      }
    ) { [viewState, userGroups] (filter: UserGroupsFilter, _) in
      let filteredUserGroups: Array<ResourceUserGroupListItemDSV> = try await userGroups.filteredResourceUserGroups(
        filter
      )

      await viewState.update { viewState in
        viewState.userGroups = filteredUserGroups
      }
    }
  }
}

extension ResourceUserGroupsListDisplayController {

  internal struct Context {

    internal var filter: ObservableViewState<UserGroupsFilter>
    internal var selectGroup: (UserGroup.ID) -> Void
    internal var showMessage: (SnackBarMessage?) -> Void
  }

  internal struct ViewState: Hashable {

    internal var userGroups: Array<ResourceUserGroupListItemDSV>
  }
}

extension ResourceUserGroupsListDisplayController {

  internal final func refresh() async {
    do {
      try await self.sessionData.refreshIfNeeded()
    }
    catch {
      self.diagnostics.log(
        error: error,
        info: .message(
          "Failed to refresh session data."
        )
      )
      self.context.showMessage(.error(error))
    }
  }

  internal final func selectGroup(
    _ id: UserGroup.ID
  ) {
    self.context.selectGroup(id)
  }
}
