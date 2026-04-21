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

import Display

internal struct TOTPView: ControlledView {

  internal let controller: TOTPViewController

  internal init(controller: TOTPViewController) {
    self.controller = controller
  }

  internal var body: some View {
    VStack(spacing: 0) {

      Image(named: .totp)
        .resizable()
        .aspectRatio(contentMode: .fit)
        .frame(width: 80)
        .frame(maxWidth: .infinity)
        .padding(.top, 32)

      Text(displayable: "totp.title.label")
        .font(.inter(ofSize: 32, weight: .regular))
        .minimumScaleFactor(0.5)
        .lineLimit(1)
        .foregroundStyle(Color.passboltPrimaryText)
        .padding(.top, 24)

      Text(displayable: "totp.message.label")
        .font(.inter(ofSize: 16, weight: .regular))
        .lineLimit(1)
        .minimumScaleFactor(0.5)
        .padding(.top, 16)

      OTPInputView(
        otpLength: TOTPViewController.otpLength,
        onCodeEntered: self.controller.otpEntered(_:)
      )
      .frame(height: 60)
      .padding(.top, 16)
      HStack {
        Spacer()
        AsyncButton(
          action: {},
          label: {
            HStack(spacing: 8) {
              Text(displayable: "totp.paste.otp.button.label")
                .font(.inter(ofSize: 16, weight: .medium))
                .foregroundStyle(Color.passboltPrimaryBlue)
              Image(named: .copy)
            }
          }
        )
      }
      .padding(.top, 16)

      Toggle(isOn: self.binding(to: \.rememberDevice)) {
        Text(displayable: "totp.remember.device.toggle.label")
          .font(.inter(ofSize: 14, weight: .semibold))
          .foregroundStyle(Color.passboltPrimaryText)
      }
      .padding(.top, 96)
      Spacer()
    }
    .padding(.horizontal, 16)
  }
}

private struct OTPInputView: UIViewRepresentable {
  private let otpLength: Int
  private let onCodeEntered: (String) -> Void

  fileprivate init(otpLength: Int, onCodeEntered: @escaping (String) -> Void) {
    self.otpLength = otpLength
    self.onCodeEntered = onCodeEntered
  }

  fileprivate func makeUIView(context: Context) -> UICommons.OTPInput {
    let view = UICommons.OTPInput(length: otpLength)
    context.coordinator.configure(view)
    return view
  }

  fileprivate func updateUIView(_ uiView: UICommons.OTPInput, context: Context) {
    /** no-op */
  }

  fileprivate func makeCoordinator() -> Coordinator {
    Coordinator(
      onCodeEntered: onCodeEntered
    )
  }

  fileprivate final class Coordinator {
    private let onCodeEntered: (String) -> Void
    private var cancellable: AnyCancellable?

    fileprivate init(onCodeEntered: @escaping (String) -> Void) {
      self.onCodeEntered = onCodeEntered
    }

    fileprivate func configure(_ view: UICommons.OTPInput) {
      cancellable = view.textPublisher
        .filter { $0.count == view.length }
        .sink { [weak self] (otp: String) in
          self?.onCodeEntered(otp)
        }
    }
  }
}
