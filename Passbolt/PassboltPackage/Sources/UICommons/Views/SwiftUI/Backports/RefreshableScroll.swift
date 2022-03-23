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

#warning("TODO: to remove after bumping minimum iOS version to 15")
private struct RefreshableScrollView<Content>: View
where Content: View {

  @State var isRefreshing: Bool = false
  @State var isRefreshingLocked: Bool = false
  @State private var refreshTask: RecurringTask = .init()
  private let content: Content

  fileprivate init(
    action: @Sendable @escaping () async -> Void,
    content: Content
  ) {
    self.content = content
    self.refreshTask = .init(
      priority: .userInitiated,
      operation: action
    )
  }

  fileprivate var body: some View {
    ZStack(alignment: .top) {
      if self.isRefreshing {
        SwiftUI.ProgressView()
          .padding(4)
          .frame(maxWidth: .infinity, alignment: .top)
      }
      GeometryReader { geometry in
        ScrollView {
          content
            .anchorPreference(
              key: OffsetPreferenceKey.self,
              value: .top
            ) { anchor in
              geometry[anchor].y
            }
            .padding(
              top: self.isRefreshing
                ? 38
                : 0
            )
        }
        .onPreferenceChange(OffsetPreferenceKey.self) { offset in
          if !self.isRefreshingLocked, offset > 38 {
            self.isRefreshingLocked = true
            withAnimation {
              self.isRefreshing = true
            }
            Task { @MainActor in
              await self.refreshTask.run(
                replacingCurrent: false
              )
              withAnimation {
                self.isRefreshing = false
              }
            }
          }
          else if self.isRefreshingLocked, !self.isRefreshing, offset <= 0 {
            self.isRefreshingLocked = false
          }
          else {
            /* NOP */
          }
        }
      }
    }
  }
}

private struct OffsetPreferenceKey: PreferenceKey {

  fileprivate static var defaultValue: CGFloat = 0

  fileprivate static func reduce(
    value: inout CGFloat,
    nextValue: () -> CGFloat
  ) {
    value = nextValue()
  }
}

extension Backport where Content == Never {

  #warning("TODO: to remove after bumping minimum iOS version to 15")
  // swift-format-ignore: AlwaysUseLowerCamelCase
  @ViewBuilder public static func RefreshableList<ListContentView>(
    refresh action: @Sendable @escaping () async -> Void,
    @ViewBuilder listContent: @escaping () -> ListContentView
  ) -> some View
  where ListContentView: View {
    if #available(iOS 15.0, *) {
      SwiftUI.List(content: listContent)
        .listStyle(.plain)
        .environment(\.defaultMinListRowHeight, 20)
        .refreshable(action: action)
    }
    else {
      RefreshableScrollView(
        action: action,
        content: LazyVStack(spacing: 0) {
          listContent()
        }
      )
    }
  }
}

extension Backport where Content == Never {

  #warning("TODO: to remove after bumping minimum iOS version to 15")
  // swift-format-ignore: AlwaysUseLowerCamelCase
  @ViewBuilder public static func List<ListContentView>(
    @ViewBuilder listContent: @escaping () -> ListContentView
  ) -> some View
  where ListContentView: View {
    if #available(iOS 15.0, *) {
      SwiftUI.List(content: listContent)
        .listStyle(.plain)
        .environment(\.defaultMinListRowHeight, 20)
    }
    else {
      ScrollView {
        LazyVStack(spacing: 0) {
          listContent()
        }
      }
    }
  }
}
