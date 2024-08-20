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
import SwiftUI

public struct OTPValueView: View {

  public enum Accessory {
    case contextual
    case toggle
    case loader
  }

  private let value: OTPValue?
  private let accessory: Accessory

  public init(
    value: OTPValue?,  // none is covered value
    accessory: Accessory
  ) {
    self.value = value
    self.accessory = accessory
  }

  public var body: some View {
    switch self.value {
    case .totp(let totp):
      HStack(spacing: 12) {
        Text(totp.otp.rawValue.split(every: 3).joined(separator: " "))
          .multilineTextAlignment(.leading)
          .font(
            .inconsolata(
              ofSize: 24,
              weight: .semibold
            )
          )
          .accessibilityIdentifier("totp.digits")

        switch self.accessory {
        case .contextual:
          CountdownCircleView(
            current: totp.timeLeft.rawValue,
            max: totp.period.rawValue
          )

        case .toggle:
          Image(named: .eyeSlash)
            .frame(
              width: 24,
              height: 24
            )

        case .loader:
          SwiftUI.ProgressView()
            .progressViewStyle(.circular)
            .frame(
              width: 24,
              height: 24
            )
        }
      }
      .frame(
        maxWidth: .infinity,
        alignment: .leading
      )
      .foregroundColor(
        totp.timeLeft > 5
          ? Color.passboltPrimaryText
          : Color.passboltSecondaryRed
      )

    case .hotp(let hotp):
      HStack(spacing: 12) {
        Text(hotp.otp.rawValue.split(every: 3).joined(separator: " "))
          .multilineTextAlignment(.leading)
          .font(
            .inconsolata(
              ofSize: 24,
              weight: .semibold
            )
          )

        switch self.accessory {
        case .contextual:
          EmptyView()

        case .toggle:
          Image(named: .eyeSlash)
            .frame(
              width: 24,
              height: 24
            )

        case .loader:
          SwiftUI.ProgressView()
            .progressViewStyle(.circular)
            .frame(
              width: 24,
              height: 24
            )
        }
      }
      .frame(
        maxWidth: .infinity,
        alignment: .leading
      )

    case .none:
      HStack(spacing: 12) {
        Text("••• •••")
          .multilineTextAlignment(.leading)
          .font(
            .inconsolata(
              ofSize: 24,
              weight: .semibold
            )
          )

        switch self.accessory {
        case .contextual:
          EmptyView()

        case .toggle:
          Image(named: .eye)
            .frame(
              width: 24,
              height: 24
            )

        case .loader:
          SwiftUI.ProgressView()
            .progressViewStyle(.circular)
            .frame(
              width: 24,
              height: 24
            )
        }
      }
      .frame(
        maxWidth: .infinity,
        alignment: .leading
      )
    }
  }
}
