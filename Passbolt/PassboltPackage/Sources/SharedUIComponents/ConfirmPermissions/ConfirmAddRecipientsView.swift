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
import UICommons

internal struct ConfirmAddRecipientsView: @MainActor ControlledView {

  internal let controller: ConfirmAddRecipientsController

  internal init(
    controller: ConfirmAddRecipientsController
  ) {
    self.controller = controller
  }

  internal var body: some View {
    ScreenView(
      title: .localized(
        key: "resource.permission.confirm.action.add"
      ),
      contentView: {
        WithViewState(from: self.controller) { state in
          VStack(spacing: 0) {
            SearchView(
              prompt: .localized(
                key: "resource.permission.edit.user.and.group.search.prompt"
              ),
              text: self.binding(
                to: \.searchText,
                updating: { self.controller.updateSearchText($0) }
              )
            )
            .padding(top: 0, leading: 16, trailing: 16)
            .accessibilityIdentifier("permissions.confirm.add.search")

            self.list(for: state)

            PrimaryButton(
              title: .localized(key: .apply),
              action: self.controller.apply
            )
            .padding(16)
            .accessibilityIdentifier("permissions.confirm.add.apply")
          }
        }
      }
    )
    .tabbarHidden()
  }

  @ViewBuilder private func list(
    for state: Controller.ViewState
  ) -> some View {
    if state.users.isEmpty && state.groups.isEmpty {
      EmptyListView(
        message: .localized(
          key: "generic.user.search.list.empty"
        )
      )
    }
    else {
      CommonList {
        CommonListSection {
          ForEach(state.groups, id: \UserGroupDetailsDSV.id) { (group: UserGroupDetailsDSV) in
            UserGroupListRowView(
              model: .init(
                id: group.id,
                name: "\(group.name)"
              ),
              contentAction: {
                self.controller.toggleUserGroup(group.id)
              },
              rightAccesory: {
                self.with(\.selectedGroups) { (selected: OrderedSet<UserGroup.ID>) in
                  SelectionIndicator(selected: selected.contains(group.id))
                }
              }
            )
            // Keyed by the name the operator sees, so a test can pick a candidate without knowing its identifier.
            .accessibilityIdentifier("permissions.confirm.add.group.\(group.name)")
          }

          ForEach(state.users, id: \UserDetailsDSV.id) { (user: UserDetailsDSV) in
            UserListRowView(
              model: .init(
                id: user.id,
                fullName: "\(user.firstName) \(user.lastName)",
                username: "\(user.username)",
                avatarImageFetch: self.controller.avatar(for: user.id),
                isSuspended: user.isSuspended
              ),
              contentAction: {
                self.controller.toggleUser(user.id)
              },
              rightAccesory: {
                self.with(\.selectedUsers) { (selected: OrderedSet<User.ID>) in
                  SelectionIndicator(selected: selected.contains(user.id))
                }
              }
            )
            .accessibilityIdentifier("permissions.confirm.add.user.\(user.username)")
          }
        }
      }
    }
  }
}
