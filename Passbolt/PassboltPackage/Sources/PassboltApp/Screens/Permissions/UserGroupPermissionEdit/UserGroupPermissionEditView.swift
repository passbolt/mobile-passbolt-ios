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

internal struct UserGroupPermissionEditView: ComponentView {

  @ObservedObject private var state: ObservableValue<ViewState>
  private let controller: Controller

  internal init(
    state: ObservableValue<ViewState>,
    controller: UserGroupPermissionEditController
  ) {
    self.state = state
    self.controller = controller
  }

  internal var body: some View {
    ScreenView(
      title: .localized(
        key: "resource.permission.details.title"
      ),
      snackBarMessage: self.$state.snackBarMessage
    ) {
      self.contentView
    }
    .alert(presenting: self.$state.deleteConfirmationAlert)
  }

  @ViewBuilder private var contentView: some View {
    VStack(spacing: 0) {
      UserGroupAvatarView()
        .frame(
          width: 96,
          height: 96,
          alignment: .center
        )
        .padding(8)

      Text(displayable: self.state.name)
        .text(
          font: .inter(
            ofSize: 20,
            weight: .semibold
          ),
          color: .passboltPrimaryText
        )
        .padding(8)

      VStack(
        alignment: .leading,
        spacing: 8
      ) {
        Text(
          displayable: .localized(
            key: "permission.details.group.members.section.title"
          )
        )
        .text(
          font: .inter(
            ofSize: 12,
            weight: .semibold
          ),
          color: .passboltPrimaryText
        )

        HStack(spacing: 0) {
          AsyncButton(
            action: {
              await self.controller.showGroupMembers()
            },
            label: {
              OverlappingAvatarStackView(self.state.groupMembersPreviewItems)
            }
          )
          .frame(maxWidth: .infinity)

          Image(named: .chevronRight)
            .resizable()
            .aspectRatio(1, contentMode: .fit)
            .padding(
              top: 12,
              leading: 4,
              bottom: 12,
              trailing: 0
            )
        }
        .frame(height: 40, alignment: .leading)
        .padding(top: 16)
      }
      .frame(
        maxWidth: .infinity,
        alignment: .leading
      )
      .padding(top: 16)

      VStack(
        alignment: .leading,
        spacing: 8
      ) {
        Text(
          displayable: .localized(
            key: "permission.details.type.section.title"
          )
        )
        .text(
          font: .inter(
            ofSize: 12,
            weight: .semibold
          ),
          color: .passboltPrimaryText
        )

        ForEach(
          PermissionType.allCases,
          id: \.self
        ) { (permissionType: PermissionType) in
          AsyncButton(
            action: {
              await self.controller
                .setPermissionType(permissionType)
            },
            label: {
              HStack(spacing: 0) {
                ResourcePermissionTypeView(
                  permissionType: permissionType
                )
                .frame(
                  maxWidth: .infinity,
                  alignment: .leading
                )

                Image(
                  named: self.state.permissionType == permissionType
                    ? .circleSelected
                    : .circleUnselected
                )
                .resizable()
                .frame(width: 20, height: 20)
                .padding(4)
              }
            }
          )
        }
      }
      .frame(
        maxWidth: .infinity,
        alignment: .leading
      )
      .padding(top: 16)

      Spacer()

      PrimaryButton(
        title: .localized(
          key: .apply
        ),
        action: {
          self.controller
            .saveChanges()
        }
      )

      SecondaryButton(
        title: .localized(
          key: "resource.permission.edit.button.delete.title"
        ),
        iconName: .trash,
        action: {
          self.controller
            .deletePermission()
        }
      )
    }
    .padding(
      leading: 16,
      bottom: 16,
      trailing: 16
    )
  }
}

extension UserGroupPermissionEditView {

  internal struct ViewState: Hashable {

    internal var name: DisplayableString
    internal var permissionType: PermissionType
    internal var groupMembersPreviewItems: Array<OverlappingAvatarStackView.Item>
    internal var deleteConfirmationAlert: ConfirmationAlertMessage? = .none
    internal var snackBarMessage: SnackBarMessage? = .none
  }
}
