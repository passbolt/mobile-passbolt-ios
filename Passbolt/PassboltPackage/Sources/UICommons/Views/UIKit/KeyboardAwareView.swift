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

open class KeyboardAwareView: PlainView {

  private lazy var backgroundTapGestureDelegate: BackgroundTapGestureDelegate = {
    let backgroundTapGesture: UITapGestureRecognizer = .init(
      target: self,
      action: #selector(backgroundTapEditingEndHandler)
    )
    let backgroundTapGestureDelegate: BackgroundTapGestureDelegate = .init(backgroundTapGesture: backgroundTapGesture)
    backgroundTapGesture.delegate = backgroundTapGestureDelegate
    self.addGestureRecognizer(backgroundTapGesture)
    return backgroundTapGestureDelegate
  }()

  public required init() {
    super.init()
    setupBackgroundTapEditingEndHandler()
  }

  private func setupBackgroundTapEditingEndHandler() {
    _ = backgroundTapGestureDelegate  // load variable
  }

  @objc private func backgroundTapEditingEndHandler() {
    dispatchPrecondition(condition: .onQueue(.main))
    endEditing(true)
  }
}

private final class BackgroundTapGestureDelegate: NSObject, UIGestureRecognizerDelegate {

  fileprivate weak var backgroundTapGesture: UIGestureRecognizer?

  fileprivate init(backgroundTapGesture: UIGestureRecognizer?) {
    self.backgroundTapGesture = backgroundTapGesture
  }

  fileprivate func gestureRecognizer(
    _ gestureRecognizer: UIGestureRecognizer,
    shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer
  ) -> Bool {
    guard gestureRecognizer === backgroundTapGesture else { return true }
    return false
  }

  fileprivate func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
    !(touch.view is UIControl)
  }

  fileprivate func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive press: UIPress) -> Bool {
    false
  }
}
