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
  private let chevronVisible: Bool
  private let leftAccessory: () -> LeftAccessoryView
  private let content: () -> ContentView
  private let rightAccessory: () -> RightAccessoryView

  public init(
    action: @Sendable @escaping () async -> Void,
    chevronVisible: Bool = false,
    @ViewBuilder leftAccessory: @escaping () -> LeftAccessoryView,
    @ViewBuilder content: @escaping () -> ContentView,
    @ViewBuilder rightAccessory: @escaping () -> RightAccessoryView
  ) {
    self.action = action
    self.chevronVisible = chevronVisible
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
        .padding(
          leading: 4
        )

      if self.chevronVisible {
        Image(named: .chevronRight)
          .resizable()
          .aspectRatio(1, contentMode: .fit)
          .padding(
            top: 12,
            leading: 4,
            bottom: 12,
            trailing: 0
          )
      }  // else { /* NOP */ }
    }
    .foregroundColor(Color.passboltPrimaryText)
    .padding(top: 12, leading: 16, bottom: 12, trailing: 16)
    .frame(height: 64)
    .frame(maxWidth: .infinity)
    .listRowSeparator(.hidden)
    .listRowInsets(EdgeInsets())
    .buttonStyle(.plain)
  }
}

extension ListRowView
where LeftAccessoryView == EmptyView {

  public init(
    action: @Sendable @escaping () async -> Void,
    chevronVisible: Bool = false,
    @ViewBuilder content: @escaping () -> ContentView,
    @ViewBuilder rightAccessory: @escaping () -> RightAccessoryView
  ) {
    self.action = action
    self.chevronVisible = chevronVisible
    self.leftAccessory = EmptyView.init
    self.content = content
    self.rightAccessory = rightAccessory
  }
}

extension ListRowView
where RightAccessoryView == EmptyView {

  public init(
    action: @Sendable @escaping () async -> Void,
    chevronVisible: Bool = false,
    @ViewBuilder leftAccessory: @escaping () -> LeftAccessoryView,
    @ViewBuilder content: @escaping () -> ContentView
  ) {
    self.action = action
    self.chevronVisible = chevronVisible
    self.leftAccessory = leftAccessory
    self.content = content
    self.rightAccessory = EmptyView.init
  }
}

extension ListRowView
where LeftAccessoryView == EmptyView, RightAccessoryView == EmptyView {

  public init(
    action: @Sendable @escaping () async -> Void,
    chevronVisible: Bool = false,
    @ViewBuilder content: @escaping () -> ContentView
  ) {
    self.action = action
    self.chevronVisible = chevronVisible
    self.leftAccessory = EmptyView.init
    self.content = content
    self.rightAccessory = EmptyView.init
  }
}

extension ListRowView
where ContentView == ListRowTitleView {

  public init(
    action: @Sendable @escaping () async -> Void,
    chevronVisible: Bool = false,
    @ViewBuilder leftAccessory: @escaping () -> LeftAccessoryView,
    title: DisplayableString,
    @ViewBuilder rightAccessory: @escaping () -> RightAccessoryView
  ) {
    self.action = action
    self.chevronVisible = chevronVisible
    self.leftAccessory = leftAccessory
    self.content = {
      ListRowTitleView(title: title)
    }
    self.rightAccessory = rightAccessory
  }
}

extension ListRowView
where ContentView == ListRowTitleView, RightAccessoryView == EmptyView {

  public init(
    action: @Sendable @escaping () async -> Void,
    chevronVisible: Bool = false,
    @ViewBuilder leftAccessory: @escaping () -> LeftAccessoryView,
    title: DisplayableString
  ) {
    self.action = action
    self.chevronVisible = chevronVisible
    self.leftAccessory = leftAccessory
    self.content = {
      ListRowTitleView(title: title)
    }
    self.rightAccessory = EmptyView.init
  }
}

extension ListRowView
where ContentView == ListRowTitleWithSubtitleView {
  public init(
    action: @Sendable @escaping () async -> Void,
    chevronVisible: Bool = false,
    @ViewBuilder leftAccessory: @escaping () -> LeftAccessoryView,
    title: DisplayableString,
    subtitle: DisplayableString,
    @ViewBuilder rightAccessory: @escaping () -> RightAccessoryView
  ) {
    self.action = action
    self.chevronVisible = chevronVisible
    self.leftAccessory = leftAccessory
    self.content = {
      ListRowTitleWithSubtitleView(
        title: title,
        subtitle: subtitle
      )
    }
    self.rightAccessory = rightAccessory
  }
}

extension ListRowView
where ContentView == ListRowTitleWithSubtitleView, RightAccessoryView == EmptyView {

  public init(
    action: @Sendable @escaping () async -> Void,
    chevronVisible: Bool = false,
    @ViewBuilder leftAccessory: @escaping () -> LeftAccessoryView,
    title: DisplayableString,
    subtitle: DisplayableString
  ) {
    self.action = action
    self.chevronVisible = chevronVisible
    self.leftAccessory = leftAccessory
    self.content = {
      ListRowTitleWithSubtitleView(
        title: title,
        subtitle: subtitle
      )
    }
    self.rightAccessory = EmptyView.init
  }
}

#if DEBUG

internal struct ListRowView_Previews: PreviewProvider {

  internal static var previews: some View {
    ListRowView(
      action: {
        // main action
      },
      chevronVisible: true,
      leftAccessory: {
        Image(named: .plus)
          .resizable()
          .aspectRatio(1, contentMode: .fit)
          .padding(8)
          .backgroundColor(.passboltPrimaryBlue)
          .foregroundColor(Color.passboltPrimaryButtonText)
          .cornerRadius(8)
      },
      title: "Content title",
      rightAccessory: {
        AsyncButton(
          action: {
            // accessory action
          },
          label: {
            Image(named: .more)
              .resizable()
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
