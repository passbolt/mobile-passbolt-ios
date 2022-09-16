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

import SwiftUI
import UICommons
import UIComponents

internal struct PermissionUsersAndGroupsSearchView: ComponentView {

  @ObservedObject private var state: ObservableValue<ViewState>
  private let controller: Controller

  internal init(
    state: ObservableValue<ViewState>,
    controller: PermissionUsersAndGroupsSearchController
  ) {
    self.state = state
    self.controller = controller
  }

  internal var body: some View {
    ScreenView(
      title: .localized(
        key: "resource.permission.edit.user.and.group.search.title"
      ),
      snackBarMessage: self.$state.snackBarMessage,
      contentView: {
        VStack(spacing: 0) {
          self.searchBar
          self.list
          self.saveButton
        }
      }
    )
  }

  private var searchBar: some View {
    VStack(spacing: 0) {
      SearchView(
        prompt: .localized(
          key: "resource.permission.edit.user.and.group.search.prompt"
        ),
        text: self.$state.searchText
      )
      .padding(
        top: 0,
        leading: 16,
        trailing: 16
      )

      OverlappingAvatarStackView(
        Array(self.state.selectedItems)
      )
      .frame(height: 40)
      .padding(
        top: 8,
        leading: 16,
        bottom: 8,
        trailing: 16
      )
    }
  }

  private var list: some View {
    Group {
      if self.state.listSelectionRowViewModels.isEmpty && self.state.listExistingRowViewModels.isEmpty {
        EmptyListView(
          message: .localized(
            key: "generic.user.search.list.empty"
          )
        )
      }
      else {
        List {
          Section {
            ForEach(self.state.listSelectionRowViewModels) { listRow in
              switch listRow {
              case let .user(userRow):
                UserListRowView(
                  model: userRow,
                  contentAction: {
                    self.controller.toggleUserSelection(userRow.id)
                  },
                  rightAccesory: {
                    SelectionIndicator(
                      selected: self.state.selectedItems.contains { item in
                        switch item {
                        case let .user(id, _):
                          return userRow.id == id
                        case .userGroup:
                          return false
                        }
                      }
                    )
                  }
                )
              case let .userGroup(userGroupRow):
                UserGroupListRowView(
                  model: userGroupRow,
                  contentAction: {
                    self.controller.toggleUserGroupSelection(userGroupRow.id)
                  },
                  rightAccesory: {
                    SelectionIndicator(
                      selected: self.state.selectedItems.contains { item in
                        switch item {
                        case let .userGroup(id):
                          return userGroupRow.id == id
                        case .user:
                          return false
                        }
                      }
                    )
                  }
                )
              }
            }
          }
          .listSectionSeparator(.hidden)
          .backgroundColor(.passboltBackground)

          if !self.state.listExistingRowViewModels.isEmpty {
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

              ForEach(self.state.listExistingRowViewModels) { listRow in
                switch listRow {
                case let .user(userRow, permission):
                  UserListRowView(
                    model: userRow,
                    contentAction: {
                      self.controller.toggleUserSelection(userRow.id)
                    },
                    rightAccesory: {
                      ResourcePermissionTypeCompactView(
                        permissionType: permission
                      )
                    }
                  )
                case let .userGroup(userGroupRow, permission):
                  UserGroupListRowView(
                    model: userGroupRow,
                    contentAction: {
                      self.controller.toggleUserGroupSelection(userGroupRow.id)
                    },
                    rightAccesory: {
                      ResourcePermissionTypeCompactView(
                        permissionType: permission
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
      action: {
        self.controller
          .saveSelection()
      }
    )
    .padding(16)
  }
}

extension PermissionUsersAndGroupsSearchView {

  internal struct ViewState: Hashable {

    internal var searchText: String
    internal var selectedItems: Array<OverlappingAvatarStackView.Item>
    internal var listSelectionRowViewModels: Array<SelectionRowViewModel>
    internal var listExistingRowViewModels: Array<ExistingPermissionRowViewModel>
    internal var snackBarMessage: SnackBarMessage? = .none
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
    case let .user(model):
      return "user-\(model.id)"
    case let .userGroup(model):
      return "userGroup-\(model.id)"
    }
  }
}

extension PermissionUsersAndGroupsSearchView {

  internal enum ExistingPermissionRowViewModel {

    case user(UserListRowViewModel, permission: PermissionType)
    case userGroup(UserGroupListRowViewModel, permission: PermissionType)
  }
}

extension PermissionUsersAndGroupsSearchView.ExistingPermissionRowViewModel: Hashable {}

extension PermissionUsersAndGroupsSearchView.ExistingPermissionRowViewModel: Identifiable {

  public var id: AnyHashable {
    switch self {
    case let .user(model, _):
      return "user-\(model.id)"
    case let .userGroup(model, _):
      return "userGroup-\(model.id)"
    }
  }
}
