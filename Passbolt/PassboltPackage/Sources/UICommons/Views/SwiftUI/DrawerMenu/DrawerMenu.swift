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

public struct DrawerMenu<TitleView, ContentView>: View
where TitleView: View, ContentView: View {

  private let title: () -> TitleView
  private let content: () -> ContentView
  private let closeTap: @MainActor () async -> Void

  public init(
    closeTap: @escaping @MainActor () async -> Void,
    @ViewBuilder title: @escaping () -> TitleView,
    @ViewBuilder content: @escaping () -> ContentView
  ) {
    self.closeTap = closeTap
    self.title = title
    self.content = content
  }

  public var body: some View {
    VStack(spacing: 0) {
      HStack {
        title()
          .frame(
            maxWidth: .infinity,
            alignment: .leading
          )
          .frame(height: 24)

        AsyncButton(
          action: self.closeTap,
          regularLabel: {
            Image(named: .close)
              .resizable()
              .frame(
                width: 24,
                height: 24
              )
          }
        )
      }
      .text(
        font: .inter(
          ofSize: 20,
          weight: .semibold
        ),
        color: .passboltPrimaryText
      )
      .padding(
        EdgeInsets(
          top: 16,
          leading: 16,
          bottom: 16,
          trailing: 16
        )
      )

      ListDividerView()
        .padding(
          top: 0,
          leading: 8,
          bottom: 0,
          trailing: 8
        )

      ScrollView {
        self.content()
          .padding(
            top: 8,
            leading: 8,
            bottom: 0,
            trailing: 8
          )
      }
    }
    .backgroundColor(.passboltSheetBackground)
  }
}

#if DEBUG

internal struct DrawerMenu_Previews: PreviewProvider {

  internal static var previews: some View {
    DrawerMenu(
      closeTap: {
        // close
      },
      title: {
        Text("Drawer menu")
      },
      content: {
        VStack(spacing: 0) {
          DrawerMenuItemView(
            action: {},
            title: {
              Text("Item 1")
            },
            leftIcon: {
              Image(named: .dice)
                .resizable()
            },
            isSelected: false
          )

          DrawerMenuItemView(
            action: {},
            title: {
              Text("Item 2")
            },
            leftIcon: {
              Image(named: .biometricsIcon)
                .resizable()
            },
            isSelected: true
          )

          DrawerMenuItemView(
            action: {},
            title: {
              Text("Item 3")
            },
            leftIcon: {
              Image(named: .lockedLock)
                .resizable()
                .padding(2)
            },
            isSelected: false
          )

          ListDividerView()
            .padding(
              EdgeInsets(
                top: 8,
                leading: 0,
                bottom: 8,
                trailing: 0
              )
            )
          DrawerMenuItemView(
            action: {},
            title: {
              Text("Item 4")
            },
            leftIcon: {
              Image(named: .bug)
                .resizable()
            },
            rightIcon: {
              Image(named: .link)
                .resizable()
            },
            isSelected: false
          )

          ForEach((0 ... 10), id: \.self) { _ in
            DrawerMenuItemView(
              action: {},
              title: {
                Text("Item x")
              },
              leftIcon: {
                Image(named: .bug)
                  .resizable()
              },
              rightIcon: {
                Image(named: .link)
                  .resizable()
              },
              isSelected: false
            )
          }
        }
      }
    )
  }
}
#endif
