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
import UICommons

public struct V4UpgradeBannerView: View {

  private let upgradeAction: @MainActor () async -> Void
  private let learnMoreAction: @MainActor () async -> Void

  public init(
    upgradeAction: @escaping @MainActor () async -> Void,
    learnMoreAction: @escaping @MainActor () async -> Void
  ) {
    self.upgradeAction = upgradeAction
    self.learnMoreAction = learnMoreAction
  }

  public var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      Text(displayable: "resource.edit.v4.upgrade.banner.title")
        .font(.inter(ofSize: 16, weight: .bold))
        .padding(.vertical, 20)

      VStack(alignment: .leading, spacing: 16) {
        Text(displayable: "resource.edit.v4.upgrade.banner.description")
          .font(.inter(ofSize: 14, weight: .medium))
          .foregroundColor(.passboltPrimaryText)
          .multilineTextAlignment(.leading)

        ActionButton(
          title: "resource.edit.v4.upgrade.banner.button",
          action: self.upgradeAction
        )
        .accessibilityIdentifier("resource.edit.v4.upgrade.button")

        AsyncButton(
          action: self.learnMoreAction,
          label: {
            Text(displayable: "resource.edit.v4.upgrade.banner.learn.more")
              .font(.inter(ofSize: 13, weight: .regular))
              .foregroundColor(.passboltPrimaryText)
              .underline()
          }
        )
        .frame(maxWidth: .infinity, alignment: .center)
        .padding(.top, 8)
        .accessibilityIdentifier("resource.edit.v4.upgrade.learn.more")
      }
      .padding(16)
      .backgroundColor(.passboltSelect)
      .cornerRadius(4)
    }
  }
}

#if DEBUG

internal struct V4UpgradeBannerView_Previews: PreviewProvider {

  internal static var previews: some View {
    V4UpgradeBannerView(
      upgradeAction: {},
      learnMoreAction: {}
    )
    .padding()
  }
}
#endif
