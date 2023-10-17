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
import UICommons

internal struct PermissionListRowView: View {

  private let item: PermissionListRowItem
  private let action: @MainActor () async throws -> Void

  internal init(
    _ item: PermissionListRowItem,
    action: @escaping @MainActor () async throws -> Void
  ) {
    self.item = item
    self.action = action
  }

  internal var body: some View {
    switch self.item {
    case let .user(details, imageData):
      CommonListRow(
        contentAction: self.action,
        content: {
          HStack(spacing: 8) {
            AsyncUserAvatarView(imageLoad: imageData)
              .frame(
                width: 40,
                height: 40
              )

            ListRowTitleWithSubtitleView(
              title: "\(details.firstName) \(details.lastName)",
              subtitle: "\(details.username)"
            )
          }
        },
        accessory: {
          HStack(spacing: 4) {
            ResourcePermissionTypeCompactView(
              permission: details.permission
            )
            DisclosureIndicatorImage()
          }
        }
      )
      .padding(
        top: 8,
        bottom: 8
      )
      .frame(height: 64)

    case let .userGroup(details):
      CommonListRow(
        contentAction: self.action,
        content: {
          HStack(spacing: 8) {
            UserGroupAvatarView()
              .frame(
                width: 40,
                height: 40
              )

            Text("\(details.name)")
              .text(
                font: .inter(
                  ofSize: 14,
                  weight: .semibold
                ),
                color: .passboltPrimaryText
              )
          }
        },
        accessory: {
          HStack(spacing: 4) {
            ResourcePermissionTypeCompactView(
              permission: details.permission
            )
            DisclosureIndicatorImage()
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
}

#if DEBUG

internal struct PermissionListRowView_Previews: PreviewProvider {

  internal static var previews: some View {
    PermissionListRowView(
      .userGroup(
        details: .init(
          id: .init(),
          name: "User group",
          permission: .read,
          members: []
        )
      ),
      action: {}
    )
  }
}
#endif
