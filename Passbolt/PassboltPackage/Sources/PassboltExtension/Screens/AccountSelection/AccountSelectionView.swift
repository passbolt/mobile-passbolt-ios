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
import SharedUIComponents
import UICommons

internal final class AccountSelectionView: View {

  internal var accountTapPublisher: AnyPublisher<AccountSelectionCellItem, Never> { collectionView.accountTapPublisher }
  internal var addAccountTapPublisher: AnyPublisher<Void, Never> { collectionView.addAccountPublisher }

  private let logoImageView: ImageView = .init()
  private lazy var collectionView: AccountSelectionCollectionView = .init(
    layout: UICollectionViewCompositionalLayout.accountSelectionLayout()
  )

  private let container: View = .init()
  private let titleLabel: Label = .init()
  private let subTitleLabel: Label = .init()

  @available(*, unavailable, message: "Use init(mode:)")
  internal required init() {
    unreachable("\(Self.self).\(#function) should not be used")
  }

  internal init(
    mode: AccountSelectionController.Mode
  ) {
    super.init()

    mut(self) {
      .backgroundColor(dynamic: .background)
    }

    mut(container) {
      .combined(
        .subview(of: self),
        .edges(equalTo: self, insets: .init(top: -8, left: -16, bottom: -8, right: -16)),
        .backgroundColor(dynamic: .background),
        .subview(
          titleLabel,
          subTitleLabel,
          collectionView
        )
      )
    }

    mut(titleLabel) {
      .combined(
        .titleStyle(),
        .topAnchor(.equalTo, container.topAnchor, constant: 113),
        .leadingAnchor(.equalTo, container.leadingAnchor),
        .trailingAnchor(.equalTo, container.trailingAnchor)
      )
    }

    mut(subTitleLabel) {
      .combined(
        .infoStyle(),
        .leadingAnchor(.equalTo, container.leadingAnchor),
        .trailingAnchor(.equalTo, container.trailingAnchor),
        .topAnchor(.equalTo, titleLabel.bottomAnchor, constant: 16)
      )
    }

    switch mode {
    case .signIn:
      mut(titleLabel) {
        .text(displayable: .localized(key: "autofill.extension.account.selection.switch.account.title"))
      }

      mut(subTitleLabel) {
        .text(displayable: .localized(key: "autofill.extension.account.selection.switch.account.subtitle"))
      }

    case .switchAccount:
      mut(titleLabel) {
        .text(displayable: .localized(key: "autofill.extension.account.selection.sign.in.title"))
      }

      mut(subTitleLabel) {
        .text(displayable: .localized(key: "autofill.extension.account.selection.sign.in.subtitle"))
      }
    }

    mut(collectionView) {
      .combined(
        .leadingAnchor(.equalTo, container.leadingAnchor),
        .trailingAnchor(.equalTo, container.trailingAnchor),
        .topAnchor(.equalTo, subTitleLabel.bottomAnchor, constant: 40),
        .bottomAnchor(.equalTo, container.bottomAnchor, constant: -20),
        .set(\.dynamicBackgroundColor, to: .background)
      )
    }
  }

  internal func update(items: Array<AccountSelectionListItem>) {
    collectionView.update(data: items)
  }
}
