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

internal final class YubikeyView: PlainView {

  internal var toggleRememberDevicePublisher: AnyPublisher<Void, Never> { labeledSwitch.togglePublisher }
  internal var scanTapPublisher: AnyPublisher<Void, Never> { scanButton.tapPublisher }

  private let imageView: ImageView = .init()
  private let titleLabel: Label = .init()
  private let descriptionLabel: Label = .init()
  private let labeledSwitch: LabeledSwitch
  private let scanButton: TextButton = .init()

  internal required init() {
    self.labeledSwitch = .init()
    super.init()

    mut(imageView) {
      .combined(
        .subview(of: self),
        .topAnchor(.equalTo, safeAreaLayoutGuide.topAnchor, constant: 32),
        .leadingAnchor(.equalTo, leadingAnchor),
        .trailingAnchor(.equalTo, trailingAnchor),
        .contentMode(.scaleAspectFit),
        .image(named: .yubikeyLogo, from: .uiCommons)
      )
    }

    mut(titleLabel) {
      .combined(
        .subview(of: self),
        .leadingAnchor(.equalTo, leadingAnchor),
        .trailingAnchor(.equalTo, trailingAnchor),
        .topAnchor(.equalTo, imageView.bottomAnchor, constant: 24),
        .font(.inter(ofSize: 24, weight: .semibold)),
        .textColor(dynamic: .primaryText),
        .text(displayable: .localized(key: "mfa.yubikey.title")),
        .textAlignment(.center)
      )
    }

    mut(descriptionLabel) {
      .combined(
        .subview(of: self),
        .leadingAnchor(.equalTo, leadingAnchor),
        .trailingAnchor(.equalTo, trailingAnchor),
        .topAnchor(.equalTo, titleLabel.bottomAnchor, constant: 16),
        .font(.inter(ofSize: 14)),
        .textColor(dynamic: .primaryText),
        .text(displayable: .localized(key: "mfa.yubikey.description")),
        .numberOfLines(0),
        .lineBreakMode(.byWordWrapping),
        .textAlignment(.center)
      )
    }

    mut(labeledSwitch) {
      .combined(
        .subview(of: self),
        .leadingAnchor(.equalTo, leadingAnchor),
        .trailingAnchor(.equalTo, trailingAnchor),
        .topAnchor(.greaterThanOrEqualTo, descriptionLabel.bottomAnchor, constant: 50),
        .custom { (subject: LabeledSwitch) in
          subject.applyOn(
            label: .combined(
              .font(.inter(ofSize: 14, weight: .semibold)),
              .textColor(dynamic: .primaryText),
              .text(
                displayable: .localized(key: "mfa.remember.token")
              )
            )
          )
        }
      )
    }

    mut(scanButton) {
      .combined(
        .subview(of: self),
        .leadingAnchor(.equalTo, leadingAnchor),
        .trailingAnchor(.equalTo, trailingAnchor),
        .topAnchor(.equalTo, labeledSwitch.bottomAnchor, constant: 38),
        .bottomAnchor(.equalTo, bottomAnchor, constant: -8),
        .primaryStyle(),
        .text(displayable: .localized(key: "mfa.yubikey.scan"))
      )
    }
  }

  internal func update(rememberDevice: Bool) {
    labeledSwitch.update(isOn: rememberDevice)
  }
}
