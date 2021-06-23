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

import Commons
import struct Environment.Biometrics
import UICommons

internal final class BiometricsInfoView: ScrolledStackView {
  
  internal var setupTapPublisher: AnyPublisher<Void, Never>
  internal var skipTapPublisher: AnyPublisher<Void, Never>
  
  private let imageView: ImageView = .init()
  private let titleLabel: Label = .init()
  private let descriptionLabel: Label = .init()
  private let setupButton: TextButton = .init()
  
  internal required init() {
    let skipButton: TextButton = .init()
    
    self.setupTapPublisher = setupButton.tapPublisher
    self.skipTapPublisher = skipButton.tapPublisher
    super.init()
    
    let imageContainer: View = .init()
    mut(imageContainer) {
      .backgroundColor(dynamic: .background)
    }
    
    #warning("TODO: replace image with generic graphic when available")
    mut(imageView) {
      .combined(
        .image(dynamic: .touchID),
        .subview(of: imageContainer),
        .image(named: .welcomeAccounts),
        .contentMode(.scaleAspectFit),
        .topAnchor(.equalTo, imageContainer.topAnchor),
        .bottomAnchor(.equalTo, imageContainer.bottomAnchor),
        .centerXAnchor(.equalTo, imageContainer.centerXAnchor),
        .widthAnchor(.lessThanOrEqualTo, imageContainer.widthAnchor, multiplier: 0.8),
        .accessibilityIdentifier("welcome.accounts.imageview")
      )
    }
    
    mut(titleLabel) {
      .combined(
        .text(localized: "biometrics.info.title"),
        .titleStyle(),
        .text(localized: "biometrics.info.title"),
        .accessibilityIdentifier("biometrics.info.title.label")
      )
    }
    
    mut(descriptionLabel) {
      .combined(
        .text(localized: "biometrics.info.description"),
        .font(.inter(ofSize: 14)),
        .lineBreakMode(.byWordWrapping),
        .textAlignment(.center),
        .numberOfLines(0),
        .textColor(dynamic: .secondaryText),
        .text(localized: "biometrics.info.description"),
        .accessibilityIdentifier("biometrics.info.description.label")
      )
    }
    
    mut(setupButton) {
      .combined(
        .primaryStyle(),
        .text(localized: "biometrics.info.setup.button"),
        .accessibilityIdentifier("biometrics.info.setup.button")
      )
    }
    
    mut(skipButton) {
      .combined(
        .text(localized: "biometrics.info.setup.button"),
        .linkStyle(),
        .text(localized: "biometrics.info.later.button"),
        .accessibilityIdentifier("biometrics.info.later.button")
      )
    }
    
    mut(self) {
      .combined(
        .backgroundColor(dynamic: .background),
        .axis(.vertical),
        .isLayoutMarginsRelativeArrangement(true),
        .contentInset(.init(top: 8, left: 16, bottom: 8, right: 16)),
        .append(imageContainer),
        .appendSpace(of: 56),
        .append(titleLabel),
        .appendSpace(of: 16),
        .append(descriptionLabel),
        .appendFiller(minSize: 8),
        .append(setupButton),
        .append(skipButton)
      )
    }
  }
}
