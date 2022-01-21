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

public final class HelpMenuView: ScrolledStackView {

  public override func setup() {
    mut(self) {
      .combined(
        .backgroundColor(.clear),
        .axis(.vertical),
        .isLayoutMarginsRelativeArrangement(true),
        .contentInset(.init(top: 0, left: 16, bottom: 0, right: 16))
      )
    }
  }

  internal func setActions(_ actions: Array<HelpMenuController.Action>) {
    removeAllArrangedSubviews()
    mut(self) {
      .forEach(in: actions) { action in
        .append(HelpMenuActionCellView(action))
      }
    }
  }
}

private final class HelpMenuActionCellView: Button {

  fileprivate let imageView: ImageView = .init()
  fileprivate let titleLabel: Label = .init()

  @available(*, unavailable, message: "Use init(operation:)")
  required init() {
    unreachable(#function)
  }

  fileprivate init(_ action: HelpMenuController.Action) {
    super.init()

    mut(self) {
      .combined(
        .backgroundColor(.clear),
        .action(action.handler)
      )
    }

    mut(imageView) {
      .combined(
        .image(named: action.iconName, from: action.iconBundle),
        .tintColor(dynamic: .primaryText),
        .subview(of: self),
        .leadingAnchor(.equalTo, leadingAnchor),
        .topAnchor(.equalTo, topAnchor, constant: 18),
        .bottomAnchor(.equalTo, bottomAnchor, constant: -18),
        .widthAnchor(.equalTo, constant: 18),
        .heightAnchor(.equalTo, constant: 18),
        .contentMode(.scaleAspectFit)
      )
    }

    mut(titleLabel) {
      .combined(
        .text(displayable: action.title),
        .font(.inter(ofSize: 14, weight: .semibold)),
        .textColor(dynamic: .primaryText),
        .subview(of: self),
        .leadingAnchor(.equalTo, imageView.trailingAnchor, constant: 16),
        .trailingAnchor(.equalTo, trailingAnchor),
        .centerYAnchor(.equalTo, imageView.centerYAnchor)
      )
    }
  }
}
