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

internal final class ResourcesListResourceCell: CollectionViewCell {

  private let iconView: LetterIconLegacyView = .init()
  private let titleLabel: Label = .init()
  private let subtitleLabel: Label = .init()
  private var expiryView: ImageView = .init()
  private var tapAction: (() -> Void)?
  private var menuTapAction: (() -> Void)?
  private var titleCenterConstraint: NSLayoutConstraint?

  override internal func setup() {
    super.setup()

    mut(self) {
      .backgroundColor(dynamic: .background)
    }

    let contentButton: PlainButton = .init()
    mut(contentButton) {
      .combined(
        .backgroundColor(.clear),
        .clipsToBounds(true),
        .subview(of: self.contentView),
        .leadingAnchor(.equalTo, self.contentView.leadingAnchor),
        .topAnchor(.equalTo, self.contentView.topAnchor),
        .bottomAnchor(.equalTo, self.contentView.bottomAnchor),
        .heightAnchor(.equalTo, constant: 64),
        .action { [weak self] in self?.tapAction?() }
      )
    }

    let iconContainer: ContainerView<PlainView> = .init(
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
        .subview(of: contentButton),
        .leadingAnchor(.equalTo, contentButton.leadingAnchor, constant: 16),
        .topAnchor(.equalTo, contentButton.topAnchor, constant: 12),
        .bottomAnchor(.equalTo, contentButton.bottomAnchor, constant: -12),
        .widthAnchor(.equalTo, constant: 40),
        .heightAnchor(.equalTo, constant: 40)
      )
    }

    mut(expiryView) {
      .combined(
        .subview(of: iconContainer),
        .image(named: .exclamationMark, from: .uiCommons),
        .contentMode(.scaleAspectFit),
        .centerYAnchor(.equalTo, iconContainer.bottomAnchor, constant: -2),
        .centerXAnchor(.equalTo, iconContainer.trailingAnchor, constant: -2),
        .widthAnchor(.equalTo, constant: 12),
        .heightAnchor(.equalTo, constant: 12)
      )
    }

    mut(titleLabel) {
      .combined(
        .numberOfLines(1),
        .font(.inter(ofSize: 14, weight: .semibold)),
        .textColor(dynamic: .primaryText),
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

    let menuButton: ImageButton = .init()
    mut(menuButton) {
      .combined(
        .image(named: .more, from: .uiCommons),
        .imageContentMode(.scaleAspectFit),
        .imageInsets(.init(top: 24, left: 0, bottom: -24, right: -16)),
        .tintColor(dynamic: .iconAlternative),
        .backgroundColor(.clear),
        .subview(of: self.contentView),
        .leadingAnchor(.equalTo, contentButton.trailingAnchor),
        .trailingAnchor(.equalTo, self.contentView.trailingAnchor),
        .topAnchor(.equalTo, self.contentView.topAnchor),
        .bottomAnchor(.equalTo, self.contentView.bottomAnchor),
        .widthAnchor(.equalTo, constant: 40),
        .action { [weak self] in self?.menuTapAction?() }
      )
    }
  }

  internal func setup(
    from item: ResourcesResourceListItemDSVItem,
    tapAction: @escaping (() -> Void),
    menuTapAction: @escaping (() -> Void)
  ) {
    self.iconView.update(from: item.name)

    let attributes = [NSAttributedString.Key.font: UIFont.inter(ofSize: 14, weight: .semibold)]
    let itemNameAttributedString = NSMutableAttributedString(string: item.name, attributes: attributes)
    if item.isExpired {
      let expiredAttributes = [NSAttributedString.Key.font: UIFont.inter(ofSize: 14, weight: .regular)]
      let expiredAttributedString = NSAttributedString(
        string: " \(DisplayableString.localized("resource.expiry.expired").string(with: []))",
        attributes: expiredAttributes
      )

      itemNameAttributedString.append(expiredAttributedString)

    }
    self.titleLabel.lineBreakMode = item.isExpired ? .byTruncatingMiddle : .byTruncatingTail
    self.expiryView.isHidden = !item.isExpired
    self.titleLabel.attributedText = itemNameAttributedString

    if let username: String = item.username, !username.isEmpty {
      self.titleCenterConstraint?.constant = -10
      mut(self.subtitleLabel) {
        .combined(
          .font(.inter(ofSize: 12, weight: .regular)),
          .text(username)
        )
      }
    }
    else {
      // to adjust view to center name instead of adding username placeholder use line below
      // self.titleCenterConstraint?.constant = 0
      self.titleCenterConstraint?.constant = -10
      mut(self.subtitleLabel) {
        .combined(
          .font(.interItalic(ofSize: 12, weight: .regular)),
          .text(displayable: .localized(key: "resource.list.username.empty.placeholder"))
        )
      }
    }
    self.tapAction = tapAction
    self.menuTapAction = menuTapAction
  }

  override internal func prepareForReuse() {
    super.prepareForReuse()

    self.iconView.update(from: "")
    self.titleLabel.text = nil
    self.subtitleLabel.text = nil
    self.tapAction = nil
    self.menuTapAction = nil
    self.expiryView.isHidden = true
  }
}
