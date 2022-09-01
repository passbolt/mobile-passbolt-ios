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
import Localization
import SwiftUI

public struct ScreenView<TitleView, TitleExtensionView, TitleLeadingItem, TitleTrailingItem, ContentView>: View
where TitleView: View, TitleExtensionView: View, TitleLeadingItem: View, TitleTrailingItem: View, ContentView: View {

  private let titleView: () -> TitleView
  private let titleExtensionView: () -> TitleExtensionView
  private let titleLeadingItem: () -> TitleLeadingItem
  private let titleTrailingItem: () -> TitleTrailingItem
  private let contentView: () -> ContentView
  private let titleBarShadow: Bool
  private let loading: Bool
  private let snackBarMessage: Binding<SnackBarMessage?>

  public init(
    titleBarShadow: Bool = false,
    loading: Bool = false,
    snackBarMessage: Binding<SnackBarMessage?> = .constant(.none),
    @ViewBuilder titleView: @escaping () -> TitleView,
    @ViewBuilder titleExtensionView: @escaping () -> TitleExtensionView,
    @ViewBuilder titleLeadingItem: @escaping () -> TitleLeadingItem,
    @ViewBuilder titleTrailingItem: @escaping () -> TitleTrailingItem,
    @ViewBuilder contentView: @escaping () -> ContentView
  ) {
    self.titleView = titleView
    self.titleExtensionView = titleExtensionView
    self.titleLeadingItem = titleLeadingItem
    self.titleTrailingItem = titleTrailingItem
    self.contentView = contentView
    self.titleBarShadow = titleBarShadow
    self.loading = loading
    self.snackBarMessage = snackBarMessage
  }

  public init(
    title: DisplayableString,
    titleBarShadow: Bool = false,
    loading: Bool = false,
    snackBarMessage: Binding<SnackBarMessage?> = .constant(.none),
    @ViewBuilder contentView: @escaping () -> ContentView
  )
  where
    TitleView == Text, TitleExtensionView == EmptyView, TitleLeadingItem == EmptyView, TitleTrailingItem == EmptyView
  {
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
    self.titleExtensionView = EmptyView.init
    self.titleLeadingItem = EmptyView.init
    self.titleTrailingItem = EmptyView.init
    self.contentView = contentView
    self.titleBarShadow = titleBarShadow
    self.loading = loading
    self.snackBarMessage = snackBarMessage
  }

  public init(
    titleIcon: ImageNameConstant,
    title: DisplayableString,
    titleBarShadow: Bool = false,
    loading: Bool = false,
    snackBarMessage: Binding<SnackBarMessage?> = .constant(.none),
    @ViewBuilder titleExtensionView: @escaping () -> TitleExtensionView,
    @ViewBuilder titleLeadingItem: @escaping () -> TitleLeadingItem,
    @ViewBuilder titleTrailingItem: @escaping () -> TitleTrailingItem,
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
    self.titleExtensionView = titleExtensionView
    self.titleLeadingItem = titleLeadingItem
    self.titleTrailingItem = titleTrailingItem
    self.contentView = contentView
    self.titleBarShadow = titleBarShadow
    self.loading = loading
    self.snackBarMessage = snackBarMessage
  }

  public init(
    titleIcon: ImageNameConstant,
    title: DisplayableString,
    titleBarShadow: Bool = false,
    loading: Bool = false,
    snackBarMessage: Binding<SnackBarMessage?> = .constant(.none),
    @ViewBuilder titleLeadingItem: @escaping () -> TitleLeadingItem,
    @ViewBuilder contentView: @escaping () -> ContentView
  )
  where TitleView == HStack<TupleView<(Image, Text)>>, TitleExtensionView == EmptyView, TitleTrailingItem == EmptyView {
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
    self.titleExtensionView = EmptyView.init
    self.titleLeadingItem = titleLeadingItem
    self.titleTrailingItem = EmptyView.init
    self.contentView = contentView
    self.titleBarShadow = titleBarShadow
    self.loading = loading
    self.snackBarMessage = snackBarMessage
  }

  public init(
    titleIcon: ImageNameConstant,
    title: DisplayableString,
    titleBarShadow: Bool = false,
    loading: Bool = false,
    backButtonAction: @escaping () -> Void,
    snackBarMessage: Binding<SnackBarMessage?> = .constant(.none),
    @ViewBuilder contentView: @escaping () -> ContentView
  )
  where
    TitleView == HStack<TupleView<(Image, Text)>>, TitleExtensionView == EmptyView, TitleLeadingItem == Button<Image>,
    TitleTrailingItem == EmptyView
  {
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
    self.titleExtensionView = EmptyView.init
    self.titleLeadingItem = {
      Button(
        action: backButtonAction,
        label: { Image(named: .arrowLeft) }
      )
    }
    self.titleTrailingItem = EmptyView.init
    self.contentView = contentView
    self.titleBarShadow = titleBarShadow
    self.loading = loading
    self.snackBarMessage = snackBarMessage
  }

  public init(
    titleIcon: ImageNameConstant,
    title: DisplayableString,
    titleBarShadow: Bool = false,
    loading: Bool = false,
    snackBarMessage: Binding<SnackBarMessage?> = .constant(.none),
    @ViewBuilder contentView: @escaping () -> ContentView
  )
  where
    TitleView == HStack<TupleView<(Image, Text)>>, TitleExtensionView == EmptyView, TitleLeadingItem == EmptyView,
    TitleTrailingItem == EmptyView
  {
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
    self.titleExtensionView = EmptyView.init
    self.titleLeadingItem = EmptyView.init
    self.titleTrailingItem = EmptyView.init
    self.contentView = contentView
    self.titleBarShadow = titleBarShadow
    self.loading = loading
    self.snackBarMessage = snackBarMessage
  }

  public init(
    titleBarShadow: Bool = false,
    loading: Bool = false,
    snackBarMessage: Binding<SnackBarMessage?> = .constant(.none),
    @ViewBuilder contentView: @escaping () -> ContentView
  )
  where
    TitleView == EmptyView, TitleExtensionView == EmptyView, TitleLeadingItem == EmptyView,
    TitleTrailingItem == EmptyView
  {
    self.titleView = EmptyView.init
    self.titleExtensionView = EmptyView.init
    self.titleLeadingItem = EmptyView.init
    self.titleTrailingItem = EmptyView.init
    self.contentView = contentView
    self.titleBarShadow = titleBarShadow
    self.loading = loading
    self.snackBarMessage = snackBarMessage
  }

  public init(
    title: DisplayableString,
    titleBarShadow: Bool = false,
    loading: Bool = false,
    backButtonAction: @escaping () -> Void,
    snackBarMessage: Binding<SnackBarMessage?> = .constant(.none),
    @ViewBuilder contentView: @escaping () -> ContentView
  )
  where
    TitleView == Text, TitleExtensionView == EmptyView, TitleLeadingItem == Button<Image>,
    TitleTrailingItem == EmptyView
  {
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
    self.titleExtensionView = EmptyView.init
    self.titleLeadingItem = {
      Button(
        action: backButtonAction,
        label: { Image(named: .arrowLeft) }
      )
    }
    self.titleTrailingItem = EmptyView.init
    self.contentView = contentView
    self.titleBarShadow = titleBarShadow
    self.loading = loading
    self.snackBarMessage = snackBarMessage
  }

  public var body: some View {
    VStack(spacing: 0) {
      NavigationBar(
        barShadow: self.titleBarShadow,
        titleView: self.titleView,
        extensionView: self.titleExtensionView,
        leadingItem: self.titleLeadingItem,
        trailingItem: self.titleTrailingItem
      )
      .foregroundColor(.passboltPrimaryText)

      self.contentView()
        .frame(
          maxWidth: .infinity,
          maxHeight: .infinity,
          alignment: .top
        )
    }
    .backgroundColor(.passboltBackground)
    .snackBarMessage(presenting: self.snackBarMessage)
    .loader(visible: self.loading)
  }
}
