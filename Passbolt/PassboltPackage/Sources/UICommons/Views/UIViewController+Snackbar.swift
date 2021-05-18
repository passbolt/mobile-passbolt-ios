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
    snackbar: UIView,
    presentationAnchor: UIView? = nil, // bottom of screen is used if no anchor provided
    hideAfter hideDelay: TimeInterval = 3, // zero is not going to hide automatically
    replaceCurrent: Bool = true, // presentation will be ignored if set to false and other is presented
    animated: Bool = true
  ) {
    guard replaceCurrent || _snackbarView == nil else { return }
    dismissSnackbar(animated: animated)
    _snackbarView = snackbar
    snackbar.layer.removeAllAnimations()
    mut(snackbar) {
      .combined(
        .alpha(0),
        .subview(of: self.view),
        .leadingAnchor(
          .equalTo,
          self.view.safeAreaLayoutGuide.leadingAnchor,
          constant: 24
        ),
        .trailingAnchor(
          .equalTo,
          self.view.safeAreaLayoutGuide.trailingAnchor,
          constant: -24
        ),
        .bottomAnchor(
          .equalTo,
          presentationAnchor.map(\.topAnchor)
            ?? self.view.safeAreaLayoutGuide.bottomAnchor,
          constant: -24
        )
      )
    }
    self.view.layoutIfNeeded()
    UIView.animate(
      withDuration: animated ? 0.3 : 0,
      delay: 0,
      options: [.beginFromCurrentState, .allowUserInteraction],
      animations: { snackbar.alpha = 1 },
      completion: { [weak self] completed in
        guard completed, hideDelay > 0 else { return }
        UIView.animate(
          withDuration: 0.3,
          delay: hideDelay,
          options: [.beginFromCurrentState, .allowUserInteraction],
          animations: { snackbar.alpha = 0 },
          completion: { [weak self] completed in
            if self?._snackbarView === snackbar {
              self?._snackbarView = nil
            } else { /* */ }
            guard completed else { return }
            snackbar.removeFromSuperview()
          }
        )
      }
    )
  }
  
  public func dismissSnackbar(
    animated: Bool = true
  ) {
    guard let snackbar = _snackbarView else { return }
    _snackbarView = nil
    UIView.animate(
      withDuration: animated ? 0.3 : 0,
      delay: 0,
      options: [.beginFromCurrentState],
      animations: { snackbar.alpha = 0 },
      completion: { completed in
        guard completed else { return }
        snackbar.removeFromSuperview()
      }
    )
  }
}

fileprivate extension UIViewController {
  
  var _snackbarView: UIView? {
    get {
      objc_getAssociatedObject(
        self,
        &snackbarViewAssociationKey
      ) as? UIView
    }
    set {
      objc_setAssociatedObject(
        self,
        &snackbarViewAssociationKey,
        newValue,
        .OBJC_ASSOCIATION_RETAIN_NONATOMIC
      )
    }
  }
}

private var snackbarViewAssociationKey: Int = 0
