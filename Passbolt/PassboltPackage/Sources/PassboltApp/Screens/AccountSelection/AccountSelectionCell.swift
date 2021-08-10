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

import Accounts
import UICommons

internal final class AccountSelectionCell: CollectionViewCell {

  private let icon: ImageView = .init()
  private let titleLabel: Label = .init()
  private let subTitleLabel: Label = .init()
  private let deleteButton: Button = .init()
  private let stack: StackView = .init()
  private let indicator: View = .init()
  private var tapAction: (() -> Void)?
  private var removeAction: (() -> Void)?
  private var cancellables: Cancellables = .init()

  override internal func setup() {
    super.setup()

    mut(self) {
      .backgroundColor(dynamic: .background)
    }

    mut(icon) {
      .combined(
        .image(named: .person, from: .uiCommons),
        .cornerRadius(20, masksToBounds: true),
        .border(dynamic: .divider),
        .tintColor(dynamic: .icon),
        .contentMode(.scaleAspectFit),
        .subview(of: contentView),
        .leadingAnchor(.equalTo, contentView.leadingAnchor, constant: 12),
        .topAnchor(.equalTo, contentView.topAnchor, constant: 12),
        .bottomAnchor(.equalTo, contentView.bottomAnchor, constant: -12),
        .widthAnchor(.equalTo, constant: 40),
        .heightAnchor(.equalTo, constant: 40)
      )
    }

    mut(indicator) {
      .combined(
        .subview(of: contentView),
        .topAnchor(.equalTo, contentView.topAnchor, constant: 12),
        .leadingAnchor(.equalTo, contentView.leadingAnchor, constant: 40),
        .backgroundColor(dynamic: .secondaryGreen),
        .widthAnchor(.equalTo, constant: 12),
        .heightAnchor(.equalTo, constant: 12),
        .cornerRadius(6, masksToBounds: true),
        .hidden(true)
      )
    }

    mut(titleLabel) {
      .combined(
        .numberOfLines(1),
        .font(.inter(ofSize: 14, weight: .semibold)),
        .textColor(dynamic: .primaryText),
        .subview(of: self.contentView),
        .topAnchor(.equalTo, icon.topAnchor),
        .leadingAnchor(.equalTo, icon.trailingAnchor, constant: 12)
      )
    }

    mut(subTitleLabel) {
      .combined(
        .numberOfLines(1),
        .font(.inter(ofSize: 12)),
        .textColor(dynamic: .secondaryText),
        .subview(of: self.contentView),
        .topAnchor(.equalTo, titleLabel.bottomAnchor, constant: 8),
        .leadingAnchor(.equalTo, titleLabel.leadingAnchor),
        .trailingAnchor(.equalTo, titleLabel.trailingAnchor)
      )
    }

    Mutation<Button>
      .combined(
        .backgroundColor(.clear),
        .subview(of: contentView),
        .edges(equalTo: contentView, usingSafeArea: false),
        .action { [weak self] in self?.tapAction?() }
      )
      .instantiate()

    mut(deleteButton) {
      .combined(
        .subview(of: self.contentView),
        .centerYAnchor(.equalTo, icon.centerYAnchor),
        .leadingAnchor(.equalTo, titleLabel.trailingAnchor, constant: 12),
        .trailingAnchor(.equalTo, contentView.trailingAnchor, constant: -12),
        .widthAnchor(.equalTo, constant: 40),
        .heightAnchor(.equalTo, constant: 40),
        .action { [weak self] in self?.removeAction?() }
      )
    }

    Mutation<ImageView>
      .combined(
        .tintColor(dynamic: .icon),
        .contentMode(.scaleAspectFit),
        .image(named: .trash, from: .uiCommons),
        .subview(of: deleteButton),
        .widthAnchor(.equalTo, constant: 20),
        .heightAnchor(.equalTo, constant: 20),
        .centerXAnchor(.equalTo, deleteButton.centerXAnchor),
        .centerYAnchor(.equalTo, deleteButton.centerYAnchor)
      )
      .instantiate()
  }

  internal func setup(
    from item: AccountSelectionCellItem,
    tapAction: @escaping (() -> Void),
    removeAction: @escaping (() -> Void)
  ) {
    self.titleLabel.text = item.title
    self.subTitleLabel.text = item.subtitle

    self.indicator.isHidden = !item.isCurrentAccount

    self.tapAction = tapAction
    self.removeAction = removeAction

    item
      .imagePublisher?
      .receive(on: RunLoop.main)
      .sink(receiveValue: { [weak self] imageData in
        guard
          let data: Data = imageData,
          let image: UIImage = .init(data: data)
        else { return }

        self?.icon.image = image
      })
      .store(in: cancellables)

    item
      .listModePublisher
      .receive(on: RunLoop.main)
      .sink { [weak self] mode in
        guard let self = self else { return }

        mut(self.deleteButton) {
          .hidden(mode == .selection)
        }
      }
      .store(in: cancellables)
  }

  override internal func prepareForReuse() {
    super.prepareForReuse()

    self.cancellables = .init()

    mut(self.icon) {
      .image(
        named: .person,
        from: .uiCommons
      )
    }

    self.titleLabel.text = ""
    self.subTitleLabel.text = ""
    self.indicator.isHidden = true
    self.tapAction = nil
    self.removeAction = nil
  }
}
