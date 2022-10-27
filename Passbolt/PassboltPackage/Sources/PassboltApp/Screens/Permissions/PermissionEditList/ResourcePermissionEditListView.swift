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

internal struct ResourcePermissionEditListView: ComponentView {

  @ObservedObject private var state: ObservableValue<ViewState>
  private let controller: Controller

  internal init(
    state: ObservableValue<ViewState>,
    controller: ResourcePermissionEditListController
  ) {
    self.state = state
    self.controller = controller
  }

  internal var body: some View {
    ScreenView(
      title: .localized(
        key: "resource.permission.edit.list.title"
      ),
      loading: self.state.loading,
      snackBarMessage: self.$state.snackBarMessage
    ) {
      self.contentView
    }
  }

  @ViewBuilder private var contentView: some View {
    VStack(spacing: 0) {
      if self.state.permissionListItems.isEmpty {
        self.addPermissionButton

        EmptyListView(
          message: .localized(
            key: "resource.permission.edit.list.empty.message"
          )
        )
      }
      else {
        List(
          content: {
            self.addPermissionButton
              .listRowSeparator(.hidden)
              .listRowInsets(EdgeInsets())
              .buttonStyle(.plain)
            ForEach(
              self.state.permissionListItems,
              id: \PermissionListRowItem.self
            ) { item in
              PermissionListRowView(
                item,
                action: {
                  switch item {
                  case let .user(details, _):
                    self.controller.showUserPermissionEdit(details)

                  case let .userGroup(details):
                    self.controller.showUserGroupPermissionEdit(details)
                  }
                }
              )
            }
          }
        )
        .listStyle(.plain)
        .environment(\.defaultMinListRowHeight, 20)
      }

      PrimaryButton(
        title: .localized(
          key: .apply
        ),
        action: self.controller.saveChanges
      )
      .disabled(self.state.permissionListItems.isEmpty)
      .padding(16)
    }
  }

  private var addPermissionButton: some View {
    ListRowView(
      leftAccessory: {
        Image(named: .create)
          .resizable()
          .frame(
            width: 40,
            height: 40,
            alignment: .center
          )
      },
      contentAction: self.controller.addPermission,
      content: {
        Text(
          displayable: .localized(
            key: "resource.permission.edit.list.add.button.title"
          )
        )
        .font(
          .inter(
            ofSize: 14,
            weight: .semibold
          )
        )
        .foregroundColor(.passboltPrimaryBlue)
        .padding(
          leading: 8,
          trailing: 8
        )
      }
    )
  }
}

extension ResourcePermissionEditListView {

  internal struct ViewState: Hashable {

    internal var permissionListItems: Array<PermissionListRowItem>
    internal var loading: Bool = false
    internal var snackBarMessage: SnackBarMessage? = .none
  }
}
