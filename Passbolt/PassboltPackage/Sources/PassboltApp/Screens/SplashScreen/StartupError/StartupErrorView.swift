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

internal struct StartupErrorView: @MainActor ControlledView {

  internal let controller: StartupErrorViewController

  internal init(controller: StartupErrorViewController) {
    self.controller = controller
  }

  internal var body: some View {
    withAlert(\.alert) {
      VStack(spacing: 30) {
        VStack(spacing: 30) {
          Text(displayable: .localized(key: .genericError))
            .font(.inter(ofSize: 20, weight: .semibold))
            .multilineTextAlignment(.center)
            .foregroundStyle(Color.passboltPrimaryText)
          Image(named: .errorState)
        }
        VStack(spacing: 15) {
          PrimaryButton(
            title: .localized(key: .refresh),
            action: self.controller.refresh
          )
          PrimaryButton(
            title: .localized(key: .signOut),
            action: self.controller.signOut
          )
        }
        .padding(.horizontal, 64)
        .padding(.top, 20)
        Spacer()
      }
      .padding(.top, 90)
    }
  }
}

#if DEBUG
#Preview {
  PlaceholderView()
    .sheet(isPresented: .constant(true)) {
      createPreview(
        StartupErrorView.self,
        with: {}
      )
    }
}
#endif
