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

internal struct UserGroupPermissionDetailsView: ComponentView {

  @ObservedObject private var state: ObservableValue<ViewState>
  private let controller: Controller

  internal init(
    state: ObservableValue<ViewState>,
    controller: UserGroupPermissionDetailsController
  ) {
    self.state = state
    self.controller = controller
  }

  internal var body: some View {
    VStack(spacing: 0) {
      self.titleView

      self.contentView
    }
    .backgroundColor(.passboltBackground)
    .snackBarMessage(presenting: self.$state.snackBarMessage)
  }

  @ViewBuilder private var titleView: some View {
    ZStack(alignment: .top) {
      Rectangle()
        .fill(Color.passboltBackground)
        .ignoresSafeArea(.all, edges: .top)
      Text(
        displayable: .localized(
          key: "resource.permission.details.title"
        )
      )
      .font(
        .inter(
          ofSize: 16,
          weight: .semibold
        )
      )
      .foregroundColor(.passboltPrimaryText)
      .frame(height: 40)
      .padding(
        leading: 32,
        trailing: 32
      )
      // hide under navigation bar
      .padding(top: -42)
    }
    .fixedSize(horizontal: false, vertical: true)
    .zIndex(1)
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

      Text(self.state.permissionDetails.name)
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
          displayable: .localized(key: "permission.details.group.members.section.title")
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
          displayable: .localized(key: "permission.details.type.section.title")
        )
        .text(
          font: .inter(
            ofSize: 12,
            weight: .semibold
          ),
          color: .passboltPrimaryText
        )

        ResourcePermissionTypeView(
          permissionType: self.state.permissionDetails.permissionType
        )
        .frame(alignment: .leading)
      }
      .frame(
        maxWidth: .infinity,
        alignment: .leading
      )
      .padding(top: 16)

      Spacer()
    }
    .padding(
      leading: 16,
      bottom: 16,
      trailing: 16
    )
  }
}

extension UserGroupPermissionDetailsView {

  internal struct ViewState: Hashable {

    internal var permissionDetails: UserGroupPermissionDetailsDSV
    internal var groupMembersPreviewItems: Array<OverlappingAvatarStackView.Item>
    internal var snackBarMessage: SnackBarMessage? = .none
  }
}