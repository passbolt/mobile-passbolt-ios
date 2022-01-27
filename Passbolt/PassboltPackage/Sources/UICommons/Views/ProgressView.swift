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

import CommonModels
import UIKit

public final class ProgressView: View {

  override public var dynamicTintColor: DynamicColor? {
    get { super.dynamicTintColor }
    set {
      super.dynamicTintColor = newValue
      progressBar.dynamicBackgroundColor = newValue ?? .background
    }
  }
  override public var intrinsicContentSize: CGSize { UIView.layoutFittingExpandedSize }
  private let progressBar: View = .init()
  private var progressWidthConstraint: NSLayoutConstraint?

  override public func setup() {
    mut(self) {
      .combined(
        .backgroundColor(dynamic: .divider),
        .cornerRadius(4, masksToBounds: true),
        .heightAnchor(.equalTo, constant: 8)
      )
    }
    mut(progressBar) {
      .combined(
        .backgroundColor(dynamic: dynamicTintColor ?? .background),
        .subview(of: self),
        .cornerRadius(4, masksToBounds: true),
        .topAnchor(.equalTo, topAnchor),
        .bottomAnchor(.equalTo, bottomAnchor),
        .leadingAnchor(.equalTo, leadingAnchor),
        .trailingAnchor(.lessThanOrEqualTo, trailingAnchor),
        .widthAnchor(.equalTo, constant: 0, referenceOutput: &progressWidthConstraint)
      )
    }
  }

  public func update(
    progress: Double,
    animated: Bool
  ) {
    assert(progress >= 0, "Cannot display progress less than zero")
    assert(progress <= 1, "Cannot display progress greather than one")
    progressWidthConstraint?.isActive = false
    mut(progressBar) {
      .widthAnchor(
        .equalTo,
        widthAnchor,
        multiplier: CGFloat(progress),
        referenceOutput: &progressWidthConstraint
      )
    }
    UIView.animate(withDuration: animated ? 0.3 : 0) {
      self.layoutIfNeeded()
    }
  }
}
