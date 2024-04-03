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

import Commons
import SwiftUI

@MainActor
public struct ResourceUserGroupListItemView: View {

  private let name: String
  private let contentCount: Int
  private let action: @MainActor () async throws -> Void

  public init(
    name: String,
    contentCount: Int,
    action: @escaping @MainActor () async throws -> Void
  ) {
    self.name = name
    self.contentCount = contentCount
    self.action = action
  }

  public var body: some View {
    ListRowView(
      chevronVisible: true,
      leftAccessory: {
        Image(
          named: .userGroupIcon
        )
        .frame(
          width: 40,
          height: 40,
          alignment: .center
        )
      },
      contentAction: self.action,
      content: {
        Text(self.name)
          .font(.inter(ofSize: 14, weight: .semibold))
          .foregroundColor(Color.passboltPrimaryText)
      },
      rightAccessory: {
        Text("\(self.contentCount)")
          .text(
            font: .inter(
              ofSize: 14,
              weight: .regular
            ),
            color: .passboltPrimaryText
          )
      }
    )
  }
}

#if DEBUG

internal struct ResourceUserGroupListItemView_Previews: PreviewProvider {

  internal static var previews: some View {
    ResourceUserGroupListItemView(
      name: "UserGroup",
      contentCount: 0,
      action: {
        // action
      }
    )
  }
}
#endif
