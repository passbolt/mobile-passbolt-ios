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

internal struct AccountExportAuthorizationView: ControlledView {

  private let controller: AccountExportAuthorizationController

  internal init(
    controller: AccountExportAuthorizationController
  ) {
    self.controller = controller
  }

  var body: some View {
    WithViewState(controller) { (state: ViewState) in
      ScreenView(
        title: .localized(key: "authorization.title"),
        snackBarMessage: self.controller.binding(to: \.snackBarMessage),
        contentView: {
          self.contentView(using: state)
        }
      )
    }
  }

  @ViewBuilder @MainActor private func contentView(
    using state: ViewState
  ) -> some View {
    AuthView(
      label: state.accountLabel,
      username: state.accountUsername,
      domain: state.accountDomain,
      avatarImage: state.accountAvatarImage,
      passphraseBinding: .init(
        get: { state.passphrase.map(\.rawValue) },
        set: { (passphrase: Validated<String>) in
          self.controller.setPassphrase(passphrase.map(Passphrase.init(rawValue:)).value)
        }
      ),
      mainActionLabel: .localized(
        key: "authorization.reverification.button.title"
      ),
      mainAction: self.controller.authorizeWithPassphrase,
      biometricsAvailability: state.biometricsAvailability,
      biometricsAction: self.controller.authorizeWithBiometrics,
      supportActionView: EmptyView.init
    )
    .onAppear {  // auto use biometrics when able
      switch state.biometricsAvailability {
      case .faceID, .touchID:
        self.controller.authorizeWithBiometrics()

      case .unavailable, .unconfigured:
        break  // NOP
      }
    }
  }
}

#if DEBUG
internal struct AccountExportAuthorizationView_Previews: PreviewProvider {
  internal static var previews: some View {
    AccountExportAuthorizationView(
      controller: .placeholder
    )
  }
}
#endif
