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

import SwiftUI

public struct CountdownCircleView: View {

  private let value: CGFloat

  public init<RawValue>(
    current: RawValue,
    max: RawValue
  ) where RawValue: BinaryInteger {
    if current <= 0 || max <= 0 || max < current {
      self.value = .leastNonzeroMagnitude
    }
    else {
      self.value = CGFloat(current) / CGFloat(max)
    }
  }

  public init(
    value: CGFloat
  ) {
    if value < 0 {
      self.value = 0
    }
    else {
      self.value = value
    }
  }

  public var body: some View {
    ZStack {
      Circle()
        .stroke(
          Color.passboltIcon,
          style: .init(
            lineWidth: 2
          )
        )

      Circle()
        .trim(
          from: 0,
          to: self.value
        )
        .rotation(.degrees(-90))
        .stroke(
          style: .init(
            lineWidth: 2,
            lineCap: .round,
            lineJoin: .round
          )
        )
        .animation(
          .easeOut,
          value: self.value
        )
    }
    .padding(4)
    .frame(
      width: 24,
      height: 24
    )
    .accessibilityIdentifier("totp.loader.circle")
  }
}

#if DEBUG

private struct RunningTimerView<Content>: View
where Content: View {

  @State private var runningValue: UInt = 30
  @State private var timer =
    Timer
    .publish(every: 1, on: .main, in: .common)
    .autoconnect()
  private let content: (UInt) -> Content

  fileprivate init(
    @ViewBuilder content: @escaping (UInt) -> Content
  ) {
    self.content = content
  }

  var body: some View {
    self.content(self.runningValue)
      .onReceive(timer) { _ in
        if self.runningValue == 0 {
          self.runningValue = 30
        }
        else {
          self.runningValue -= 1
        }
      }
  }
}

internal struct CountdownCircleView_Previews: PreviewProvider {

  internal static var previews: some View {
    ScrollView {
      RunningTimerView { value in
        CountdownCircleView(
          value: CGFloat(value) / 30
        )
      }
      .frame(maxWidth: 24)

      CountdownCircleView(
        value: 0
      )
      .frame(maxWidth: 24)

      CountdownCircleView(
        value: -10
      )
      .frame(maxWidth: 24)

      CountdownCircleView(
        current: 30,
        max: 30
      )
      .frame(maxWidth: 24)

      CountdownCircleView(
        current: 20,
        max: 30
      )
      .frame(maxWidth: 24)

      CountdownCircleView(
        current: 5,
        max: 30
      )
      .frame(maxWidth: 24)

      CountdownCircleView(
        current: 1,
        max: 30
      )
      .frame(maxWidth: 24)

      CountdownCircleView(
        current: 0,
        max: 30
      )
      .frame(maxWidth: 24)

      CountdownCircleView(
        current: 30,
        max: 0
      )
      .frame(maxWidth: 24)
    }
    .padding(16)
  }
}
#endif
