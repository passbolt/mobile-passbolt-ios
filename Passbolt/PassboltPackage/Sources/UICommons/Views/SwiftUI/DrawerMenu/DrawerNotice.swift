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

public struct DrawerNotice<ActionsView>: View
where ActionsView: View {

  private let title: DisplayableString
  private let icon: ImageNameConstant?
  private let iconColor: Color
  private let paragraphs: Array<DisplayableString>
  private let actions: () -> ActionsView

  public init(
    title: DisplayableString,
    icon: ImageNameConstant? = .none,
    iconColor: Color = .passboltWarningOrange,
    paragraphs: Array<DisplayableString>,
    @ViewBuilder actions: @escaping () -> ActionsView
  ) {
    self.title = title
    self.icon = icon
    self.iconColor = iconColor
    self.paragraphs = paragraphs
    self.actions = actions
  }

  public var body: some View {
    VStack(
      alignment: .leading,
      spacing: 0
    ) {
      Text(displayable: self.title)
        .font(
          .inter(
            ofSize: 20,
            weight: .semibold
          )
        )
        .foregroundStyle(Color.passboltPrimaryText)
        .frame(
          maxWidth: .infinity,
          alignment: .leading
        )

      ListDividerView()
        .padding(
          top: 8,
          bottom: 8
        )

      if let icon: ImageNameConstant = self.icon {
        Image(named: icon)
          .renderingMode(.template)
          .resizable()
          .scaledToFit()
          .frame(
            width: 140,
            height: 140
          )
          .foregroundStyle(self.iconColor)
          .frame(
            maxWidth: .infinity,
            alignment: .center
          )
          .padding(.bottom, 16)
      }  // else - no icon

      VStack(
        alignment: .leading,
        spacing: 12
      ) {
        ForEach(
          Array(self.paragraphs.enumerated()),
          id: \.offset
        ) { (paragraph: (offset: Int, element: DisplayableString)) in
          Text(
            localizedMarkdown: paragraph.element,
            size: 14,
            color: .passboltSecondaryText
          )
          .fixedSize(horizontal: false, vertical: true)
          .frame(
            maxWidth: .infinity,
            alignment: .leading
          )
        }
      }
      .padding(.bottom, 24)

      VStack(spacing: 8) {
        self.actions()
      }
    }
    .multilineTextAlignment(.leading)
    .padding(
      top: 32,
      leading: 20,
      bottom: 16,
      trailing: 20
    )
    .backgroundColor(.passboltSheetBackground)
  }
}

#if DEBUG

internal struct DrawerNotice_Previews: PreviewProvider {

  internal static var previews: some View {
    DrawerNotice(
      title: .raw("Outdated iOS version"),
      icon: .startupWarning,
      paragraphs: [
        .raw(
          "Your device runs an iOS version that no longer receives updates. Passbolt support for this version is scheduled to be phased out."
        ),
        .raw(
          "To stay protected and keep receiving Passbolt updates **update your device to a newer iOS version**."
        ),
      ],
      actions: {
        PrimaryButton(
          title: .raw("I understand"),
          action: {}
        )
        SecondaryButton(
          title: .raw("Don't show again"),
          action: {}
        )
      }
    )
  }
}
#endif
