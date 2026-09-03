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

internal struct ConfirmGroupPermissionDetailsView: @MainActor ControlledView {

  internal let controller: ConfirmGroupPermissionDetailsController

  internal init(
    controller: ConfirmGroupPermissionDetailsController
  ) {
    self.controller = controller
  }

  internal var body: some View {
    WithViewState(from: self.controller) { state in
      ScreenView(
        title: .localized(
          key: "resource.permission.details.title"
        )
      ) {
        self.contentView(with: state)
      }
    }
  }

  @ViewBuilder private func contentView(
    with state: Controller.ViewState
  ) -> some View {
    VStack(spacing: 0) {
      UserGroupAvatarView()
        .frame(width: 96, height: 96, alignment: .center)
        .padding(8)

      Text(state.details.name)
        .text(
          font: .inter(ofSize: 20, weight: .semibold),
          color: .passboltPrimaryText
        )
        .padding(8)

      self.membersSection(with: state)

      self.permissionSection(with: state)

      Spacer()

      if state.editable {
        self.actionsSection
      }
    }
    .padding(leading: 16, bottom: 16, trailing: 16)
  }

  /// Nothing here reaches the recipient list until one of these is used - the navigation bar's back button leaves
  /// the recipient as it was.
  @ViewBuilder private var actionsSection: some View {
    VStack(spacing: 8) {
      PrimaryButton(
        title: .localized(key: .apply),
        action: self.controller.apply
      )
      .accessibilityIdentifier("permissions.confirm.group.apply")

      // Secondary rather than destructive, as on the user details screen: this drops a row from a list still
      // being composed, and nothing is sent until the whole list is confirmed.
      SecondaryButton(
        title: .localized(key: "resource.permission.confirm.action.remove"),
        iconName: .trash,
        action: self.controller.remove
      )
      .accessibilityIdentifier("permissions.confirm.group.remove")
    }
    .padding(top: 16)
  }

  @ViewBuilder private func membersSection(
    with state: Controller.ViewState
  ) -> some View {
    VStack(alignment: .leading, spacing: 8) {
      Text(displayable: .localized(key: "permission.details.group.members.section.title"))
        .text(
          font: .inter(ofSize: 12, weight: .semibold),
          color: .passboltPrimaryText
        )

      HStack(spacing: 0) {
        AsyncButton(
          action: self.controller.showMembers,
          label: {
            OverlappingAvatarStackView(state.memberPreviewItems)
          }
        )
        .frame(maxWidth: .infinity)

        Image(named: .chevronRight)
          .resizable()
          .aspectRatio(1, contentMode: .fit)
          .padding(top: 12, leading: 4, bottom: 12, trailing: 0)
      }
      .frame(height: 40, alignment: .leading)
      .accessibilityIdentifier("permissions.confirm.group.members")
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(top: 16)
  }

  @ViewBuilder private func permissionSection(
    with state: Controller.ViewState
  ) -> some View {
    VStack(alignment: .leading, spacing: 8) {
      Text(displayable: .localized(key: "permission.details.type.section.title"))
        .text(
          font: .inter(ofSize: 12, weight: .semibold),
          color: .passboltPrimaryText
        )

      if state.editable {
        ForEach(Permission.allCases, id: \.self) { (permission: Permission) in
          AsyncButton(
            action: {
              self.controller.selectPermission(permission)
            },
            label: {
              HStack(spacing: 0) {
                ResourcePermissionTypeView(permission: permission)
                  .frame(maxWidth: .infinity, alignment: .leading)

                Image(
                  named: state.selectedPermission == permission
                    ? .circleSelected
                    : .circleUnselected
                )
                .resizable()
                .foregroundStyle(
                  state.selectedPermission == permission
                    ? Color.passboltPrimaryBlue
                    : Color.passboltIcon
                )
                .frame(width: 20, height: 20)
                .padding(4)
              }
            }
          )
          .accessibilityIdentifier("permissions.confirm.group.level.\(permission)")
        }
      }
      else {
        ResourcePermissionTypeView(permission: state.selectedPermission)
          .frame(alignment: .leading)
      }
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(top: 16)
  }
}
