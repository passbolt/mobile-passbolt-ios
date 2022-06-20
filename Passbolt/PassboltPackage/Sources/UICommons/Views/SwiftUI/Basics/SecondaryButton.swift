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

import AegithalosCocoa
import Commons
import SwiftUI

@MainActor
public struct SecondaryButton: View {

  private let icon: Image?
  private let title: DisplayableString
  private let action: @Sendable () async -> Void

  public init(
    title: DisplayableString,
    iconName: ImageNameConstant? = .none,
    action: @Sendable @escaping () async -> Void
  ) {
    self.icon = iconName.map(Image.init(named:))
    self.title = title
    self.action = action
  }

  public var body: some View {
    AsyncButton(
      action: self.action,
      label: {
        if let icon: Image = self.icon {
          HStack(spacing: 0) {
            icon
              .resizable()
              .frame(width: 20, height: 20)
              .padding(8)
            self.titleView
          }
        }
        else {
          self.titleView
        }
      }
    )
    .contentShape(Rectangle())
    .padding(8)
    .frame(height: 56)
    .foregroundColor(.passboltPrimaryText)
    .backgroundColor(.clear)
  }

  private var titleView: some View {
    Text(displayable: title)
      .font(
        .inter(
          ofSize: 14,
          weight: .medium
        )
      )
  }
}