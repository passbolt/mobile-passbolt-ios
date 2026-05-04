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
import SharedUIComponents

internal struct WelcomeScreenView: ControlledView {

  internal let controller: WelcomeScreenViewController

  internal init(controller: WelcomeScreenViewController) {
    self.controller = controller
  }

  internal var body: some View {
    withAlert(
      \.alert,
      content: {
        content
      }
    )
  }

  private var content: some View {
    VStack(spacing: 0) {
      GeometryReader { reader in
        VStack(spacing: 0) {
          Image(named: .passboltLogo)
            .resizable()
            .scaledToFit()
            .frame(width: reader.size.width * 0.4)
            .frame(maxWidth: .infinity)

          Image(named: .accountsSkeleton)
            .resizable()
            .scaledToFit()
            .frame(width: reader.size.width * 0.7)
            .frame(maxWidth: .infinity)
            .padding(.top, 56)
            .accessibilityIdentifier("image.account.avatar")

          Text(displayable: "welcome.title")
            .titleStyle()
            .padding(.top, 56)
            .accessibilityIdentifier("label.title")

          Text(displayable: "welcome.description")
            .infoStyle()
            .accessibilityIdentifier("label.description")
            .padding(.horizontal, 16)
            .padding(.top, 16)
          Spacer()
        }
      }

      Spacer()
      PrimaryButton(
        title: "welcome.connect.to.account",
        action: self.controller.goToScanning
      )
      .accessibilityIdentifier("button.account.transfer")
      SecondaryButton(
        title: "welcome.no.account",
        action: { self.controller.showNoAccountAlert() }
      )
      .accessibilityIdentifier("button.account.none")
    }
    .padding(.top, 0)
    .padding(.horizontal, 16)
    .padding(.bottom, 16)
    .toolbar {
      ToolbarItem(placement: .topBarTrailing) {
        IconButton(
          iconName: .help,
          action: { await self.controller.openHelpMenu() }
        )
      }
    }
  }
}

#if DEBUG

#Preview {
  createPreview(WelcomeScreenView.self)
    .wrapInNavigationStack()
}
#endif
