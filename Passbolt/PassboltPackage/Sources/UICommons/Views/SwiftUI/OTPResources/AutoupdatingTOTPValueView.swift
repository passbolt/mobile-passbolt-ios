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

public struct AutoupdatingTOTPValueView: View {

  @State private var value: TOTPValue?
  private let generateTOTP: (@Sendable () -> TOTPValue)?

  public init(
    generateTOTP: (@Sendable () -> TOTPValue)?
  ) {
    self.generateTOTP = generateTOTP
  }

  public var body: some View {
    HStack(spacing: 12) {
      if let value {
        Group {
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
      }
    }
    .frame(
      maxWidth: .infinity,
      alignment: .leading
    )
    .task {
      guard let generateTOTP
      else {
        self.value = .none
        return
      }  // no updates available

      if #available(iOS 16.0, *) {
        var iterator: AsyncTimerSequence<ContinuousClock>.Iterator = AsyncTimerSequence(
          interval: .seconds(1),
          clock: .continuous
        )
        .makeAsyncIterator()
        repeat {
          self.value = generateTOTP()
        }
        while await iterator.next() != nil

      }
      else {
        // this is not fully correct, it will drift quickly but it is about to be dropped
        repeat {
          self.value = generateTOTP()
        }
        while (try? await Task.sleep(nanoseconds: NSEC_PER_SEC)) != nil
      }
    }
  }
}
