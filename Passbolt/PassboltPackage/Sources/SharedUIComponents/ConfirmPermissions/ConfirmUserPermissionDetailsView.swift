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

internal struct ConfirmUserPermissionDetailsView: @MainActor ControlledView {

  internal let controller: ConfirmUserPermissionDetailsController

  internal init(
    controller: ConfirmUserPermissionDetailsController
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
      VStack(spacing: 0) {
        AsyncUserAvatarView(
          imageLoad: self.controller.loadAvatar()
        )
        .frame(width: 96, height: 96, alignment: .center)
        .padding(8)

        Text("\(state.details.firstName) \(state.details.lastName)")
          .text(
            font: .inter(ofSize: 20, weight: .semibold),
            color: .passboltPrimaryText
          )
          .padding(8)
      }
      .opacity(state.details.isSuspended ? 0.5 : 1)

      Text("\(state.details.username)")
        .text(
          font: .inter(ofSize: 14, weight: .regular),
          color: .passboltSecondaryText
        )
        .padding(8)

      FingerprintTextView(
        fingerprint: state.details.fingerprint
      )
      .padding(8)

      self.permissionSection(with: state)

      Spacer()
    }
    .padding(leading: 16, bottom: 16, trailing: 16)
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
              await self.controller.setPermission(permission)
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
          .accessibilityIdentifier("permissions.confirm.user.level.\(permission)")
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
