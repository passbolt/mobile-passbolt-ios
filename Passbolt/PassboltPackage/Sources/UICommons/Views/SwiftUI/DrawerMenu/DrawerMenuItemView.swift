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

public struct DrawerMenuItemView<TitleView, LeftIconView, RightIconView>: View
where TitleView: View, LeftIconView: View, RightIconView: View {

  private let action: @Sendable () async -> Void
  private let title: () -> TitleView
  private let leftIcon: () -> LeftIconView
  private let rightIcon: () -> RightIconView
  private let isSelected: Bool

  public init(
    @_inheritActorContext action: @escaping @Sendable () async -> Void,
    @ViewBuilder title: @escaping () -> TitleView,
    @ViewBuilder leftIcon: @escaping () -> LeftIconView,
    @ViewBuilder rightIcon: @escaping () -> RightIconView,
    isSelected: Bool
  ) {
    self.action = action
    self.title = title
    self.leftIcon = leftIcon
    self.rightIcon = rightIcon
    self.isSelected = isSelected
  }

  public init(
    action: @escaping @Sendable () async -> Void,
    @ViewBuilder title: @escaping () -> TitleView,
    @ViewBuilder leftIcon: @escaping () -> LeftIconView,
    isSelected: Bool = false
  ) where RightIconView == EmptyView {
    self.action = action
    self.title = title
    self.leftIcon = leftIcon
    self.rightIcon = EmptyView.init
    self.isSelected = isSelected
  }

  public var body: some View {
    AsyncButton(
      action: self.action,
      regularLabel: {
        HStack {
          self.leftIcon()
            .frame(maxWidth: 24, maxHeight: 24)
          self.title()
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding([.leading, .trailing], 8)
          self.rightIcon()
            .frame(maxWidth: 24, maxHeight: 24)
        }
      },
			loadingLabel: {
				HStack {
					SwiftUI.ProgressView()
						.progressViewStyle(.circular)
						.tint(
							self.isSelected
							? Color.passboltPrimaryTextInverted
							: Color.passboltPrimaryText
						)
						.frame(maxWidth: 24, maxHeight: 24)
					self.title()
						.frame(maxWidth: .infinity, alignment: .leading)
						.padding([.leading, .trailing], 8)
					self.rightIcon()
						.frame(maxWidth: 24, maxHeight: 24)
				}
			}
    )
    .padding(
      EdgeInsets(
        top: 8,
        leading: 16,
        bottom: 8,
        trailing: 16
      )
    )
    .frame(height: 40)
    .background(
      self.isSelected
        ? Color.passboltPrimaryBlue
        : Color.clear
    )
    .foregroundColor(
      self.isSelected
        ? Color.passboltPrimaryTextInverted
        : Color.passboltPrimaryText
    )
    .font(
      .inter(
        ofSize: 14,
        weight: .semibold
      )
    )
    .cornerRadius(3)
    .padding(
      EdgeInsets(
        top: 8,
        leading: 0,
        bottom: 8,
        trailing: 0
      )
    )
  }
}

#if DEBUG

internal struct DrawerMenuItemView_Previews: PreviewProvider {

  internal static var previews: some View {
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
    }
    .padding(8)
  }
}
#endif
