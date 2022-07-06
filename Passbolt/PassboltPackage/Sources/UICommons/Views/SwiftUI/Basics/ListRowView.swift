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

  private let chevronVisible: Bool
  private let leftAction: (@MainActor () -> Void)?
  private let leftAccessory: () -> LeftAccessoryView
  private let contentAction: @MainActor () -> Void
  private let content: () -> ContentView
  private let rightAction: (@MainActor () -> Void)?
  private let rightAccessory: () -> RightAccessoryView

  public init(
    chevronVisible: Bool = false,
    leftAction: (@MainActor () -> Void)? = .none,
    @ViewBuilder leftAccessory: @escaping () -> LeftAccessoryView,
    contentAction: @escaping @MainActor () -> Void,
    @ViewBuilder content: @escaping () -> ContentView,
    rightAction: (@MainActor () -> Void)? = .none,
    @ViewBuilder rightAccessory: @escaping () -> RightAccessoryView
  ) {
    self.chevronVisible = chevronVisible
    self.leftAction = leftAction
    self.leftAccessory = leftAccessory
    self.contentAction = contentAction
    self.content = content
    self.rightAction = rightAction
    self.rightAccessory = rightAccessory
  }

  public var body: some View {
    HStack(spacing: 0) {
      if let leftAction: @MainActor () -> Void = self.leftAction {
        Button(
          action: {
            MainActor.execute(priority: .userInitiated) {
              leftAction()
            }
          },
          label: {
            self.leftAccessory()
              .frame(
                maxHeight: 52,
                alignment: .leading
              )
              .contentShape(
                .interaction,
                Rectangle()
              )
          }
        )

        if let rightAction: @MainActor () -> Void = self.rightAction {
          Button(
            action: {
              MainActor.execute(priority: .userInitiated) {
                self.contentAction()
              }
            },
            label: {
              self.content()
                .frame(
                  maxWidth: .infinity,
                  maxHeight: 52,
                  alignment: .leading
                )
                .frame(maxWidth: .infinity)
                .contentShape(
                  .interaction,
                  Rectangle()
                )
            }
          )

          Button(
            action: {
              MainActor.execute(priority: .userInitiated) {
                rightAction()
              }
            },
            label: {
              self.rightAccessory()
                .frame(
                  maxHeight: 52,
                  alignment: .trailing
                )
            }
          )
          .contentShape(
            .interaction,
            Rectangle()
          )
        }
        else {
          Button(
            action: {
              MainActor.execute(priority: .userInitiated) {
                self.contentAction()
              }
            },
            label: {
              HStack(spacing: 0) {
                self.content()
                  .frame(
                    maxWidth: .infinity,
                    maxHeight: 52,
                    alignment: .leading
                  )

                self.rightAccessory()
                  .frame(
                    maxHeight: 52,
                    alignment: .trailing
                  )
              }
              .frame(maxWidth: .infinity)
              .contentShape(
                .interaction,
                Rectangle()
              )
            }
          )
        }
      }
      else if let rightAction: @MainActor () -> Void = self.rightAction {
        Button(
          action: {
            MainActor.execute(priority: .userInitiated) {
              self.contentAction()
            }
          },
          label: {
            HStack(spacing: 0) {
              self.leftAccessory()
                .frame(
                  maxHeight: 52,
                  alignment: .leading
                )

              self.content()
                .frame(
                  maxWidth: .infinity,
                  maxHeight: 52,
                  alignment: .leading
                )
                .padding(
                  leading: 8,
                  trailing: 8
                )
            }
            .frame(maxWidth: .infinity)
            .contentShape(
              .interaction,
              Rectangle()
            )
          }
        )

        Button(
          action: {
            MainActor.execute(priority: .userInitiated) {
              rightAction()
            }
          },
          label: {
            self.rightAccessory()
              .frame(
                maxHeight: 52,
                alignment: .trailing
              )
          }
        )
        .contentShape(
          .interaction,
          Rectangle()
        )
      }
      else {
        Button(
          action: {
            MainActor.execute(priority: .userInitiated) {
              self.contentAction()
            }
          },
          label: {
            HStack(spacing: 0) {
              self.leftAccessory()
                .frame(
                  maxHeight: 52,
                  alignment: .leading
                )

              self.content()
                .frame(
                  maxWidth: .infinity,
                  maxHeight: 52,
                  alignment: .leading
                )
                .padding(
                  leading: 8,
                  trailing: 8
                )

              self.rightAccessory()
                .frame(
                  maxHeight: 52,
                  alignment: .trailing
                )
            }
            .frame(maxWidth: .infinity)
            .contentShape(
              .interaction,
              Rectangle()
            )
          }
        )
      }

      if self.chevronVisible {
        Image(named: .chevronRight)
          .frame(
            maxHeight: 52,
            alignment: .trailing
          )
          .padding(
            top: 12,
            bottom: 12,
            trailing: 0
          )
      }  // else { /* NOP */ }
    }
    .foregroundColor(.passboltPrimaryText)
    .padding(
      top: 12,
      leading: 16,
      bottom: 12,
      trailing: 16
    )
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
    chevronVisible: Bool = false,
    contentAction: @escaping @MainActor () -> Void,
    @ViewBuilder content: @escaping () -> ContentView,
    rightAction: (@MainActor () -> Void)? = .none,
    @ViewBuilder rightAccessory: @escaping () -> RightAccessoryView
  ) {
    self.init(
      chevronVisible: chevronVisible,
      leftAction: .none,
      leftAccessory: EmptyView.init,
      contentAction: contentAction,
      content: content,
      rightAction: rightAction,
      rightAccessory: rightAccessory
    )
  }
}

