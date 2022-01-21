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

internal final class ResourcesSelectionListSectionHeader: CollectionReusableView {

  private let label: Label = .init()
  private var heightConstraint: NSLayoutConstraint?

  internal required init() {
    super.init()

    mut(self) {
      .combined(
        .backgroundColor(.clear),
        .heightAnchor(.equalTo, constant: 0, referenceOutput: &heightConstraint)
      )
    }

    mut(label) {
      .combined(
        .font(.inter(ofSize: 14, weight: .medium)),
        .textColor(dynamic: .primaryText),
        .textAlignment(.left),
        .numberOfLines(0),
        .subview(of: self),
        .edges(
          equalTo: self,
          insets: .init(
            top: -10,
            left: -16,
            bottom: -10,
            right: -16
          ),
          usingSafeArea: false
        )
      )
    }
  }

  internal func setTitle(
    _ displayable: DisplayableString?
  ) {
    if let displayableString: DisplayableString = displayable {
      mut(label) {
        .text(displayable: displayableString)
      }
      heightConstraint?.constant = 44
    }
    else {
      heightConstraint?.constant = 0
    }
  }

  override func prepareForReuse() {
    super.prepareForReuse()

    label.text = ""
    heightConstraint?.constant = 0
  }
}
