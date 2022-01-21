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
import Commons

open class EmptyStateView: View {

  internal let titleLabel: Label = .init()
  internal let imageView: ImageView = .init()

  public init(
    labelString: DisplayableString = .localized(key: .emptyList)
  ) {
    super.init()

    mut(titleLabel) {
      .combined(
        .numberOfLines(0),
        .lineBreakMode(.byWordWrapping),
        .text(displayable: labelString),
        .textColor(dynamic: .primaryText),
        .textAlignment(.center),
        .font(.inter(ofSize: 20, weight: .semibold)),
        .subview(of: self),
        .topAnchor(.greaterThanOrEqualTo, self.topAnchor),
        .leadingAnchor(.equalTo, self.leadingAnchor),
        .trailingAnchor(.equalTo, self.trailingAnchor)
      )
    }

    let imageContainer: ContainerView = .init(
      contentView: imageView,
      mutation: .combined(
        .image(dynamic: .emptyState),
        .contentMode(.scaleAspectFit)
      ),
      widthMultiplier: 0.7,
      heightMultiplier: 1
    )
    mut(imageContainer) {
      .combined(
        .subview(of: self),
        .topAnchor(.equalTo, titleLabel.bottomAnchor, constant: 8),
        .leadingAnchor(.equalTo, leadingAnchor),
        .trailingAnchor(.equalTo, trailingAnchor),
        .centerYAnchor(.equalTo, centerYAnchor),
        .bottomAnchor(.lessThanOrEqualTo, bottomAnchor)
      )
    }

    mut(self) {
      .combined(
        .backgroundColor(.clear)
      )
    }
  }

  @available(*, unavailable)
  public required init() {
    unreachable(#function)
  }
}
