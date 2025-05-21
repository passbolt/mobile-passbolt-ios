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

public struct CommonListResourceOTPView<AccessoryView>: View where AccessoryView: View {

  private let name: String
  private let isExpired: Bool
  private let nextOTP: @Sendable () async -> OTPValue?
  private let contentAction: @MainActor (OTPValue?) async -> Void
  private let accessoryAction: (@MainActor () async -> Void)?
  private let accessory: @MainActor () -> AccessoryView
  @State private var currentOTP: OTPValue?

  public init(
    name: String,
    isExpired: Bool,
    otpGenerator: @escaping @Sendable () async -> OTPValue?,
    contentAction: @escaping @MainActor (OTPValue?) async -> Void,
    accessoryAction: (@MainActor () async -> Void)? = .none,
    @ViewBuilder accessory: @escaping @MainActor () -> AccessoryView
  ) {
    self.name = name
    self.isExpired = isExpired
    self.nextOTP = otpGenerator
    self.contentAction = contentAction
    self.accessoryAction = accessoryAction
    self.accessory = accessory
  }

  public init(
    name: String,
    isExpired: Bool,
    otpGenerator: @escaping @Sendable () async -> OTPValue?,
    contentAction: @escaping @MainActor (OTPValue?) async -> Void
  ) where AccessoryView == EmptyView {
    self.name = name
    self.isExpired = isExpired
    self.nextOTP = otpGenerator
    self.contentAction = contentAction
    self.accessoryAction = .none
    self.accessory = EmptyView.init
  }

  public var body: some View {
    CommonListRow(
      content: {
        HStack(spacing: 8) {
          ZStack(alignment: .bottomTrailing) {
            LetterIconView(text: self.name)
              .frame(
                width: 40,
                height: 40,
                alignment: .center
              )
            if isExpired == true {
              Image(named: .exclamationMark)
                .resizable()
                .frame(
                  width: 12,
                  height: 12
                )
                .alignmentGuide(.trailing) { dim in
                  dim[HorizontalAlignment.center] + 2
                }
                .alignmentGuide(.bottom) { dim in
                  dim[VerticalAlignment.center] + 2
                }
            }
          }

          VStack(alignment: .leading, spacing: 4) {
            Text(name)
              .font(.inter(ofSize: 14, weight: .semibold))
              .lineLimit(1)
              .foregroundColor(Color.passboltPrimaryText)

            AsyncButton(
              action: {
                await self.contentAction(self.currentOTP)
              },
              regularLabel: {
                OTPValueView(
                  value: self.currentOTP,
                  accessory: self.currentOTP == nil
                    ? .toggle
                    : .contextual
                )
              },
              loadingLabel: {
                OTPValueView(
                  value: self.currentOTP,
                  accessory: .loader
                )
              }
            )
          }
        }
        .frame(height: 64)
        .task {
          while !Task.isCancelled {
            self.currentOTP = await self.nextOTP()
          }
          self.currentOTP = .none
        }
      },
      accessoryAction: self.accessoryAction,
      accessory: self.accessory
    )
  }
}

#if DEBUG

// swift-format-ignore: NeverForceUnwrap
internal struct CommonListResourceOTPView_Previews: PreviewProvider {
  internal static var previews: some View {
    CommonList {
      CommonListSection {
        CommonListResourceOTPView(
          name: "Resource",
          isExpired: false,
          otpGenerator: {
            try? await Task.never()
          },
          contentAction: { (otp: OTPValue?) in
            try? await Task.sleep(nanoseconds: (0 ... 1000).randomElement()! * NSEC_PER_MSEC)
            print("contentAction \(otp as Any)")
          },
          accessory: EmptyView.init
        )

        CommonListResourceOTPView(
          name: "Very long name which will surely not fit in one line of text and should be truncated",
          isExpired: false,
          otpGenerator: {
            try? await Task.never()
          },
          contentAction: { (otp: OTPValue?) in
            try? await Task.sleep(nanoseconds: (0 ... 1000).randomElement()! * NSEC_PER_MSEC)
            print("contentAction \(otp as Any)")
          },
          accessory: EmptyView.init
        )

        CommonListResourceOTPView(
          name: "Very long name which will surely not fit in one line of text and should be truncated",
          isExpired: false,
          otpGenerator: {
            try? await Task.never()
          },
          contentAction: { (otp: OTPValue?) in
            try? await Task.sleep(nanoseconds: (0 ... 1000).randomElement()! * NSEC_PER_MSEC)
            print("contentAction \(otp as Any)")
          },
          accessory: {
            Image(named: .chevronRight)
          }
        )

        CommonListResourceOTPView(
          name: "Very long name which will surely not fit in one line of text and should be truncated",
          isExpired: false,
          otpGenerator: {
            try? await Task.sleep(nanoseconds: NSEC_PER_SEC)
            return .totp(
              .init(
                resourceID: .none,
                otp: "123456",
                timeLeft: Seconds(rawValue: 30 - Int64(time(nil) % 30)),
                period: 30
              )
            )
          },
          contentAction: { (otp: OTPValue?) in
            try? await Task.sleep(nanoseconds: (0 ... 1000).randomElement()! * NSEC_PER_MSEC)
            print("contentAction \(otp as Any)")
          },
          accessoryAction: {
            try? await Task.sleep(nanoseconds: (0 ... 1000).randomElement()! * NSEC_PER_MSEC)
            print("accessoryAction")
          },
          accessory: {
            Image(named: .more)
          }
        )
      }
    }
  }
}
#endif
