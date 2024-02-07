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

public struct OperationResultView: View {

  private let image: ImageNameConstant
  private let title: DisplayableString
  private let message: DisplayableString?
  private let actionLabel: DisplayableString
  private let action: @Sendable () async -> Void

  public init(
    image: ImageNameConstant,
    title: DisplayableString,
    message: DisplayableString? = .none,
    actionLabel: DisplayableString,
    action: @escaping @Sendable () async -> Void
  ) {
    self.image = image
    self.title = title
    self.message = message
    self.actionLabel = actionLabel
    self.action = action
  }

  public var body: some View {
    VStack(spacing: 16) {
      Spacer()

      Image(named: self.image)

      Text(displayable: self.title)
        .text(
          .center,
          lines: .none,
          font: .inter(
            ofSize: 24,
            weight: .semibold
          ),
          color: .passboltPrimaryText
        )

      if let message: DisplayableString = self.message {
        Text(displayable: message)
          .text(
            .center,
            lines: .none,
            font: .inter(
              ofSize: 14,
              weight: .light
            ),
            color: .passboltSecondaryText
          )
      }  // else NOP

      Spacer()

      PrimaryButton(
        title: self.actionLabel,
        action: self.action
      )

    }
    .padding(
      leading: 16,
      bottom: 16,
      trailing: 16
    )
  }
}

#if DEBUG

internal struct OperationResultView_Previews: PreviewProvider {

  internal static var previews: some View {
    OperationResultView(
      image: .failureMark,
      title: "Transfer failed",
      message: "Account transfer failed",
      actionLabel: "Try again",
      action: {}
    )

    OperationResultView(
      image: .successMark,
      title: "Transfer finished",
      message: "Account transfer is completed",
      actionLabel: "Continue",
      action: {}
    )

    OperationResultView(
      image: .successMark,
      title: "Success!",
      actionLabel: "Continue",
      action: {}
    )
  }
}
#endif
