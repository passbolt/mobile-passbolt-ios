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
import UICommons

internal final class HomeSearchView: PlainView {

  private lazy var textSearchView: TextSearchView = .init(
    leftAccesoryView: presentationMenuButton,
    rightAccesoryView: accountMenuButton
  )
  private lazy var presentationMenuButton: ImageButton = .init()
  private lazy var accountMenuButton: ImageButton = .init()

  override func setup() {
    super.setup()

    mut(presentationMenuButton) {
      .combined(
        .image(named: .filter, from: .uiCommons),
        .contentMode(.scaleAspectFit),
        .backgroundColor(.clear),
        .widthAnchor(.equalTo, constant: 24),
        .heightAnchor(.equalTo, constant: 24),
        .accessibilityIdentifier("search.view.menu")
      )
    }
    mut(accountMenuButton) {
      .combined(
        .image(named: .person, from: .uiCommons),
        .contentMode(.scaleAspectFit),
        .backgroundColor(dynamic: .background),
        .border(dynamic: .divider),
        .cornerRadius(14, masksToBounds: true),
        .widthAnchor(.equalTo, constant: 28),
        .heightAnchor(.equalTo, constant: 28)
      )
    }

    mut(textSearchView) {
      .combined(
        .subview(of: self),
        .heightAnchor(.equalTo, constant: 48),
        .edges(
          equalTo: self,
          insets: UIEdgeInsets(
            top: -8,
            left: -16,
            bottom: -8,
            right: -16
          ),
          usingSafeArea: false
        )
      )
    }
  }
}

extension HomeSearchView {

  internal var presentationMenuTapPublisher: AnyPublisher<Void, Never> {
    presentationMenuButton.tapPublisher
  }

  internal var accountMenuTapPublisher: AnyPublisher<Void, Never> {
    accountMenuButton.tapPublisher
  }

  internal var searchTextPublisher: AnyPublisher<String, Never> {
    textSearchView.textPublisher
  }

  internal func setSearchText(_ text: String) {
    textSearchView.setText(text)
  }

  internal func setAccountAvatar(image: UIImage) {
    accountMenuButton.image = image
  }
}