extension ListRowView
where RightAccessoryView == EmptyView {

  public init(
    chevronVisible: Bool = false,
    leftAction: (@MainActor () -> Void)? = .none,
    @ViewBuilder leftAccessory: @escaping () -> LeftAccessoryView,
    contentAction: @escaping @MainActor () -> Void,
    @ViewBuilder content: @escaping () -> ContentView
  ) {
    self.init(
      chevronVisible: chevronVisible,
      leftAction: leftAction,
      leftAccessory: leftAccessory,
      contentAction: contentAction,
      content: content,
      rightAction: .none,
      rightAccessory: EmptyView.init
    )
  }
}

extension ListRowView
where LeftAccessoryView == EmptyView, RightAccessoryView == EmptyView {

  public init(
    chevronVisible: Bool = false,
    contentAction: @escaping @MainActor () -> Void,
    @ViewBuilder content: @escaping () -> ContentView
  ) {
    self.init(
      chevronVisible: chevronVisible,
      leftAction: .none,
      leftAccessory: EmptyView.init,
      contentAction: contentAction,
      content: content,
      rightAction: .none,
      rightAccessory: EmptyView.init
    )
  }
}

extension ListRowView
where ContentView == ListRowTitleView {

  public init(
    chevronVisible: Bool = false,
    title: DisplayableString,
    leftAction: (@MainActor () -> Void)? = .none,
    @ViewBuilder leftAccessory: @escaping () -> LeftAccessoryView,
    contentAction: @escaping @MainActor () -> Void,
    rightAction: (@MainActor () -> Void)? = .none,
    @ViewBuilder rightAccessory: @escaping () -> RightAccessoryView
  ) {
    self.init(
      chevronVisible: chevronVisible,
      leftAction: leftAction,
      leftAccessory: leftAccessory,
      contentAction: contentAction,
      content: {
        ListRowTitleView(title: title)
      },
      rightAction: rightAction,
      rightAccessory: rightAccessory
    )
  }
}

extension ListRowView
where ContentView == ListRowTitleView, RightAccessoryView == EmptyView {

  public init(
    chevronVisible: Bool = false,
    title: DisplayableString,
    leftAction: (@MainActor () -> Void)? = .none,
    @ViewBuilder leftAccessory: @escaping () -> LeftAccessoryView,
    contentAction: @escaping @MainActor () -> Void
  ) {
    self.init(
      chevronVisible: chevronVisible,
      leftAction: leftAction,
      leftAccessory: leftAccessory,
      contentAction: contentAction,
      content: {
        ListRowTitleView(title: title)
      },
      rightAction: .none,
      rightAccessory: EmptyView.init
    )
  }
}

extension ListRowView
where ContentView == ListRowTitleWithSubtitleView {
  public init(
    chevronVisible: Bool = false,
    title: DisplayableString,
    subtitle: DisplayableString,
    leftAction: (@MainActor () -> Void)? = .none,
    @ViewBuilder leftAccessory: @escaping () -> LeftAccessoryView,
    contentAction: @escaping @MainActor () -> Void,
    rightAction: (@MainActor () -> Void)? = .none,
    @ViewBuilder rightAccessory: @escaping () -> RightAccessoryView
  ) {
    self.init(
      chevronVisible: chevronVisible,
      leftAction: leftAction,
      leftAccessory: leftAccessory,
      contentAction: contentAction,
      content: {
        ListRowTitleWithSubtitleView(
          title: title,
          subtitle: subtitle
        )
      },
      rightAction: rightAction,
      rightAccessory: rightAccessory
    )
  }
}

extension ListRowView
where ContentView == ListRowTitleWithSubtitleView, RightAccessoryView == EmptyView {

  public init(
    chevronVisible: Bool = false,
    title: DisplayableString,
    subtitle: DisplayableString,
    leftAction: (@MainActor () -> Void)? = .none,
    @ViewBuilder leftAccessory: @escaping () -> LeftAccessoryView,
    contentAction: @escaping @MainActor () -> Void
  ) {
    self.init(
      chevronVisible: chevronVisible,
      leftAction: leftAction,
      leftAccessory: leftAccessory,
      contentAction: contentAction,
      content: {
        ListRowTitleWithSubtitleView(
          title: title,
          subtitle: subtitle
        )
      },
      rightAction: .none,
      rightAccessory: EmptyView.init
    )
  }
}

#if DEBUG

internal struct ListRowView_Previews: PreviewProvider {

  internal static var previews: some View {
    ListRowView(
      chevronVisible: true,
      title: "Content title",
      leftAccessory: {
        Image(named: .plus)
          .resizable()
          .aspectRatio(1, contentMode: .fit)
          .padding(8)
          .backgroundColor(.passboltPrimaryBlue)
          .foregroundColor(Color.passboltPrimaryButtonText)
          .cornerRadius(8)
      },
      contentAction: {
        // tap
      },
      rightAction: {
        // tap
      },
      rightAccessory: {
        Image(named: .more)
          .resizable()
          .aspectRatio(1, contentMode: .fit)
          .foregroundColor(Color.passboltIcon)
          .padding(8)
          .frame(width: 44)
      }
    )
  }
}
#endif
