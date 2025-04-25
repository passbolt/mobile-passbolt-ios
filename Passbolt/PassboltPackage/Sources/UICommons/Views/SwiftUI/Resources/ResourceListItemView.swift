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
  private let isExpired: Bool
  private let contentAction: @MainActor () async throws -> Void
  private let rightAction: (@MainActor () async throws -> Void)?
  private let rightAccessory: () -> AccessoryView

  public init(
    name: String,
    username: String?,
    isExpired: Bool,
    contentAction: @escaping @MainActor () async throws -> Void,
    rightAction: (@MainActor () async throws -> Void)? = .none,
    @ViewBuilder rightAccessory: @escaping () -> AccessoryView
  ) {
    self.name = name
    self.username = (username?.isEmpty ?? true) ? nil : username
    self.isExpired = isExpired
    self.contentAction = contentAction
    self.rightAction = rightAction
    self.rightAccessory = rightAccessory
  }

  public var body: some View {
    ListRowView(
      leftAccessory: {
        ZStack(alignment: .bottomTrailing) {
          LetterIconView(text: self.name)
            .frame(
              width: 40,
              height: 40,
              alignment: .center
            )
          if isExpired == true {
            Image(named: .exclamationMark)
              .resizable()
              .frame(
                width: 12,
                height: 12
              )
              .alignmentGuide(.trailing) { dim in
                dim[HorizontalAlignment.center] + 2
              }
              .alignmentGuide(.bottom) { dim in
                dim[VerticalAlignment.center] + 2
              }
          }
        }
      },
      contentAction: self.contentAction,
      content: {
        VStack(alignment: .leading, spacing: 4) {
          HStack(spacing: 4) {
            Text(name)
              .font(.inter(ofSize: 14, weight: .semibold))
              .foregroundColor(Color.passboltPrimaryText)
            if isExpired {
              Text(displayable: "resource.expiry.expired")
                .font(.inter(ofSize: 14, weight: .regular))
                .foregroundColor(Color.passboltPrimaryText)
            }
          }

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
      rightAction: self.rightAction,
      rightAccessory: self.rightAccessory
    )
  }
}

#if DEBUG

internal struct ResourceListItemView_Previews: PreviewProvider {

  internal static var previews: some View {
    ResourceListItemView(
      name: "Resource",
      username: "username",
      isExpired: true,
      contentAction: {
        // action
      },
      rightAccessory: EmptyView.init
    )
  }
}
#endif
