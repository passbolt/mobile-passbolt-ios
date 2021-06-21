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

internal final class ExtensionSetupView: ScrolledStackView {
  
  internal var closeTapPublisher: AnyPublisher<Void, Never>
  internal var backToAppTapPublisher: AnyPublisher<Void, Never>
  
  internal required init() {
    let closeButton: TextButton = .init()
    let backToAppButton: TextButton = .init()
    
    self.closeTapPublisher = closeButton.tapPublisher
    self.backToAppTapPublisher = backToAppButton.tapPublisher
    
    super.init()
    
    let imageContainer: View = .init()
    mut(imageContainer) {
      .backgroundColor(dynamic: .background)
    }
    
    let imageView: ImageView = .init()
    mut(imageView) {
      .combined(
        .subview(of: imageContainer),
        .image(dynamic: .successMark),
        .contentMode(.scaleAspectFit),
        .topAnchor(.equalTo, imageContainer.topAnchor),
        .bottomAnchor(.equalTo, imageContainer.bottomAnchor),
        .centerXAnchor(.equalTo, imageContainer.centerXAnchor),
        .widthAnchor(.lessThanOrEqualTo, imageContainer.widthAnchor, multiplier: 0.4)
      )
    }

    let titleLabel: Label = .init()
    mut(titleLabel) {
      .combined(
        .titleStyle(),
        .text(localized: "extension.setup.title")
      )
    }

    let infoLabel: Label = .init()
    mut(infoLabel) {
      .combined(
        .infoStyle(),
        .text(localized: "extension.setup.info")
      )
    }

    mut(closeButton) {
      .combined(
        .primaryStyle(),
        .text(localized: .done, inBundle: .commons)
      )
    }

    mut(backToAppButton) {
      .combined(
        .linkStyle(),
        .text(localized: "extension.setup.button.back.to.app")
      )
    }

    mut(self) {
      .combined(
        .backgroundColor(dynamic: .background),
        .isLayoutMarginsRelativeArrangement(true),
        .contentInset(.init(top: 54, left: 16, bottom: 8, right: 16)),
        .append(imageContainer),
        .appendSpace(of: 32),
        .append(titleLabel),
        .appendSpace(of: 16),
        .append(infoLabel),
        .appendFiller(minSize: 8),
        .append(closeButton),
        .append(backToAppButton)
      )
    }
  }
}
