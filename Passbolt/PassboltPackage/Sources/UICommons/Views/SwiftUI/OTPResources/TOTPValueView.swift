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

public struct TOTPValueView: View {

  private let value: TOTPValue?

  public init(
    value: TOTPValue?  // none is covered value
  ) {
    self.value = value
  }

  public var body: some View {
    if let value {
      HStack(spacing: 12) {
        Text(value.otp.rawValue.split(every: 3).joined(separator: " "))
          .multilineTextAlignment(.leading)
          .font(
            .inconsolata(
              ofSize: 24,
              weight: .semibold
            )
          )

        CountdownCircleView(
          current: value.timeLeft.rawValue,
          max: value.period.rawValue
        )
      }
      .frame(
        maxWidth: .infinity,
        alignment: .leading
      )
      .foregroundColor(
        value.timeLeft > 5
          ? Color.passboltPrimaryText
          : Color.passboltSecondaryRed
      )
    }
    else {
      Text("••• •••")
        .multilineTextAlignment(.leading)
        .font(
          .inconsolata(
            ofSize: 24,
            weight: .semibold
          )
        )
        .frame(
          maxWidth: .infinity,
          alignment: .leading
        )
    }
  }
}
