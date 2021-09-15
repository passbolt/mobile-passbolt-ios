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

extension UIViewController {

  public func present(
    overlay: UIView,
    animated: Bool = true
  ) {
    dismissSnackbar(animated: true)
    _overlayView = overlay
    overlay.layer.removeAllAnimations()
    let parentView: UIView = self.view.window ?? self.view
    mut(overlay) {
      .combined(
        .alpha(0),
        .subview(of: parentView),
        .edges(equalTo: parentView, usingSafeArea: false)
      )
    }
    parentView.layoutIfNeeded()
    parentView.bringSubviewToFront(overlay)
    UIView.animate(
      withDuration: animated ? 0.3 : 0,
      delay: 0,
      options: .beginFromCurrentState,
      animations: { overlay.alpha = 1 }
    )
  }

  public func dismissOverlay(
    animated: Bool = true
  ) {
    guard let overlay = _overlayView else { return }
    _overlayView = nil
    UIView.animate(
      withDuration: animated ? 0.3 : 0,
      delay: 0,
      options: [.beginFromCurrentState],
      animations: { overlay.alpha = 0 },
      completion: { _ in
        overlay.removeFromSuperview()
      }
    )
  }
}

extension UIViewController {

  // swift-format-ignore: NoLeadingUnderscores
  fileprivate var _overlayView: UIView? {
    get {
      objc_getAssociatedObject(
        self,
        &overlayViewAssociationKey
      ) as? UIView
    }
    set {
      objc_setAssociatedObject(
        self,
        &overlayViewAssociationKey,
        newValue,
        .OBJC_ASSOCIATION_RETAIN_NONATOMIC
      )
    }
  }
}

private var overlayViewAssociationKey: Int = 0
