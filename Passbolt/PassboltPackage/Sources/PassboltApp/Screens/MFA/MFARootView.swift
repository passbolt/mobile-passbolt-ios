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

internal final class MFARootView: KeyboardAwareView {

  internal var tapPublisher: AnyPublisher<Void, Never> { button.tapPublisher }

  private let scrolledStack: ScrolledStackView = .init()
  private let container: PlainView = .init()
  private let button: TextButton = .init()

  @available(*, unavailable, message: "Use init(hideButton:)")
  internal required init() {
    unreachable(#function)
  }

  internal init(hideButton: Bool) {
    super.init()

    mut(self) {
      .backgroundColor(dynamic: .background)
    }

		mut(self.button) {
      .combined(
        .linkStyle(),
        .text(
          displayable: .localized(key: "mfa.provider.try.another")
        )
      )
    }

    mut(scrolledStack) {
      .combined(
        .clipsToBounds(true),
        .isLayoutMarginsRelativeArrangement(true),
        .contentInset(.init(top: 0, left: 16, bottom: 8, right: 16)),
        .axis(.vertical),
        .subview(of: self),
        .leadingAnchor(.equalTo, leadingAnchor),
        .trailingAnchor(.equalTo, trailingAnchor),
        .topAnchor(.equalTo, safeAreaLayoutGuide.topAnchor),
        .bottomAnchor(.equalTo, keyboardLayoutGuide.topAnchor),
				.append(self.container),
				.when(
					!hideButton,
					then: .append(self.button)
				)
      )
    }

		mut(self.container) {
			.heightAnchor(
				.greaterThanOrEqualTo,
				self.safeAreaLayoutGuide.heightAnchor,
				constant: hideButton
				? -8 // content inset
				: -64 // button size + content inset
			)
		}
  }

  internal func setContent(
		view: UIView
	) {
		self.container.subviews.forEach { $0.removeFromSuperview() }

    mut(view) {
      .combined(
				.subview(of: self.container),
				.edges(equalTo: self.container)
      )
    }
  }
}
