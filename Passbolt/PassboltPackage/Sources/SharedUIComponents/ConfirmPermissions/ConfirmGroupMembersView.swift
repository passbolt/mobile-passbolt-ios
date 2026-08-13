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

internal struct ConfirmGroupMembersView: @MainActor ControlledView {

  internal let controller: ConfirmGroupMembersController

  internal init(
    controller: ConfirmGroupMembersController
  ) {
    self.controller = controller
  }

  internal var body: some View {
    WithViewState(from: self.controller) { state in
      ScreenView(
        title: DisplayableString(stringLiteral: state.groupName)
      ) {
        CommonList {
          CommonListSection {
            ForEach(state.members, id: \UserDetailsDSV.id) { (member: UserDetailsDSV) in
              self.memberRow(for: member)
            }
          }
        }
      }
    }
  }

  private func memberRow(
    for details: UserDetailsDSV
  ) -> some View {
    CommonListRow(
      content: {
        HStack(spacing: 8) {
          AsyncUserAvatarView(imageLoad: self.controller.avatar(for: details.id))
            .frame(width: 40, height: 40)

          ListRowTitleWithSubtitleView(
            title: DisplayableString(stringLiteral: "\(details.firstName) \(details.lastName)"),
            subtitle: "\(details.username)"
          )
        }
        .opacity(details.isSuspended ? 0.6 : 1)
      }
    )
    .padding(top: 8, bottom: 8)
    .frame(height: 64)
  }
}
