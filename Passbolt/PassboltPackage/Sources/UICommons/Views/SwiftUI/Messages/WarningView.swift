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

public struct WarningView {

  private let message: DisplayableString

  public init(
    message: DisplayableString
  ) {
    self.message = message
  }
}

extension WarningView: View {

  public var body: some View {
    HStack {
      Image(named: .warning)
        .frame(
          width: 24,
          height: 24
        )
        .padding(trailing: 8)

      Text(displayable: self.message)
        .multilineTextAlignment(.leading)

      Spacer()
    }
    .padding(
      leading: 16,
      trailing: 16
    )
    .padding(
      top: 12,
      bottom: 12
    )
    .backgroundColor(.passboltSecondaryOrange)
    .foregroundColor(.passboltWarningText)
    .font(
      .inter(
        ofSize: 12,
        weight: .medium
      )
    )
    .cornerRadius(4, corners: .allCorners)
  }
}

#if DEBUG

internal struct WarningView_Previews: PreviewProvider {

  internal static var previews: some View {
    VStack(spacing: 8) {
      WarningView(message: "This is a warning message")
      WarningView(message: "This is a very long warning message which should have more than one line to be displayed.")
    }
    .padding(8)
  }
}
#endif
