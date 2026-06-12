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
import UICommons

internal struct TransferInfoStepsView: View {
  internal typealias Step = DisplayableString

  private let title: DisplayableString
  private let steps: Array<Step>

  internal init(
    title: DisplayableString,
    steps: Array<Step>
  ) {
    self.title = title
    self.steps = steps
  }

  internal var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      Text(displayable: title)
        .font(.inter(ofSize: 14))
        .foregroundStyle(Color.passboltPrimaryText)

      VStack(alignment: .leading, spacing: 0) {
        ForEach(Array(steps.enumerated()), id: \.offset) { index, step in
          stepView(number: index + 1, text: step)
          if index < steps.count - 1 {
            divider
          }
        }
      }
      .padding(.top, 24)
      .padding(.horizontal, 8)
      GeometryReader { reader in
        Image(named: .qrCodeSample)
          .resizable()
          .aspectRatio(contentMode: .fit)
          .accessibilityIdentifier("transfer.account.import.image")
          .frame(width: reader.size.width * 0.6)
          .frame(maxWidth: .infinity)
      }
      .padding(.top, 16)
      Spacer()
    }
  }

  private func stepView(number: Int, text: Step) -> some View {
    HStack(spacing: 16) {
      stepIcon(number: number)

      Text(
        localizedMarkdown: text,
        size: 14,
        color: .passboltSecondaryText
      )
      .multilineTextAlignment(.leading)

      Spacer()
    }
  }

  private func stepIcon(number: Int) -> some View {
    Text("\(number)")
      .font(.inter(ofSize: 14, weight: .semibold))
      .foregroundStyle(Color.passboltPrimaryText)
      .background {
        Circle()
          .stroke(lineWidth: 1)
          .foregroundStyle(Color.passboltDivider)
          .frame(width: 24, height: 24)
      }
  }

  private var divider: some View {
    Rectangle()
      .frame(width: 1, height: 16)
      .foregroundColor(.passboltDivider)
      .padding(.leading, 4)
      .padding(.top, 8)
      .padding(.bottom, 8)
  }
}
