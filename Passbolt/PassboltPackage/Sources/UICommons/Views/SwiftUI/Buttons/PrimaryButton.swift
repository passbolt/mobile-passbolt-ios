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

public struct PrimaryButton: View {

  private let icon: Image?
  private let title: DisplayableString
  private let style: Style
  private let action: @MainActor () async throws -> Void

  public init(
    title: DisplayableString,
    iconName: ImageNameConstant? = .none,
    style: Style = .regular,
    action: @escaping @MainActor () async throws -> Void
  ) {
    self.icon = iconName.map(Image.init(named:))
    self.title = title
    self.style = style
    self.action = action
  }

  public var body: some View {
    AsyncButton(
      action: self.action,
      regularLabel: {
        self.regularLabelView
      },
      loadingLabel: {
        self.loadingLabelView
      }
    )
    .foregroundColor(.passboltPrimaryButtonText)
    .backgroundColor(self.style.backgroundColor)
    .frame(height: 56)
    .cornerRadius(4)
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

  @MainActor @ViewBuilder private var regularLabelView: some View {
    if let icon: Image = self.icon {
      HStack(spacing: 8) {
        icon
          .resizable()
          .frame(width: 20, height: 20)
        self.titleView
      }
      .frame(
        maxWidth: .infinity,
        maxHeight: .infinity
      )
      .padding(8)
    }
    else {
      self.titleView
        .frame(
          maxWidth: .infinity,
          maxHeight: .infinity
        )
        .padding(8)
    }
  }

  @MainActor @ViewBuilder private var loadingLabelView: some View {
    HStack(spacing: 8) {
      SwiftUI.ProgressView()
        .progressViewStyle(.circular)
        .tint(.passboltPrimaryButtonText)
        .frame(width: 20, height: 20)
      self.titleView
    }
    .frame(
      maxWidth: .infinity,
      maxHeight: .infinity
    )
    .padding(8)
  }
}

extension PrimaryButton {

  public enum Style {

    case regular
    case destructive
  }
}

extension PrimaryButton.Style {

  fileprivate var backgroundColor: Color {
    switch self {
    case .regular:
      return .passboltPrimaryBlue

    case .destructive:
      return .passboltSecondaryRed
    }
  }
}

#if DEBUG

internal struct PrimaryButton_Previews: PreviewProvider {

  internal static var previews: some View {
    PrimaryButton(
      title: "Primary button",
      action: {
        print("TAP")
        try? await Task.sleep(nanoseconds: 1500 * NSEC_PER_MSEC)
      }
    )
    .padding()
  }
}
#endif
