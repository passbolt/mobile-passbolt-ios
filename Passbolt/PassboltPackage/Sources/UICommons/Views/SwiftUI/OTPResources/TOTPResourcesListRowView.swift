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

import CommonModels
import SwiftUI

public struct TOTPResourcesListRowView<Accessory>: View
where Accessory: View {

  private let title: String
  private let value: TOTPValue?  // .none means hidden
  private let action: () -> Void
  private let accessory: () -> Accessory

  public init(
    title: String,
    value: TOTPValue?,
    action: @escaping () -> Void,
    @ViewBuilder accessory: @escaping () -> Accessory
  ) {
    self.title = title
    self.value = value
    self.action = action
    self.accessory = accessory
  }

  public var body: some View {
    HStack(spacing: 12) {
      LetterIconView(text: self.title)
        .frame(
          width: 40,
          height: 40
        )

      VStack(spacing: 4) {
        Text(self.title)
          .multilineTextAlignment(.leading)
          .frame(
            maxWidth: .infinity,
            alignment: .leading
          )
          .font(
            .inter(
              ofSize: 12,
              weight: .semibold
            )
          )

        Button(
          action: self.action,
          label: {
            if let totpValue: TOTPValue = self.value {
              HStack(spacing: 12) {
                Text(totpValue.otp.rawValue.split(every: 3).joined(separator: " "))
                  .multilineTextAlignment(.leading)
                  .font(
                    .inconsolata(
                      ofSize: 24,
                      weight: .semibold
                    )
                  )

                CountdownCircleView(
                  current: totpValue.timeLeft.rawValue,
                  max: totpValue.validityPeriod.rawValue
                )
              }
              .frame(
                maxWidth: .infinity,
                alignment: .leading
              )
              .foregroundColor(
                totpValue.timeLeft > 5
                  ? Color.passboltPrimaryText
                  : Color.passboltSecondaryRed
              )
            }
            else {
              HStack(spacing: 12) {
                Text("••• •••")
                  .multilineTextAlignment(.leading)
                  .font(
                    .inconsolata(
                      ofSize: 24,
                      weight: .semibold
                    )
                  )

                Image(named: .eye)
                  .resizable()
                  .frame(
                    width: 20,
                    height: 20
                  )
              }
              .frame(
                maxWidth: .infinity,
                alignment: .leading
              )
            }
          }
        )
        .contentShape(Rectangle())
      }

      self.accessory()
        .frame(
          maxWidth: 32,
          maxHeight: 40,
          alignment: .trailing
        )
    }
    .commonListRowModifiers()
  }
}

#if DEBUG

private struct RunningTimerView<Content>: View
where Content: View {

  @State private var runningValue: Seconds = 30
  @State private var timer =
    Timer
    .publish(every: 1, on: .main, in: .common)
    .autoconnect()
  private let content: (Seconds) -> Content

  fileprivate init(
    @ViewBuilder content: @escaping (Seconds) -> Content
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

internal struct TOTPResourcesListRowView_Previews: PreviewProvider {

  internal static var previews: some View {
    CommonList {
      RunningTimerView { value in
        TOTPResourcesListRowView(
          title: "Revealed running",
          value: .init(
            otp: "123456",
            timeLeft: value,
            validityPeriod: 30
          ),
          action: {},
          accessory: {
            Button(
              action: {},
              label: {
                Image(named: .more)
                  .resizable()
                  .frame(
                    width: 20,
                    height: 20
                  )
              }
            )
          }
        )
      }

      TOTPResourcesListRowView(
        title: "Item hidden",
        value: .none,
        action: {},
        accessory: {
          Button(
            action: {},
            label: {
              Image(named: .more)
                .resizable()
                .frame(
                  width: 20,
                  height: 20
                )
            }
          )
        }
      )

      TOTPResourcesListRowView(
        title: "Revealed",
        value: .init(
          otp: "123456",
          timeLeft: 23,
          validityPeriod: 30
        ),
        action: {},
        accessory: {
          Button(
            action: {},
            label: {
              Image(named: .more)
                .resizable()
                .frame(
                  width: 20,
                  height: 20
                )
            }
          )
        }
      )

      TOTPResourcesListRowView(
        title: "Revealed with very long title which won't fit in one line",
        value: .init(
          otp: "123456",
          timeLeft: 23,
          validityPeriod: 30
        ),
        action: {},
        accessory: {
          Button(
            action: {},
            label: {
              Image(named: .more)
                .resizable()
                .frame(
                  width: 20,
                  height: 20
                )
            }
          )
        }
      )

      TOTPResourcesListRowView(
        title: "Low Time Revealed",
        value: .init(
          otp: "123456",
          timeLeft: 3,
          validityPeriod: 30
        ),
        action: {},
        accessory: {
          Button(
            action: {},
            label: {
              Image(named: .more)
                .resizable()
                .frame(
                  width: 20,
                  height: 20
                )
            }
          )
        }
      )
    }
  }
}
#endif
