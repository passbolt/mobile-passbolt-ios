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

import Localization
import SwiftUI
import AegithalosCocoa

public struct ScreenView<TitleView, ContentView>: View
where TitleView: View, ContentView: View {

  private let titleView: () -> TitleView
  private let contentView: () -> ContentView
  private let loading: Bool
  private let snackBarMessage: Binding<SnackBarMessage?>

  public init(
    loading: Bool = false,
    snackBarMessage: Binding<SnackBarMessage?> = .constant(.none),
    @ViewBuilder titleView: @escaping () -> TitleView,
    @ViewBuilder contentView: @escaping () -> ContentView
  ) {
    self.titleView = titleView
    self.contentView = contentView
    self.loading = loading
    self.snackBarMessage = snackBarMessage
  }

  public init(
    title: DisplayableString,
    loading: Bool = false,
    snackBarMessage: Binding<SnackBarMessage?> = .constant(.none),
    @ViewBuilder contentView: @escaping () -> ContentView
  ) where TitleView == Text {
    self.titleView = {
      Text(
        displayable: title
      )
      .font(
        .inter(
          ofSize: 16,
          weight: .semibold
        )
      )
      .foregroundColor(.passboltPrimaryText)
    }
    self.contentView = contentView
    self.loading = loading
    self.snackBarMessage = snackBarMessage
  }

  public init(
    titleIcon: ImageNameConstant,
    title: DisplayableString,
    loading: Bool = false,
    snackBarMessage: Binding<SnackBarMessage?> = .constant(.none),
    @ViewBuilder contentView: @escaping () -> ContentView
  ) where TitleView == HStack<TupleView<(Image, Text)>> {
    self.titleView = {
      HStack<TupleView<(Image, Text)>>(spacing: 12) {
        Image(named: titleIcon)

        Text(
          displayable: title
        )
        .font(
          .inter(
            ofSize: 16,
            weight: .semibold
          )
        )
        .foregroundColor(.passboltPrimaryText)
      }
    }
    self.contentView = contentView
    self.loading = loading
    self.snackBarMessage = snackBarMessage
  }

  public init(
    loading: Bool = false,
    snackBarMessage: Binding<SnackBarMessage?> = .constant(.none),
    @ViewBuilder contentView: @escaping () -> ContentView
  ) where TitleView == EmptyView {
    self.titleView = EmptyView.init
    self.contentView = contentView
    self.loading = loading
    self.snackBarMessage = snackBarMessage
  }

  public var body: some View {
    VStack(spacing: 0) {
      NavigationBar(
        titleView: self.titleView
      )

      self.contentView()
    }
    .backgroundColor(.passboltBackground)
    .snackBarMessage(
      presenting: self.snackBarMessage
    )
    .loader(
      visible: self.loading
    )
  }
}
