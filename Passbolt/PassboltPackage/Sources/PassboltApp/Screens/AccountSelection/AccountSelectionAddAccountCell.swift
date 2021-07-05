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

import UICommons

internal final class AccountSelectionAddAccountCell: CollectionViewCell {

  private let titleLabel: Label = .init()
  private var tapAction: (() -> Void)?

  override internal func setup() {
    super.setup()

    mut(self) {
      .backgroundColor(dynamic: .background)
    }

    let icon: ImageView = .init()
    mut(icon) {
      .combined(
        .image(named: .plus, from: .uiCommons),
        .tintColor(dynamic: .iconAlternative),
        .contentMode(.scaleAspectFit),
        .subview(of: self.contentView),
        .leadingAnchor(.equalTo, contentView.leadingAnchor, constant: 22),
        .topAnchor(.equalTo, contentView.topAnchor, constant: 22),
        .bottomAnchor(.equalTo, contentView.bottomAnchor, constant: -22),
        .widthAnchor(.equalTo, constant: 20),
        .heightAnchor(.equalTo, constant: 20)
      )
    }

    mut(titleLabel) {
      .combined(
        .numberOfLines(1),
        .font(.inter(ofSize: 14, weight: .semibold)),
        .textColor(dynamic: .primaryText),
        .subview(of: self.contentView),
        .centerYAnchor(.equalTo, icon.centerYAnchor),
        .leadingAnchor(.equalTo, icon.trailingAnchor, constant: 22),
        .trailingAnchor(.equalTo, contentView.trailingAnchor, constant: -12)
      )
    }

    Mutation<Button>
      .combined(
        .backgroundColor(.clear),
        .subview(of: self.contentView),
        .edges(equalTo: self.contentView, usingSafeArea: false),
        .action { [weak self] in self?.tapAction?() }
      )
      .instantiate()
  }

  internal func setup(
    from item: AccountSelectionAddAccountCellItem,
    tapAction: @escaping (() -> Void)
  ) {
    self.titleLabel.text = item.title
    self.tapAction = tapAction
  }

  override internal func prepareForReuse() {
    super.prepareForReuse()

    titleLabel.text = nil
    tapAction = nil
  }
}
