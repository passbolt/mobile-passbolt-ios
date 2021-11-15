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

internal final class ResourcesSelectionListResourceCell: CollectionViewCell {

  private let iconView: LetterIconView = .init()
  private let titleLabel: Label = .init()
  private let subtitleLabel: Label = .init()
  private var tapAction: (() -> Void)?
  private var titleCenterConstraint: NSLayoutConstraint?

  override internal func setup() {
    super.setup()

    mut(self) {
      .backgroundColor(dynamic: .background)
    }

    let contentButton: Button = .init()
    mut(contentButton) {
      .combined(
        .backgroundColor(.clear),
        .clipsToBounds(true),
        .subview(of: self.contentView),
        .leadingAnchor(.equalTo, self.contentView.leadingAnchor),
        .topAnchor(.equalTo, self.contentView.topAnchor),
        .bottomAnchor(.equalTo, self.contentView.bottomAnchor),
        .trailingAnchor(.equalTo, self.contentView.trailingAnchor),
        .heightAnchor(.equalTo, constant: 64),
        .action { [weak self] in self?.tapAction?() }
      )
    }

    let iconContainer: ContainerView<View> = .init(
      contentView: iconView,
      mutation: .combined(
        .userInteractionEnabled(false),
        .heightAnchor(.equalTo, constant: 40),
        .widthAnchor(.equalTo, constant: 40)
      )
    )
    mut(iconContainer) {
      .combined(
        .userInteractionEnabled(false),
        .backgroundColor(.clear),
        .cornerRadius(8, masksToBounds: true),
        .subview(of: contentButton),
        .leadingAnchor(.equalTo, contentButton.leadingAnchor, constant: 16),
        .topAnchor(.equalTo, contentButton.topAnchor, constant: 12),
        .bottomAnchor(.equalTo, contentButton.bottomAnchor, constant: -12),
        .widthAnchor(.equalTo, constant: 40),
        .heightAnchor(.equalTo, constant: 40)
      )
    }

    mut(titleLabel) {
      .combined(
        .numberOfLines(1),
        .font(.inter(ofSize: 14, weight: .semibold)),
        .textColor(dynamic: .primaryText),
        .lineBreakMode(.byTruncatingTail),
        .subview(of: contentButton),
        .centerYAnchor(.equalTo, iconContainer.centerYAnchor, referenceOutput: &self.titleCenterConstraint),
        .leadingAnchor(.equalTo, iconContainer.trailingAnchor, constant: 12),
        .trailingAnchor(.equalTo, contentButton.trailingAnchor, constant: -12)
      )
    }

    mut(subtitleLabel) {
      .combined(
        .numberOfLines(1),
        .font(.inter(ofSize: 12, weight: .regular)),
        .textColor(dynamic: .secondaryText),
        .lineBreakMode(.byTruncatingTail),
        .subview(of: contentButton),
        .topAnchor(.equalTo, titleLabel.bottomAnchor, constant: 6),
        .leadingAnchor(.equalTo, iconContainer.trailingAnchor, constant: 12),
        .trailingAnchor(.equalTo, contentButton.trailingAnchor, constant: -12)
      )
    }
  }

  internal func setup(
    from item: ResourcesSelectionListViewResourceItem,
    tapAction: @escaping (() -> Void)
  ) {
    self.iconView.update(from: item.name)
    self.titleLabel.text = item.name
    self.subtitleLabel.text = item.username
    self.titleCenterConstraint?.constant = (item.username?.isEmpty ?? true) ? 0 : -10
    self.tapAction = tapAction
  }

  override internal func prepareForReuse() {
    super.prepareForReuse()

    self.iconView.update(from: "")
    self.titleLabel.text = nil
    self.subtitleLabel.text = nil
    self.tapAction = nil
  }
}
