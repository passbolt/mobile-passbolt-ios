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

internal struct ResourceDetailsLocationSectionView: ComponentView {

  @ObservedObject private var state: ObservableValue<ViewState>
  private let controller: ResourceDetailsLocationSectionController

  internal init(
    state: ObservableValue<ViewState>,
    controller: ResourceDetailsLocationSectionController
  ) {
    self.state = state
    self.controller = controller
  }

  internal var body: some View {
    Button(
      action: self.controller.showResourceLocationDetails,
      label: {
        HStack(spacing: 0) {
          FolderLocationView(locationElements: state.location)

          Image(named: .chevronRight)
            .resizable()
            .aspectRatio(1, contentMode: .fit)
            .frame(height: 16)
            .padding(
              top: 12,
              leading: 4,
              bottom: 12,
              trailing: 0
            )
        }
        .padding(bottom: 8)
      }
    )
    .foregroundColor(Color.passboltPrimaryText)
    .frame(maxWidth: .infinity)
  }
}

extension ResourceDetailsLocationSectionView {

  internal struct ViewState: Hashable {

    internal var location: Array<String>
  }
}
