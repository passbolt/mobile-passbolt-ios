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

internal final class ModifiedResourcesListView: PlainView {

  private let filtersContainer: PlainView = .init()
  private let resourcesListContainer: PlainView = .init()

  override func setup() {
    super.setup()

    mut(self) {
      .combined(
        .backgroundColor(dynamic: .background)
      )
    }

    mut(filtersContainer) {
      .combined(
        .backgroundColor(dynamic: .background),
        .shadow(
          color: .black,
          opacity: 0.2,
          offset: .init(width: 0, height: -10),
          radius: 12
        ),
        .clipsToBounds(false),
        .subview(of: self),
        .topAnchor(.equalTo, topAnchor),
        .leftAnchor(.equalTo, leftAnchor),
        .rightAnchor(.equalTo, rightAnchor)
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

  internal func setFiltersView(_ view: UIView) {
    mut(view) {
      .combined(
        .subview(of: filtersContainer),
        .edges(equalTo: filtersContainer, usingSafeArea: true)
      )
    }
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
