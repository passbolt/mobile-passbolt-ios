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

internal struct ResourcePermissionsDetailsView: ControlledView {

  internal let controller: ResourcePermissionsDetailsViewController

  internal init(
    controller: ResourcePermissionsDetailsViewController
  ) {
    self.controller = controller
  }

  internal var body: some View {
    self.contentView
      .backgroundColor(.passboltBackground)
      .foregroundColor(.passboltPrimaryText)
      .navigationTitle(displayable: "resource.permission.list.title")
      .task(self.controller.activate)
  }

  @ViewBuilder @MainActor private var contentView: some View {
    VStack(spacing: 0) {
      self.listView
      self.editButtonView
    }
  }

  @MainActor @ViewBuilder private var listView: some View {
    CommonList {
      CommonListSection {
        self.permissionsSectionListView
      }
    }
  }

  @MainActor @ViewBuilder private var permissionsSectionListView: some View {
    WithViewState(
      from: self.controller,
      at: \.permissionListItems
    ) { (permissionListItems: Array<PermissionListRowItem>) in
      ForEach(
        permissionListItems,
        id: \PermissionListRowItem.self
      ) { item in
        PermissionListRowView(
          item,
          action: {
            switch item {
            case .user(let details, _):
              await self.controller.showUserPermissionDetails(details)

            case .userGroup(let details):
              await self.controller.showUserGroupPermissionDetails(details)
            }
          }
        )
      }
    }
  }

  @MainActor @ViewBuilder private var editButtonView: some View {
    WithViewState(
      from: self.controller,
      at: \.editable
    ) { (editable: Bool) in
      if editable {
        PrimaryButton(
          title: "resource.permission.list.edit.button.title",
          action: self.controller.editPermissions
        )
        .padding(16)
      }  // else nothing
    }
  }
}
