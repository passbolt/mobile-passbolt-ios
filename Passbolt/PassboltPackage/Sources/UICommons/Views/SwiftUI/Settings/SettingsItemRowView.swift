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

public struct SettingsItemRowView<Accessory>: View
where Accessory: View {

  private let iconName: ImageNameConstant
  private let title: DisplayableString
  private let accessory: () -> Accessory

  public init(
    icon: ImageNameConstant,
    title: DisplayableString,
    @ViewBuilder accessory: @escaping () -> Accessory
  ) {
    self.iconName = icon
    self.title = title
    self.accessory = accessory
  }

  public var body: some View {
    CommonListRow(
      content: {
        HStack(spacing: 12) {
          Image(named: self.iconName)
            .frame(
              width: 24,
              height: 24
            )

          Text(displayable: self.title)
            .frame(
              maxWidth: .infinity,
              alignment: .leading
            )
            .multilineTextAlignment(.leading)
        }
        .font(
          .inter(
            ofSize: 14,
            weight: .semibold
          )
        )
        .frame(height: 64)
      },
      accessory: self.accessory
    )
  }
}

#if DEBUG

internal struct SettingsItemRowView_Previews: PreviewProvider {

  internal static var previews: some View {
    SettingsItemRowView(
      icon: .bug,
      title: "Preview item",
      accessory: EmptyView.init
    )
  }
}
#endif
