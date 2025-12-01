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

import AuthenticationServices
import Display

internal struct NoAccountsView: ControlledView {

  internal let controller: NoAccountsViewController

  internal init(controller: NoAccountsViewController) {
    self.controller = controller
  }

  internal var body: some View {
    GeometryReader { geometry in
      VStack(spacing: 0) {
        Image(named: .passboltLogo)
          .resizable()
          .aspectRatio(contentMode: .fit)
          .frame(width: geometry.size.width * 0.4)
          .frame(maxWidth: .infinity, alignment: .center)
          .padding(.top, 16)
          .accessibilityIdentifier("no.accounts.logo.imageview")

        Image(named: .accountsSkeleton)
          .resizable()
          .aspectRatio(contentMode: .fit)
          .frame(width: geometry.size.width * 0.7)
          .padding(.top, 60)
          .accessibilityIdentifier("no.accounts.imageview")

        Text(displayable: "autofill.extension.no.accounts.title")
          .font(.inter(ofSize: 24, weight: .semibold))
          .foregroundColor(.passboltPrimaryText)
          .multilineTextAlignment(.center)
          .padding(.top, 60)
          .accessibilityIdentifier("no.accounts.title.label")

        Text(displayable: "autofill.extension.no.accounts.description")
          .font(.inter(ofSize: 14))
          .foregroundColor(.passboltSecondaryText)
          .multilineTextAlignment(.center)
          .padding(.top, 16)
          .accessibilityIdentifier("no.accounts.description.label")
      }
      .padding(.horizontal, 16)
      .padding(.top, 120)
      .navigationBarBackButtonHidden()
    }
    .padding(.bottom, 16)
    .overlay(alignment: .topTrailing) {
      AsyncButton(
        action: {
          self.controller.close()
        },
        label: {
          Image(named: .close)
            .renderingMode(.template)
            .foregroundStyle(Color.passboltPrimaryText)
            .padding(.trailing, 24)
            .padding(.top, 24)
        }
      )
    }
    .backgroundColor(.passboltBackground)
  }
}

#if DEBUG
#Preview {
  PlaceholderView()
    .sheet(isPresented: .constant(true)) {
      createPreview(
        NoAccountsView.self,
        with: (),
        using: { registry in
          registry.usePlaceholder(for: AutofillExtensionContext.self)
        }
      )
    }
}
#endif
