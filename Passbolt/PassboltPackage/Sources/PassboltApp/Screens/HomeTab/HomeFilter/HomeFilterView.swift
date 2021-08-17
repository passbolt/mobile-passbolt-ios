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

internal final class HomeFilterView: View {

  // filters are out of MVP scope
  // but its view should be located above the resourcesListContainer
  // and it is used to provide shadow drop on list below
  // replace it with proper filters when needed
  private let filtersPlaceholder: View = .init()
  private let resourcesListContainer: View = .init()

  override func setup() {
    super.setup()

    mut(self) {
      .combined(
        .backgroundColor(dynamic: .background)
      )
    }

    mut(self.filtersPlaceholder) {
      .combined(
        .backgroundColor(dynamic: .background),
        .shadow(color: .black, opacity: 0.2, offset: .init(width: 0, height: -10), radius: 12),
        .clipsToBounds(false),
        .subview(of: self),
        .heightAnchor(.equalTo, constant: 12),
        .topAnchor(.equalTo, self.topAnchor),
        .leftAnchor(.equalTo, self.leftAnchor),
        .rightAnchor(.equalTo, self.rightAnchor)
      )
    }

    mut(self.resourcesListContainer) {
      .combined(
        .subview(of: self),
        .topAnchor(.equalTo, self.filtersPlaceholder.bottomAnchor),
        .leftAnchor(.equalTo, self.leftAnchor),
        .rightAnchor(.equalTo, self.rightAnchor),
        .bottomAnchor(.equalTo, self.bottomAnchor)
      )
    }

    self.bringSubviewToFront(self.filtersPlaceholder)
  }

  internal func setResourcesView(_ view: UIView) {
    mut(view) {
      .combined(
        .subview(of: self.resourcesListContainer),
        .edges(equalTo: self.resourcesListContainer, usingSafeArea: false)
      )
    }
  }
}
