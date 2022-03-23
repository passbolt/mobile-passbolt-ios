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
public struct ListRowView<LeftAccessoryView, ContentView, RightAccessoryView>: View
where LeftAccessoryView: View, ContentView: View, RightAccessoryView: View {

  private let action: @Sendable () async -> Void
  private let leftAccessory: () -> LeftAccessoryView
  private let content: () -> ContentView
  private let rightAccessory: () -> RightAccessoryView

  public init(
    action: @Sendable @escaping () async -> Void,
    @ViewBuilder leftAccessory: @escaping () -> LeftAccessoryView,
    @ViewBuilder content: @escaping () -> ContentView,
    @ViewBuilder rightAccessory: @escaping () -> RightAccessoryView
  ) {
    self.action = action
    self.leftAccessory = leftAccessory
    self.content = content
    self.rightAccessory = rightAccessory
  }

  public var body: some View {
    HStack(spacing: 0) {
      AsyncButton(
        action: self.action,
        label: {
          HStack(spacing: 0) {
            self.leftAccessory()
              .frame(maxWidth: 52, maxHeight: 52, alignment: .leading)
            self.content()
              .frame(maxWidth: .infinity, maxHeight: 52, alignment: .leading)
          }
          .frame(maxWidth: .infinity, alignment: .leading)
          .contentShape(Rectangle())
        }
      )

      self.rightAccessory()
    }
    .foregroundColor(Color.passboltPrimaryText)
    .padding(top: 12, leading: 16, bottom: 12, trailing: 16)
    .frame(height: 64)
    .frame(maxWidth: .infinity)
  }
}

#if DEBUG

internal struct ListRowView_Previews: PreviewProvider {

  internal static var previews: some View {
    ListRowView(
      action: {
        // main action
      },
      leftAccessory: {
        Image(named: .plus)
          .aspectRatio(1, contentMode: .fit)
          .padding(8)
          .background(Color.passboltPrimaryBlue)
          .foregroundColor(Color.passboltPrimaryButtonText)
          .cornerRadius(8)
      },
      content: {
        Text("Content title")
      },
      rightAccessory: {
        AsyncButton(
          action: {
            // accessory action
          },
          label: {
            Image(named: .more)
              .aspectRatio(1, contentMode: .fit)
              .padding(8)
              .foregroundColor(Color.passboltIcon)
              .cornerRadius(8)
          }
        )
        .cornerRadius(8)
      }
    )
  }
}
#endif
