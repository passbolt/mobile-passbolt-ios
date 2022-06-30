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
import UIComponents

internal struct ResourceDetailsSharedSectionView: ComponentView {

  @ObservedObject private var state: ObservableValue<ViewState>
  private let controller: Controller

  internal init(
    state: ObservableValue<ViewState>,
    controller: ResourceDetailsSharedSectionController
  ) {
    self.state = state
    self.controller = controller
  }

  internal var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      Text(displayable: .localized(key: "resource.detail.section.shared"))
        .text(
          font: .inter(
            ofSize: 14,
            weight: .semibold
          ),
          color: .passboltPrimaryText
        )
        .padding(top: 12, bottom: 8)

      HStack(spacing: 0) {
        AsyncButton(
          action: {
            await self.controller.showResourcePermissionList()
          },
          label: {
            OverlappingAvatarStackView(self.state.items)
          }
        )
        .frame(maxWidth: .infinity)

        Image(named: .chevronRight)
          .resizable()
          .aspectRatio(1, contentMode: .fit)
          .padding(
            top: 12,
            leading: 4,
            bottom: 12,
            trailing: 0
          )
      }
      .frame(height: 40)
    }
    .foregroundColor(Color.passboltPrimaryText)
    .frame(maxWidth: .infinity)
  }
}

extension ResourceDetailsSharedSectionView {

  internal struct ViewState: Hashable {

    internal var items: Array<OverlappingAvatarStackView.Item>
  }
}
