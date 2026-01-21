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

internal struct YubiKeyView: ControlledView {

  internal let controller: YubiKeyViewController

  internal init(controller: Controller) {
    self.controller = controller
  }

  internal var body: some View {
    withAlert(
      \.alert,
      content: { content }
    )
  }

  private var content: some View {
    VStack(spacing: 0) {
      Image(named: .yubiKeyLogo)
        .resizable()
        .aspectRatio(contentMode: .fit)
        .frame(width: 80)
        .frame(maxWidth: .infinity)
        .padding(.top, 32)

      Text(displayable: "mfa.yubiKey.title")
        .font(.inter(ofSize: 24, weight: .semibold))
        .minimumScaleFactor(0.5)
        .lineLimit(1)
        .foregroundStyle(Color.passboltPrimaryText)
        .padding(.top, 24)

      Text(displayable: "mfa.yubiKey.description")
        .font(.inter(ofSize: 14, weight: .regular))
        .multilineTextAlignment(.center)
        .minimumScaleFactor(0.5)
        .padding(.top, 16)

      Spacer()

      Toggle(isOn: self.binding(to: \.rememberDevice)) {
        Text(displayable: "totp.remember.device.toggle.label")
          .font(.inter(ofSize: 14, weight: .semibold))
          .foregroundStyle(Color.passboltPrimaryText)
      }
      .padding(.bottom, 32)
      PrimaryButton(
        title: "mfa.yubiKey.scan",
        action: self.controller.startScanning
      )
    }
    .padding(.horizontal, 16)
  }
}
