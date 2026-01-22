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

internal struct ResourcePermissionEditListView: ControlledView {

  internal let controller: ResourcePermissionEditListController

  internal init(
    controller: ResourcePermissionEditListController
  ) {
    self.controller = controller
  }

  internal var body: some View {
    WithViewState(from: self.controller) { state in
      ScreenView(
        title: .localized(
          key: "resource.permission.edit.list.title"
        ),
        loading: state.loading
      ) {
        self.contentView(with: state)
      }
      .tabbarHidden()
    }
  }

  @ViewBuilder private func contentView(
    with state: Controller.ViewState
  ) -> some View {
    VStack(spacing: 0) {
      if state.permissionListItems.isEmpty {
        self.addPermissionButton
          .padding(.horizontal, 16)
        EmptyListView(
          message: .localized(
            key: "resource.permission.edit.list.empty.message"
          )
        )
      }
      else {
        CommonList {
          CommonListSection {
            self.addPermissionButton
              .listRowSeparator(.hidden)
              .listRowInsets(EdgeInsets())
              .buttonStyle(.plain)

            ForEach(
              state.permissionListItems,
              id: \PermissionListRowItem.self
            ) { item in
              PermissionListRowView(
                item,
                action: {
                  switch item {
                  case .user(let details, _):
                    await self.controller.showUserPermissionEdit(details)

                  case .userGroup(let details):
                    await self.controller.showUserGroupPermissionEdit(details)
                  }
                }
              )
            }
          }
        }
      }

      PrimaryButton(
        title: .localized(
          key: .apply
        ),
        action: self.controller.saveChanges
      )
      .opacity(
        state.permissionListItems.isEmpty
          ? 0.5
          : 1
      )
      .disabled(state.permissionListItems.isEmpty)
      .padding(16)
    }
  }

  private var addPermissionButton: some View {
    CommonListRow(
      contentAction: self.controller.addPermission,
      content: {
        HStack(spacing: 8) {
          Image(named: .create)
            .resizable()
            .frame(
              width: 40,
              height: 40,
              alignment: .center
            )
          Text(displayable: "resource.permission.edit.list.add.button.title")
            .text(
              font: .inter(
                ofSize: 14,
                weight: .semibold
              ),
              color: .passboltPrimaryText
            )
        }
      }
    )
    .padding(
      top: 8,
      bottom: 8
    )
    .frame(height: 64)
  }
}
