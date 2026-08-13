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

import CommonModels
import Display
import FeatureScopes
import Users

/// Searches the workspace users and groups and lets the operator pick new recipients to add to the permission
/// confirmation screen. Selection is returned by id via ``Context/onSelect``; the confirmation screen then fetches
/// the picked recipients' keys/membership (snapshot expansion) and adds them with the default `read` permission.
internal final class ConfirmAddRecipientsController: @MainActor ViewController {

  internal struct Context: Sendable {

    /// Recipients already present on the confirmation screen - excluded from the search results.
    internal var excludedUsers: Set<User.ID>
    internal var excludedGroups: Set<UserGroup.ID>
    internal var onSelect: @Sendable (Array<User.ID>, Array<UserGroup.ID>) async -> Void
  }

  internal struct ViewState: Equatable, Sendable {

    internal var searchText: String = .init()
    internal var users: Array<UserDetailsDSV> = .init()
    internal var groups: Array<UserGroupDetailsDSV> = .init()
    internal var selectedUsers: OrderedSet<User.ID> = .init()
    internal var selectedGroups: OrderedSet<UserGroup.ID> = .init()
  }

  /// Time a typed query waits before reaching the database, absorbing the keystrokes that follow it.
  private static let searchDebounceNanoseconds: UInt64 = 300_000_000

  internal let viewState: ViewStateSource<ViewState>

  private let context: Context
  private let users: Users
  private let userGroups: UserGroups
  private let navigationToSelf: NavigationToConfirmAddRecipients
  private var searchTask: Task<Void, Never>?

  internal init(
    context: Context,
    features: Features
  ) throws {
    self.context = context
    self.users = try features.instance()
    self.userGroups = try features.instance()
    self.navigationToSelf = try features.instance()
    self.viewState = .init(initial: .init())
    // Nobody is typing yet - fill the list right away.
    self.search(for: .init(), debounced: false)
  }

  deinit {
    // The screen is gone - no point in finishing a search nobody will see.
    self.searchTask?.cancel()
  }

  internal func updateSearchText(
    _ text: String
  ) {
    self.viewState.update(\.searchText, to: text)
    self.search(for: text, debounced: true)
  }

  private func search(
    for text: String,
    debounced: Bool
  ) {
    self.searchTask?.cancel()
    self.searchTask = .init { [weak self] in
      guard let self else { return }
      if debounced {
        // Typing replaces the query faster than the database can answer it - wait the keystrokes out first. The
        // task is cancelled by the next one, so a query only runs for text the operator paused at.
        do {
          try await Task.sleep(nanoseconds: Self.searchDebounceNanoseconds)
        }
        catch {
          return  // cancelled by a newer query
        }
      }
      do {
        let matchingUsers: Array<UserDetailsDSV> =
          try await self.users
          .filteredUsers(.init(text: text))
          .filter { !self.context.excludedUsers.contains($0.id) }
        let matchingGroups: Array<UserGroupDetailsDSV> =
          try await self.userGroups
          .filteredUserGroups(.init(userID: .none, text: text))
          .filter { !self.context.excludedGroups.contains($0.id) }
        // A newer query already replaced this one - dropping its results keeps the list matching the field.
        guard Task.isCancelled == false
        else { return }
        self.viewState.update { (state: inout ViewState) in
          state.users = matchingUsers
          state.groups = matchingGroups
        }
      }
      catch {
        error.consume()
      }
    }
  }

  internal func avatar(
    for userID: User.ID
  ) -> @Sendable () async -> Data? {
    self.users.loadAvatar(for: userID)
  }

  internal func toggleUser(
    _ userID: User.ID
  ) {
    self.viewState.update { (state: inout ViewState) in
      if state.selectedUsers.contains(userID) {
        state.selectedUsers.remove(userID)
      }
      else {
        state.selectedUsers.append(userID)
      }
    }
  }

  internal func toggleUserGroup(
    _ groupID: UserGroup.ID
  ) {
    self.viewState.update { (state: inout ViewState) in
      if state.selectedGroups.contains(groupID) {
        state.selectedGroups.remove(groupID)
      }
      else {
        state.selectedGroups.append(groupID)
      }
    }
  }

  internal func apply() async {
    let state: ViewState = await self.viewState.current
    let selectedUsers: Array<User.ID> = .init(state.selectedUsers)
    let selectedGroups: Array<UserGroup.ID> = .init(state.selectedGroups)
    await self.context.onSelect(selectedUsers, selectedGroups)
    await consumingErrors {
      try await self.navigationToSelf.revert()
    }
  }
}
