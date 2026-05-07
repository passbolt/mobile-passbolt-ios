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
import UICommons

internal struct PermissionUsersAndGroupsSearchView: ControlledView {

  internal let controller: PermissionUsersAndGroupsSearchViewController

  internal init(
    controller: PermissionUsersAndGroupsSearchViewController
  ) {
    self.controller = controller
  }

  internal var body: some View {
    ScreenView(
      title: .localized(
        key: "resource.permission.edit.user.and.group.search.title"
      ),
      contentView: {
        WithViewState(from: controller) { state in
          VStack(spacing: 0) {
            self.searchBar
            self.list(for: state)
            self.saveButton
          }
        }
      }
    )
    .task(self.controller.activate)
  }

  private var searchBar: some View {
    VStack(spacing: 0) {
      SearchView(
        prompt: .localized(
          key: "resource.permission.edit.user.and.group.search.prompt"
        ),
        text: binding(
          to: \.searchText,
          updating: { self.controller.updateSearchText($0) }
        )
      )
      .padding(
        top: 0,
        leading: 16,
        trailing: 16
      )
      with(\.selectedItems) { selectedItems in

        OverlappingAvatarStackView(selectedItems)
          .frame(height: 40)
          .padding(
            top: 8,
            leading: 16,
            bottom: 8,
            trailing: 16
          )
      }
    }
  }

  private func list(for state: Controller.ViewState) -> some View {
    Group {
      if state.listSelectionRowViewModels.isEmpty && state.listExistingRowViewModels.isEmpty {
        EmptyListView(
          message: .localized(
            key: "generic.user.search.list.empty"
          )
        )
        .padding(.horizontal, -16)
      }
      else {
        List {
          Section {
            ForEach(state.listSelectionRowViewModels) { listRow in
              switch listRow {
              case .user(let userRow):
                UserListRowView(
                  model: userRow,
                  contentAction: {
                    await self.controller.toggleUserSelection(userRow)
                  },
                  rightAccesory: {
                    with(\.selectedItems) { selectedItems in
                      SelectionIndicator(
                        selected: selectedItems.contains { item in
                          switch item {
                          case .user(let id, _, _):
                            return userRow.id == id
                          case .userGroup:
                            return false
                          }
                        }
                      )
                    }
                  }
                )
              case .userGroup(let userGroupRow):
                UserGroupListRowView(
                  model: userGroupRow,
                  contentAction: {
                    await self.controller.toggleUserGroupSelection(userGroupRow.id)
                  },
                  rightAccesory: {
                    with(\.selectedItems) { selectedItems in
                      SelectionIndicator(
                        selected: selectedItems.contains { item in
                          switch item {
                          case .userGroup(let id):
                            return userGroupRow.id == id
                          case .user:
                            return false
                          }
                        }
                      )
                    }
                  }
                )
              }
            }
          }
          .listSectionSeparator(.hidden)
          .backgroundColor(.passboltBackground)

          if !state.listExistingRowViewModels.isEmpty {
            Section {
              Text(
                displayable: .localized(
                  key: "resource.permission.edit.user.and.group.search.existing.section.title"
                )
              )
              .text(
                font: .inter(
                  ofSize: 14,
                  weight: .semibold
                ),
                color: .passboltPrimaryText
              )
              .frame(maxWidth: .infinity)
              .padding(
                leading: 16,
                trailing: 16
              )
              .listRowSeparator(.hidden)
              .listRowInsets(EdgeInsets())
              .frame(height: 24)

              ForEach(state.listExistingRowViewModels) { listRow in
                switch listRow {
                case .user(let userRow, let permission):
                  UserListRowView(
                    model: userRow,
                    contentAction: {
                      await self.controller.toggleUserSelection(userRow)
                    },
                    rightAccesory: {
                      ResourcePermissionTypeCompactView(
                        permission: permission
                      )
                    }
                  )
                case .userGroup(let userGroupRow, let permission):
                  UserGroupListRowView(
                    model: userGroupRow,
                    contentAction: {
                      await self.controller.toggleUserGroupSelection(userGroupRow.id)
                    },
                    rightAccesory: {
                      ResourcePermissionTypeCompactView(
                        permission: permission
                      )
                    }
                  )
                }
              }
            }
            .listSectionSeparator(.hidden)
            .backgroundColor(.passboltBackground)
          }  // else NOP
        }
        .listStyle(.plain)
      }
    }
    .shadowTopAndBottomEdgeOverlay()
  }

  private var saveButton: some View {
    PrimaryButton(
      title: .localized(
        key: .apply
      ),
      action: self.controller.saveSelection
    )
    .padding(16)
  }
}

extension PermissionUsersAndGroupsSearchView {

  internal struct ViewState: Equatable {

    internal var searchText: String
    internal var selectedItems: Array<OverlappingAvatarStackView.Item>
    internal var listSelectionRowViewModels: Array<SelectionRowViewModel>
    internal var listExistingRowViewModels: Array<ExistingPermissionRowViewModel>
  }
}

extension PermissionUsersAndGroupsSearchView {

  internal enum SelectionRowViewModel {

    case user(UserListRowViewModel)
    case userGroup(UserGroupListRowViewModel)
  }
}

extension PermissionUsersAndGroupsSearchView.SelectionRowViewModel: Hashable {}

extension PermissionUsersAndGroupsSearchView.SelectionRowViewModel: Identifiable {

  public var id: AnyHashable {
    switch self {
    case .user(let model):
      return "user-\(model.id)"
    case .userGroup(let model):
      return "userGroup-\(model.id)"
    }
  }
}

extension PermissionUsersAndGroupsSearchView {

  internal enum ExistingPermissionRowViewModel {

    case user(UserListRowViewModel, permission: Permission)
    case userGroup(UserGroupListRowViewModel, permission: Permission)
  }
}

extension PermissionUsersAndGroupsSearchView.ExistingPermissionRowViewModel: Hashable {}

extension PermissionUsersAndGroupsSearchView.ExistingPermissionRowViewModel: Identifiable {

  public var id: AnyHashable {
    switch self {
    case .user(let model, _):
      return "user-\(model.id)"
    case .userGroup(let model, _):
      return "userGroup-\(model.id)"
    }
  }
}
