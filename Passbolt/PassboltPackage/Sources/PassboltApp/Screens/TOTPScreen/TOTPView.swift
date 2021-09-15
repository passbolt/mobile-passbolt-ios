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

import Combine
import UICommons

internal final class TOTPView: KeyboardAwareView {

  internal var otpPublisher: AnyPublisher<String, Never>
  internal var pasteOTPTapPublisher: AnyPublisher<Void, Never>
  internal var rememberDeviceToggleTapPublisher: AnyPublisher<Void, Never>

  private let otpInput: OTPInput = .init(length: TOTPController.otpLength)
  private let rememberDeviceSwitch: UISwitch = .init()
  private let rememberDeviceToggle: Button = .init()

  internal required init() {
    otpPublisher = otpInput.textPublisher
    let pasteOTPButton: Button = .init()
    pasteOTPTapPublisher = pasteOTPButton.tapPublisher
    rememberDeviceToggleTapPublisher = rememberDeviceToggle.tapPublisher
    super.init()

    mut(self) {
      .backgroundColor(dynamic: .background)
    }

    let imageContainer: View = .init()
    mut(imageContainer) {
      .combined(
        .backgroundColor(dynamic: .background),
        .subview(of: self),
        .topAnchor(.equalTo, safeAreaLayoutGuide.topAnchor, constant: 32),
        .leadingAnchor(.equalTo, leadingAnchor, constant: 16),
        .trailingAnchor(.equalTo, trailingAnchor, constant: -16)
      )
    }

    let imageView: ImageView = .init()
    mut(imageView) {
      .combined(
        .image(dynamic: .totp),
        .subview(of: imageContainer),
        .contentMode(.scaleAspectFit),
        .topAnchor(.equalTo, imageContainer.topAnchor),
        .bottomAnchor(.equalTo, imageContainer.bottomAnchor),
        .centerXAnchor(.equalTo, imageContainer.centerXAnchor),
        .widthAnchor(.lessThanOrEqualTo, imageContainer.widthAnchor, multiplier: 0.6)
      )
    }

    let titleLabel: Label = .init()
    mut(titleLabel) {
      .combined(
        .font(.inter(ofSize: 32, weight: .regular)),
        .tintColor(dynamic: .primaryText),
        .textAlignment(.center),
        .numberOfLines(1),
        .text(localized: "totp.title.label"),
        .subview(of: self),
        .topAnchor(.equalTo, imageContainer.bottomAnchor, constant: 24),
        .leadingAnchor(.equalTo, leadingAnchor, constant: 16),
        .trailingAnchor(.equalTo, trailingAnchor, constant: -16)
      )
    }

    let messageLabel: Label = .init()
    mut(messageLabel) {
      .combined(
        .font(.inter(ofSize: 16, weight: .regular)),
        .tintColor(dynamic: .primaryText),
        .textAlignment(.center),
        .numberOfLines(1),
        .text(localized: "totp.message.label"),
        .subview(of: self),
        .topAnchor(.equalTo, titleLabel.bottomAnchor, constant: 16),
        .leadingAnchor(.equalTo, leadingAnchor, constant: 16),
        .trailingAnchor(.equalTo, trailingAnchor, constant: -16)
      )
    }

    mut(otpInput) {
      .combined(
        .subview(of: self),
        .heightAnchor(.equalTo, constant: 60),
        .topAnchor(.equalTo, messageLabel.bottomAnchor, constant: 16),
        .leadingAnchor(.equalTo, leadingAnchor, constant: 16),
        .trailingAnchor(.equalTo, trailingAnchor, constant: -16)
      )
    }

    mut(pasteOTPButton) {
      .combined(
        .subview(of: self),
        .topAnchor(.equalTo, otpInput.bottomAnchor, constant: 16),
        .leadingAnchor(.greaterThanOrEqualTo, leadingAnchor, constant: 16),
        .trailingAnchor(.equalTo, trailingAnchor, constant: -16)
      )
    }

    let pasteOTPLabel: Label = .init()
    mut(pasteOTPLabel) {
      .combined(
        .font(.inter(ofSize: 16, weight: .regular)),
        .textColor(dynamic: .primaryBlue),
        .textAlignment(.natural),
        .numberOfLines(1),
        .text(localized: "totp.paste.otp.button.label"),
        .subview(of: pasteOTPButton),
        .leadingAnchor(.equalTo, pasteOTPButton.leadingAnchor),
        .topAnchor(.equalTo, pasteOTPButton.topAnchor),
        .bottomAnchor(.equalTo, pasteOTPButton.bottomAnchor)
      )
    }

    let pasteOTPImage: ImageView = .init()
    mut(pasteOTPImage) {
      .combined(
        .image(named: .copy, from: .uiCommons),
        .tintColor(dynamic: .primaryBlue),
        .subview(of: pasteOTPButton),
        .leadingAnchor(.equalTo, pasteOTPLabel.trailingAnchor, constant: 8),
        .trailingAnchor(.equalTo, pasteOTPButton.trailingAnchor),
        .topAnchor(.equalTo, pasteOTPButton.topAnchor),
        .bottomAnchor(.equalTo, pasteOTPButton.bottomAnchor)
      )
    }

    let rememberDeviceContainer: View = .init()
    mut(rememberDeviceContainer) {
      .combined(
        .subview(of: self),
        .topAnchor(.equalTo, pasteOTPButton.bottomAnchor, constant: 96),
        .leadingAnchor(.equalTo, leadingAnchor, constant: 16),
        .trailingAnchor(.equalTo, trailingAnchor, constant: -16),
        .bottomAnchor(.lessThanOrEqualTo, bottomAnchor, constant: -16)
      )
    }

    let rememberDeviceLabel: Label = .init()
    mut(rememberDeviceLabel) {
      .combined(
        .font(.inter(ofSize: 16, weight: .regular)),
        .textColor(dynamic: .primaryText),
        .textAlignment(.natural),
        .numberOfLines(1),
        .text(localized: "totp.remember.device.toggle.label"),
        .subview(of: rememberDeviceContainer),
        .topAnchor(.equalTo, rememberDeviceContainer.topAnchor),
        .leadingAnchor(.equalTo, rememberDeviceContainer.leadingAnchor),
        .bottomAnchor(.equalTo, rememberDeviceContainer.bottomAnchor)
      )
    }

    mut(rememberDeviceToggle) {
      .combined(
        .backgroundColor(.clear),
        .subview(of: rememberDeviceContainer),
        .topAnchor(.equalTo, rememberDeviceContainer.topAnchor),
        .leadingAnchor(.greaterThanOrEqualTo, rememberDeviceLabel.trailingAnchor, constant: 8),
        .trailingAnchor(.equalTo, rememberDeviceContainer.trailingAnchor),
        .bottomAnchor(.equalTo, rememberDeviceContainer.bottomAnchor)
      )
    }

    mut(rememberDeviceSwitch) {
      .combined(
        .userInteractionEnabled(false),
        .subview(of: rememberDeviceToggle),
        .edges(
          equalTo: rememberDeviceToggle,
          insets: .init(top: 0, left: 0, bottom: 0, right: -3)
        )
      )
    }
  }

  internal func update(otp: String) {
    otpInput.text = otp
  }

  internal func update(rememberDevice: Bool) {
    rememberDeviceSwitch.setOn(rememberDevice, animated: window != nil)
  }
}
