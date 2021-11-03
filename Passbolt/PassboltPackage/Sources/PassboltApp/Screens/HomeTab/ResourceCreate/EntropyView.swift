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

import Features
import UICommons

internal final class EntropyView: View {

  private let indicator: View = .init()
  private let label: Label = .init()

  private var indicatorWidthConstraint: NSLayoutConstraint?

  internal required init() {
    super.init()

    let indicatorContainer: View =
      Mutation.combined(
        .subview(of: self),
        .leadingAnchor(.equalTo, leadingAnchor),
        .trailingAnchor(.equalTo, trailingAnchor),
        .topAnchor(.equalTo, topAnchor)
      )
      .instantiate()

    mut(indicator) {
      .combined(
        .subview(of: indicatorContainer),
        .leadingAnchor(.equalTo, indicatorContainer.leadingAnchor),
        .topAnchor(.equalTo, indicatorContainer.topAnchor),
        .heightAnchor(.equalTo, constant: 8),
        .widthAnchor(
          .equalTo,
          widthAnchor,
          multiplier: 1,
          referenceOutput: &self.indicatorWidthConstraint
        ),
        .backgroundColor(dynamic: .background),
        .border(dynamic: .divider, width: 1),
        .cornerRadius(4)
      )
    }

    mut(label) {
      .combined(
        .subview(of: self),
        .topAnchor(.equalTo, indicator.bottomAnchor, constant: 8),
        .leadingAnchor(.equalTo, leadingAnchor),
        .trailingAnchor(.equalTo, trailingAnchor),
        .bottomAnchor(.equalTo, bottomAnchor, constant: -8),
        .font(.inter(ofSize: 14, weight: .medium)),
        .textColor(dynamic: .tertiaryText),
        .text(localized: "resource.form.password.strength", inBundle: .commons)
      )
    }
  }

  internal func update(entropy: Entropy) {
    let multiplier: CGFloat
    let key: StaticString
    let color: DynamicColor

    switch entropy {
    case Entropy.zero..<Entropy.veryWeakPassword:
      key = "resource.form.password.strength"
      multiplier = 1
      color = .background
    case Entropy.veryWeakPassword..<Entropy.weakPassword:
      key = "resource.form.strength.very.weak"
      multiplier = 0.2
      color = .background
    case Entropy.weakPassword..<Entropy.fairPassword:
      key = "resource.form.strength.weak"
      multiplier = 0.4
      color = .secondaryRed
    case Entropy.fairPassword..<Entropy.strongPassword:
      key = "resource.form.strength.fair"
      multiplier = 0.6
      color = .secondaryOrange
    case Entropy.strongPassword..<Entropy.veryStrongPassword:
      key = "resource.form.strength.strong"
      multiplier = 0.8
      color = .secondaryGreen
    case Entropy.veryStrongPassword..<Entropy.greatestFinite:
      key = "resource.form.strength.very.strong"
      multiplier = 1
      color = .secondaryGreen
    case _:
      key = "resource.form.password.strength"
      multiplier = 1
      color = .background
    }

    if let indicatorWidthConstraint = indicatorWidthConstraint {
      removeConstraint(indicatorWidthConstraint)
    }
    else {
      /* NOP */
    }

    mut(label) {
      .text(localized: .init(stringLiteral: key), inBundle: .commons)
    }

    mut(indicator) {
      .combined(
        .backgroundColor(dynamic: color),
        .widthAnchor(
          .equalTo,
          widthAnchor,
          multiplier: multiplier,
          referenceOutput: &self.indicatorWidthConstraint
        )
      )
    }
  }
}
