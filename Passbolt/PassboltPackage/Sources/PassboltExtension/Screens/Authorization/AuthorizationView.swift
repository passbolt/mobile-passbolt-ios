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

internal struct AuthorizationView: ControlledView {

  internal let controller: AuthorizationViewController

  internal init(controller: AuthorizationViewController) {
    self.controller = controller
  }

  internal var body: some View {
    withAlert(
      \.alert,
      alert: { state in
        .init(
          title: state.title,
          message: state.message,
          actions: [
            .cancel(
              id: .init(),
              title: .localized(key: .gotIt)
            )
          ]
        )
      },
      content: {
        with(\.showLoadingOverlay) { showLoadingOverlay in
          self.content
            .navigationBarBackButtonHidden()
            .navigationTitle(displayable: "authorization.title")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
              if showLoadingOverlay == false {

                ToolbarItemGroup(placement: .navigationBarLeading) {
                  BackButton(
                    action: self.controller.back
                  )
                }
                ToolbarItemGroup(placement: .navigationBarTrailing) {
                  IconButton(
                    iconName: .help,
                    action: self.controller.presentHelp
                  )
                }
              }
            }
            .overlay {
              if showLoadingOverlay {
                LoadingOverlay(
                  loadingMessage: .localized(key: .loading),
                  longLoadingMessage: .localized(key: .loadingLong),
                  longLoadingDelay: 5.0
                )
              }
            }
            .task {
              await self.controller.tryBiometricSignIn()
            }
        }
      }
    )
  }

  private var content: some View {
    WithViewState(from: self.controller) { state in
      AuthView(
        label: state.label,
        username: state.username,
        domain: state.domain,
        avatarImage: state.avatarData,
        passphrase: binding(to: \.passphrase),
        mainActionLabel: "authorization.button.title",
        mainAction: self.controller.signIn,
        biometricsAvailability: state.biometricsAvailability,
        biometricsAction: self.controller.biometricSignIn,
        supportActionView: {
          SecondaryButton(
            title: "authorization.forgot.passphrase.button.title",
            action: {
              await self.controller.forgotPassword()
            }
          )
          .accessibilityIdentifier("button.forgot.passphrase")
        }
      )
      .task {
        await self.controller.loadAvatar()
      }
    }
  }
}

#if DEBUG
#Preview {
  PlaceholderView()
    .sheet(isPresented: .constant(true)) {
      createPreview(
        AuthorizationView.self,
        with: .ada,
        perform: { controller in
          await controller.signIn()
        }
      )
      .wrapInNavigationStack()
    }
}

#endif
