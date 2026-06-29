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

import Display

internal struct UnsupportedMFAView: ControlledView {

  internal let controller: UnsupportedMFAViewController

  internal init(controller: UnsupportedMFAViewController) {
    self.controller = controller
  }

  internal var body: some View {
    ScreenView(
      title: "settings.expert.title",
      contentView: {
        self.content
      }
    )
    .navigationBarBackButtonHidden(true)
    .toolbar(.hidden, for: .tabBar)
  }

  @ViewBuilder @MainActor private var content: some View {
    VStack(spacing: 0) {
      GeometryReader { reader in
        VStack(spacing: 0) {
          Spacer()
          Image(named: .failureMark)
            .resizable()
            .scaledToFit()
            .frame(width: reader.size.width * 0.4)
            .frame(maxWidth: .infinity)

          Text(displayable: "mfa.unsupported.provider.title")
            .titleStyle()
            .padding(.top, 32)

          Text(displayable: "mfa.unsupported.provider.description")
            .infoStyle()
            .padding(.top, 16)

          Spacer()
        }
      }
    }
    .padding(.horizontal, 16)
    .padding(.bottom, 16)
    .navigationBarBackButtonHidden()
    .toolbar {
      ToolbarItem(placement: .topBarTrailing) {
        IconButton(
          iconName: .close,
          action: { await self.controller.close() }
        )
      }
    }
  }
}
