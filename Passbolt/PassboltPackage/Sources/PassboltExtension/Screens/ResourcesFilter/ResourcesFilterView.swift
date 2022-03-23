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

internal final class ResourcesFilterView: PlainView {

  internal var searchTextPublisher: AnyPublisher<String, Never> {
    searchBar.textPublisher
  }
  internal var avatarTapPublisher: AnyPublisher<Void, Never>
  private let avatarButton: ImageButton
  private let searchBar: TextSearchView
  private let resourcesListContainer: PlainView = .init()

  required init() {
    let avatarTapSubject: PassthroughSubject<Void, Never> = .init()
    self.avatarTapPublisher = avatarTapSubject.eraseToAnyPublisher()
    let avatarButton: ImageButton = .init()
    self.avatarButton = avatarButton
    self.searchBar = .init(rightAccesoryView: avatarButton)
    super.init()

    mut(self) {
      .combined(
        .backgroundColor(dynamic: .background)
      )
    }

    let filtersContainer: PlainView = .init()
    mut(filtersContainer) {
      .combined(
        .backgroundColor(dynamic: .background),
        .shadow(color: .black, opacity: 0.2, offset: .init(width: 0, height: -10), radius: 12),
        .clipsToBounds(false),
        .subview(of: self),
        .topAnchor(.equalTo, topAnchor),
        .leftAnchor(.equalTo, leftAnchor),
        .rightAnchor(.equalTo, rightAnchor)
      )
    }

    mut(avatarButton) {
      .combined(
        .action(avatarTapSubject.send),
        .image(named: .person, from: .uiCommons),
        .contentMode(.scaleAspectFit),
        .backgroundColor(dynamic: .background),
        .border(dynamic: .divider),
        .cornerRadius(14, masksToBounds: true),
        .widthAnchor(.equalTo, constant: 28),
        .heightAnchor(.equalTo, constant: 28)
      )
    }

    mut(searchBar) {
      .combined(
        .subview(of: filtersContainer),
        .heightAnchor(.equalTo, constant: 48),
        .edges(
          equalTo: filtersContainer,
          insets: .init(
            top: 0,
            left: -16,
            bottom: -8,
            right: -16
          ),
          usingSafeArea: true
        )
      )
    }

    mut(resourcesListContainer) {
      .combined(
        .subview(of: self),
        .topAnchor(.equalTo, filtersContainer.bottomAnchor),
        .leftAnchor(.equalTo, leftAnchor),
        .rightAnchor(.equalTo, rightAnchor),
        .bottomAnchor(.equalTo, bottomAnchor)
      )
    }

    bringSubviewToFront(filtersContainer)
  }

  internal func setSearchText(_ text: String) {
    searchBar.setText(text)
  }

  internal func setAvatarImage(_ image: UIImage) {
    avatarButton.image = image
  }

  internal func setResourcesView(_ view: UIView) {
    mut(view) {
      .combined(
        .subview(of: resourcesListContainer),
        .edges(equalTo: resourcesListContainer, usingSafeArea: false)
      )
    }
  }
}
