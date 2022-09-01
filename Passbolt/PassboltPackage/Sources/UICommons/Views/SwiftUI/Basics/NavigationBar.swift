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
import Localization
import SwiftUI

public struct NavigationBar<TitleView, ExtensionView, LeadingItem, TrailingItem>: View
where TitleView: View, ExtensionView: View, LeadingItem: View, TrailingItem: View {

  @Environment(\.isInNavigationTreeContext) var isInNavigationTreeContext: Bool
  private let barShadow: Bool
  private let titleView: () -> TitleView
  private let extensionView: () -> ExtensionView
  private let leadingItem: () -> LeadingItem
  private let trailingItem: () -> TrailingItem

  public init(
    barShadow: Bool = false,
    @ViewBuilder titleView: @escaping () -> TitleView,
    @ViewBuilder extensionView: @escaping () -> ExtensionView,
    @ViewBuilder leadingItem: @escaping () -> LeadingItem,
    @ViewBuilder trailingItem: @escaping () -> TrailingItem
  ) {
    self.barShadow = barShadow
    self.titleView = titleView
    self.extensionView = extensionView
    self.leadingItem = leadingItem
    self.trailingItem = trailingItem
  }

  public init(
    barShadow: Bool = false,
    backAction: (() -> Void)? = .none,
    @ViewBuilder titleView: @escaping () -> TitleView,
    @ViewBuilder leadingItem: @escaping () -> LeadingItem,
    @ViewBuilder trailingItem: @escaping () -> TrailingItem
  ) where ExtensionView == EmptyView {
    self.barShadow = barShadow
    self.titleView = titleView
    self.extensionView = EmptyView.init
    self.leadingItem = leadingItem
    self.trailingItem = trailingItem
  }

  public var body: some View {
    ZStack(alignment: .top) {
      if self.barShadow {
        Rectangle()
          .fill(Color.passboltBackground)
          .shadow(
            color: .black.opacity(0.2),
            radius: 12,
            x: 0,
            y: -10
          )
          .ignoresSafeArea(.container, edges: [.top, .leading, .trailing])
      }
      else {
        Rectangle()
          .fill(Color.passboltBackground)
          .ignoresSafeArea(.container, edges: [.top, .leading, .trailing])
      }
      VStack(spacing: 0) {
        // ignore bar buttons out of navigationtree
        // it will be inaccesible anyway
        if self.isInNavigationTreeContext {
          HStack {
            self.leadingItem()
              .frame(
                minWidth: 24,
                idealWidth: 40,
                maxWidth: 40,
                maxHeight: 40
              )
            Spacer()
            self.titleView()
              .frame(maxWidth: .infinity)
              .frame(height: 40)
            Spacer()
            self.trailingItem()
              .frame(
                minWidth: 24,
                idealWidth: 40,
                maxWidth: 40,
                maxHeight: 40
              )
          }
          .frame(height: 40)
          .padding(top: 8)
        }
        else {
          self.titleView()
            .frame(maxWidth: .infinity)
            .frame(height: 40)
            .padding(
              top: 8,
              leading: 24,
              trailing: 24
            )
        }

        self.extensionView()
      }
      .padding(
        // hide under navigation bar without NavigationTree
        top: isInNavigationTreeContext ? 0 : -52,
        leading: 8,
        trailing: 8
      )
    }
    .fixedSize(
      horizontal: false,
      vertical: true
    )
    // ensure being on top
    .zIndex(.greatestFiniteMagnitude)
    .navigationBarHidden(isInNavigationTreeContext)
  }
}
