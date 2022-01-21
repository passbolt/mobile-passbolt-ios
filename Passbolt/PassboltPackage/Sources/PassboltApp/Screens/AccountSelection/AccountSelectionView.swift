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
  internal var removeTapPublisher: AnyPublisher<Void, Never> { removeContainer.tapPublisher }
  internal var doneTapPublisher: AnyPublisher<Void, Never> { doneButton.tapPublisher }
  internal var removeAccountPublisher: AnyPublisher<AccountSelectionCellItem, Never> {
    collectionView.removeAccountPublisher
  }

  private let logoImageView: ImageView = .init()
  private lazy var collectionView: AccountSelectionCollectionView = .init(
    layout: UICollectionViewCompositionalLayout.accountSelectionLayout()
  )

  private let container: View = .init()
  private let titleLabel: Label = .init()
  private let subTitleLabel: Label = .init()
  private let logoContainer: View = .init()
  private let buttonStack: StackView = .init()
  private let removeContainer: Button = .init()
  private let removeIcon: ImageView = .init()
  private let removeLabel: Label = .init()
  private let doneButton: TextButton = .init()

  @available(*, unavailable)
  internal required init() {
    unreachable("Use init(shouldHideTitle:")
  }

  internal init(shouldHideTitle: Bool) {
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
          logoContainer,
          subTitleLabel,
          collectionView,
          buttonStack
        )
      )
    }

    mut(logoContainer) {
      .combined(
        .backgroundColor(dynamic: .background),
        .leadingAnchor(.equalTo, container.leadingAnchor),
        .trailingAnchor(.equalTo, container.trailingAnchor),
        .topAnchor(.equalTo, container.topAnchor)
      )
    }

    mut(logoImageView) {
      .combined(
        .subview(of: logoContainer),
        .image(dynamic: .passboltLogo),
        .contentMode(.scaleAspectFit),
        .topAnchor(.equalTo, logoContainer.topAnchor),
        .bottomAnchor(.equalTo, logoContainer.bottomAnchor),
        .centerXAnchor(.equalTo, logoContainer.centerXAnchor),
        .widthAnchor(.equalTo, constant: 118),
        .accessibilityIdentifier("account.selection.app.logo.imageview")
      )
    }

    mut(titleLabel) {
      .when(
        !shouldHideTitle,
        then: .combined(
          .subview(of: container),
          .titleStyle(),
          .leadingAnchor(.equalTo, container.leadingAnchor),
          .trailingAnchor(.equalTo, container.trailingAnchor),
          .topAnchor(.equalTo, logoContainer.bottomAnchor, constant: 94)
        )
      )
    }

    mut(subTitleLabel) {
      .combined(
        .infoStyle(),
        .leadingAnchor(.equalTo, container.leadingAnchor),
        .trailingAnchor(.equalTo, container.trailingAnchor),
        .when(
          shouldHideTitle,
          then: .topAnchor(.equalTo, logoContainer.bottomAnchor, constant: 94),
          else: .topAnchor(.equalTo, titleLabel.bottomAnchor, constant: 16)
        )
      )
    }

    mut(collectionView) {
      .combined(
        .leadingAnchor(.equalTo, container.leadingAnchor),
        .trailingAnchor(.equalTo, container.trailingAnchor),
        .topAnchor(.equalTo, subTitleLabel.bottomAnchor, constant: 40),
        .bottomAnchor(.equalTo, buttonStack.topAnchor, constant: -20),
        .custom { (subject: CollectionView) in
          subject.dynamicBackgroundColor = .background
        }
      )
    }

    mut(removeContainer) {
      .subview(removeIcon, removeLabel)
    }

    mut(removeIcon) {
      .combined(
        .image(named: .trash, from: .uiCommons),
        .tintColor(dynamic: .icon),
        .leadingAnchor(.greaterThanOrEqualTo, removeContainer.leadingAnchor, constant: 40),
        .trailingAnchor(.equalTo, removeLabel.leadingAnchor, constant: -18),
        .topAnchor(.equalTo, removeContainer.topAnchor),
        .bottomAnchor(.equalTo, removeContainer.bottomAnchor)
      )
    }

    mut(removeLabel) {
      .combined(
        .text(displayable: .localized(key: "account.selection.remove.account.button.title")),
        .font(.inter(ofSize: 14, weight: .semibold)),
        .textColor(dynamic: .primaryText),
        .trailingAnchor(.lessThanOrEqualTo, removeContainer.trailingAnchor, constant: -40),
        .centerYAnchor(.equalTo, removeContainer.centerYAnchor)
      )
    }

    mut(doneButton) {
      .combined(
        .primaryStyle(),
        .hidden(true),
        .text(displayable: .localized(key: .done)),
        .accessibilityIdentifier("account.selection.done.button")
      )
    }

    mut(buttonStack) {
      .combined(
        .axis(.vertical),
        .leadingAnchor(.equalTo, container.leadingAnchor),
        .trailingAnchor(.equalTo, container.trailingAnchor),
        .bottomAnchor(.equalTo, container.bottomAnchor),
        .arrangedSubview(removeContainer, doneButton)
      )
    }
  }

  internal func update(items: Array<AccountSelectionListItem>) {
    collectionView.update(data: items)
  }

  internal func update(mode: AccountSelectionListMode) {
    switch mode {
    case .selection:
      mut(titleLabel) {
        .text(
          displayable: .localized(key: "account.selection.title")
        )
      }

      mut(subTitleLabel) {
        .text(
          displayable: .localized(key: "account.selection.subtitle")
        )
      }

      mut(doneButton) {
        .hidden(true)
      }

      mut(removeContainer) {
        .hidden(false)
      }

    case .removal:
      mut(titleLabel) {
        .text(
          displayable: .localized(key: "account.selection.remove.account.title")
        )
      }

      mut(subTitleLabel) {
        .text(
          displayable: .localized(key: "account.selection.remove.account.subtitle")
        )
      }

      mut(doneButton) {
        .hidden(false)
      }

      mut(removeContainer) {
        .hidden(true)
      }
    }
  }
}
