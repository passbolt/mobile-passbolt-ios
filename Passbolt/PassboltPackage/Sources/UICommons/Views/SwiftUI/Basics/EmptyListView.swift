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

import Localization
import SwiftUI

public struct EmptyListView: View {

  private let message: DisplayableString

  public init(
    message: DisplayableString =
      .localized(
        key: "generic.empty.list"
      )
  ) {
    self.message = message
  }

  public var body: some View {
    VStack(
      alignment: .center,
      spacing: 0
    ) {
      Spacer()
      Text(
        displayable: self.message
      )
      .text(
        font: .inter(
          ofSize: 20,
          weight: .semibold
        ),
        color: .passboltPrimaryText
      )
      Image(named: .emptyState)
        .aspectRatio(1, contentMode: .fit)
        .padding(
          top: 24,
          leading: 64,
          trailing: 64
        )
      Spacer()
    }
    .padding(
      top: 24,
      leading: 16,
      bottom: 16,
      trailing: 16
    )
    .frame(
      maxWidth: .infinity,
      maxHeight: .infinity,
      alignment: .center
    )
    .listRowSeparator(.hidden)
    .listRowInsets(EdgeInsets())
    .backgroundColor(.passboltBackground)
  }
}
