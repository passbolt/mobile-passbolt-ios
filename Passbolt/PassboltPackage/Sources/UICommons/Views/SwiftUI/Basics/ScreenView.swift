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

public struct ScreenView<TitleCenterView, TitleBottomView, TitleLeadingItem, TitleTrailingItem, ContentView>: View
where TitleCenterView: View, TitleBottomView: View, TitleLeadingItem: View, TitleTrailingItem: View, ContentView: View {

  @Environment(\.isInNavigationTreeContext) var isInNavigationTreeContext: Bool
  @Environment(\.navigationTreeDismiss) var navigationTreeDismiss: NavigationTreeDismiss?
  @Environment(\.navigationTreeBack) var navigationTreeBack: NavigationTreeBack?
  private let title: DisplayableString
  private let loading: Bool
  private let snackBarMessage: Binding<SnackBarMessage?>
  private let titleCenterView: () -> TitleCenterView
  private let titleBottomView: () -> TitleBottomView
  private let titleLeadingItem: () -> TitleLeadingItem
  private let titleTrailingItem: () -> TitleTrailingItem
  private let contentView: () -> ContentView

  public init(
    title: DisplayableString,
    loading: Bool = false,
    snackBarMessage: Binding<SnackBarMessage?> = .constant(.none),
    @ViewBuilder titleCenterView: @escaping () -> TitleCenterView,
    @ViewBuilder titleBottomView: @escaping () -> TitleBottomView,
    @ViewBuilder titleLeadingItem: @escaping () -> TitleLeadingItem,
    @ViewBuilder titleTrailingItem: @escaping () -> TitleTrailingItem,
    @ViewBuilder contentView: @escaping () -> ContentView
  ) {
    self.title = title
    self.loading = loading
    self.snackBarMessage = snackBarMessage
    self.titleCenterView = titleCenterView
    self.titleBottomView = titleBottomView
    self.titleLeadingItem = titleLeadingItem
    self.titleTrailingItem = titleTrailingItem
    self.contentView = contentView
  }

  public init(
    titleIcon: ImageNameConstant,
    title: DisplayableString,
    loading: Bool = false,
    snackBarMessage: Binding<SnackBarMessage?> = .constant(.none),
    @ViewBuilder titleExtensionView: @escaping () -> TitleBottomView,
    @ViewBuilder titleLeadingItem: @escaping () -> TitleLeadingItem,
    @ViewBuilder titleTrailingItem: @escaping () -> TitleTrailingItem,
    @ViewBuilder contentView: @escaping () -> ContentView
  ) where TitleCenterView == HStack<TupleView<(Image, Text)>> {
    self.title = title
    self.titleCenterView = {
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
    self.titleBottomView = titleExtensionView
    self.titleLeadingItem = titleLeadingItem
    self.titleTrailingItem = titleTrailingItem
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
  )
  where
    TitleCenterView == HStack<TupleView<(Image, Text)>>, TitleBottomView == EmptyView, TitleLeadingItem == EmptyView,
    TitleTrailingItem == EmptyView
  {
    self.title = title
    self.titleCenterView = {
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
    self.titleBottomView = EmptyView.init
    self.titleLeadingItem = EmptyView.init
    self.titleTrailingItem = EmptyView.init
    self.contentView = contentView
    self.loading = loading
    self.snackBarMessage = snackBarMessage
  }

  public init(
    title: DisplayableString,
    loading: Bool = false,
    backButtonAction: @escaping () -> Void,
    snackBarMessage: Binding<SnackBarMessage?> = .constant(.none),
    @ViewBuilder contentView: @escaping () -> ContentView
  )
  where
    TitleCenterView == Text, TitleBottomView == EmptyView, TitleLeadingItem == Button<Image>,
    TitleTrailingItem == EmptyView
  {
    self.title = title
    self.titleCenterView = {
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
    self.titleBottomView = EmptyView.init
    self.titleLeadingItem = {
      Button(
        action: backButtonAction,
        label: { Image(named: .arrowLeft) }
      )
    }
    self.titleTrailingItem = EmptyView.init
    self.contentView = contentView
    self.loading = loading
    self.snackBarMessage = snackBarMessage
  }

  public init(
    title: DisplayableString,
    loading: Bool = false,
    dismissButtonAction: @escaping () -> Void,
    snackBarMessage: Binding<SnackBarMessage?> = .constant(.none),
    @ViewBuilder contentView: @escaping () -> ContentView
  )
  where
    TitleCenterView == Text, TitleBottomView == EmptyView, TitleLeadingItem == EmptyView,
    TitleTrailingItem == Button<Image>
  {
    self.title = title
    self.titleCenterView = {
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
    self.titleBottomView = EmptyView.init
    self.titleLeadingItem = EmptyView.init
    self.titleTrailingItem = {
      Button(
        action: dismissButtonAction,
        label: { Image(named: .close) }
      )
    }
    self.contentView = contentView
    self.loading = loading
    self.snackBarMessage = snackBarMessage
  }

  public init(
    title: DisplayableString,
    loading: Bool = false,
    snackBarMessage: Binding<SnackBarMessage?> = .constant(.none),
    @ViewBuilder contentView: @escaping () -> ContentView
  )
  where
    TitleCenterView == Text, TitleBottomView == EmptyView, TitleLeadingItem == EmptyView,
    TitleTrailingItem == EmptyView
  {
    self.title = title
    self.titleCenterView = {
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
    self.titleBottomView = EmptyView.init
    self.titleLeadingItem = EmptyView.init
    self.titleTrailingItem = EmptyView.init
    self.contentView = contentView
    self.loading = loading
    self.snackBarMessage = snackBarMessage
  }

  public var body: some View {
    if self.isInNavigationTreeContext {
      VStack(spacing: 0) {
        self.titleBottomView()
          .padding(leading: 16, trailing: 16)

        self.contentView()
          .frame(
            maxWidth: .infinity,
            maxHeight: .infinity,
            alignment: .top
          )
      }
      .snackBarMessage(presenting: self.snackBarMessage)
      .loader(visible: self.loading)
      .navigationBarTitleDisplayMode(.inline)
      .navigationTitle(Text(displayable: self.title))
      .navigationBarBackButtonHidden(TitleLeadingItem.self != EmptyView.self)
      .toolbar {
        ToolbarItem(placement: .navigationBarLeading) {
          self.titleLeadingItem()
            .frame(maxWidth: 60, alignment: .leading)
        }
        ToolbarItem(placement: .principal) {
          self.titleCenterView()
            .frame(maxWidth: .infinity, alignment: .center)
        }
        ToolbarItem(placement: .navigationBarTrailing) {
          self.titleTrailingItem()
            .frame(maxWidth: 60, alignment: .trailing)
        }
      }
      .backgroundColor(.passboltBackground)
      .foregroundColor(.passboltPrimaryText)
    }
    else {
      self.legacyBody
    }
  }

  @ViewBuilder private var legacyBody: some View {
    VStack(spacing: 0) {
      NavigationBar(
        centerView: self.titleCenterView,
        bottomView: self.titleBottomView
      )

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
