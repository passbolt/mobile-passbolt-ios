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

internal final class ResourcesSelectionListAddCell: CollectionViewCell {

  private var tapAction: (() -> Void)?

  override internal func setup() {
    super.setup()

    mut(self) {
      .backgroundColor(dynamic: .background)
    }

    let contentButton: Button = .init()
    mut(contentButton) {
      .combined(
        .backgroundColor(.clear),
        .subview(of: contentView),
        .heightAnchor(.equalTo, constant: 64),
        .edges(equalTo: contentView, usingSafeArea: false),
        .action { [weak self] in self?.tapAction?() }
      )
    }

    let iconContainer: ContainerView<ImageView> = .init(
      contentView: .init(),
      mutation: .combined(
        .image(named: .plus, from: .uiCommons),
        .tintColor(dynamic: .primaryButtonText),
        .contentMode(.scaleAspectFit)
      ),
      edges: UIEdgeInsets(
        top: 8,
        left: 8,
        bottom: -8,
        right: -8
      )
    )
    mut(iconContainer) {
      .combined(
        .userInteractionEnabled(false),
        .backgroundColor(dynamic: .primaryBlue),
        .cornerRadius(8),
        .subview(of: contentButton),
        .leadingAnchor(.equalTo, contentButton.leadingAnchor, constant: 16),
        .topAnchor(.equalTo, contentButton.topAnchor, constant: 12),
        .bottomAnchor(.equalTo, contentButton.bottomAnchor, constant: -12),
        .widthAnchor(.equalTo, constant: 40),
        .heightAnchor(.equalTo, constant: 40)
      )
    }

    mut(Label()) {
      .combined(
        .numberOfLines(1),
        .font(.inter(ofSize: 14, weight: .semibold)),
        .textColor(dynamic: .primaryText),
        .text(displayable: .localized(key: .create)),
        .subview(of: contentButton),
        .centerYAnchor(.equalTo, iconContainer.centerYAnchor),
        .leadingAnchor(.equalTo, iconContainer.trailingAnchor, constant: 12),
        .trailingAnchor(.equalTo, contentButton.trailingAnchor, constant: -12)
      )
    }

  }

  internal func setup(
    tapAction: @escaping (() -> Void)
  ) {
    self.tapAction = tapAction
  }

  override internal func prepareForReuse() {
    super.prepareForReuse()

    self.tapAction = nil
  }
}
