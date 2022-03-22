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
public struct ResourceListItemView<AccessoryView>: View where AccessoryView: View {

  private let name: String
  private let username: String?
  private let action: () async -> Void
  private let accessory: () -> AccessoryView

  public init(
    name: String,
    username: String?,
    action: @escaping () async -> Void,
    @ViewBuilder accessory: @escaping () -> AccessoryView
  ) {
    self.name = name
    self.username = (username?.isEmpty ?? true) ? nil : username
    self.action = action
    self.accessory = accessory
  }

  public var body: some View {
    ListRowView(
      action: {
        await self.action()
      },
      leftAccessory: {
        LetterIconView(text: self.name)
          .frame(
            width: 40,
            height: 40,
            alignment: .center
          )
      },
      content: {
        VStack(alignment: .leading, spacing: 4) {
          Text(name)
            .font(.inter(ofSize: 14, weight: .semibold))
            .foregroundColor(Color.passboltPrimaryText)
          Text(
            self.username
              ?? DisplayableString
              .localized(key: "resource.list.username.empty.placeholder")
              .string()
          )
          .font(
            self.username == nil
              ? .interItalic(ofSize: 12, weight: .regular)
              : .inter(ofSize: 12, weight: .regular)

          )
          .foregroundColor(Color.passboltSecondaryText)
        }
      },
      rightAccessory: self.accessory
    )
  }
}

#if DEBUG

internal struct ResourceListItemView_Previews: PreviewProvider {

  internal static var previews: some View {
    ResourceListItemView(
      name: "Resource",
      username: "username",
      action: {
        // action
      },
      accessory: EmptyView.init
    )
  }
}
#endif
