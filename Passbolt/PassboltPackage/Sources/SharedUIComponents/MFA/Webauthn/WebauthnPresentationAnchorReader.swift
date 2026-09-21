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

import AuthenticationServices
import SwiftUI
import UIKit

internal struct WebauthnPresentationAnchorReader: UIViewRepresentable {

  private let anchorUpdate: @MainActor (ASPresentationAnchor?) -> Void

  internal init(
    anchorUpdate: @escaping @MainActor (ASPresentationAnchor?) -> Void
  ) {
    self.anchorUpdate = anchorUpdate
  }

  internal func makeUIView(
    context: Context
  ) -> UIView {
    AnchorReadingView(anchorUpdate: self.anchorUpdate)
  }

  internal func updateUIView(
    _ uiView: UIView,
    context: Context
  ) {
    // no-op
  }
}

@MainActor
private final class AnchorReadingView: UIView {

  private let anchorUpdate: @MainActor (ASPresentationAnchor?) -> Void

  fileprivate init(
    anchorUpdate: @escaping @MainActor (ASPresentationAnchor?) -> Void
  ) {
    self.anchorUpdate = anchorUpdate
    super.init(frame: .zero)
    self.isUserInteractionEnabled = false
    self.backgroundColor = .clear
  }

  @available(*, unavailable)
  fileprivate required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  fileprivate override func didMoveToWindow() {
    super.didMoveToWindow()
    self.anchorUpdate(self.window)
  }
}
