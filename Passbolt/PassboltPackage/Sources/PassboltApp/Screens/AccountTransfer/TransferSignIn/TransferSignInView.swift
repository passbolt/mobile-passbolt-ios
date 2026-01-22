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

import AccountSetup
import Display
import SharedUIComponents

internal struct TransferSignInView: ControlledView {

  internal let controller: TransferSignInViewController

  internal init(controller: Controller) {
    self.controller = controller
  }

  internal var body: some View {
    withAlert(
      \.alert,
      content: {
        with(\.isLoading) { isLoading in
          content
            .overlay {
              if isLoading {
                LoadingOverlay(
                  loadingMessage: .localized(key: .loading),
                  longLoadingMessage: .localized(key: .loadingLong),
                  longLoadingDelay: 5.0
                )
              }
            }
        }
      }
    )
  }

  private var content: some View {
    WithViewState(controller.viewState) { state in
      UICommons.AuthorizationView(
        label: state.account?.label ?? "",
        username: state.account?.username ?? "",
        domain: state.account?.domain.rawValue ?? "",
        avatarImage: state.avatarData,
        passphrase: self.binding(to: \.passphrase),
        mainActionLabel: .localized(key: "authorization.button.title"),
        mainAction: self.controller.completeTransfer,
        biometricsAvailability: .unconfigured,
        biometricsAction: {},
        supportActionView: {
          SecondaryButton(
            title: "authorization.forgot.passphrase.button.title",
            action: self.controller.forgotPassphraseTapped
          )
          .accessibilityIdentifier("button.forgot.passphrase")
        }
      )
    }
    .navigationBarBackButtonHidden()
    .navigationBarTitleDisplayMode(.inline)
    .navigationTitle(displayable: "sign.in.title")
    .toolbar {
      ToolbarItem(placement: .topBarLeading) {
        IconButton(
          iconName: .arrowLeft,
          action: self.controller.backTapped
        )
        .accessibilityIdentifier("button.exit")
      }
      ToolbarItem(placement: .topBarTrailing) {
        IconButton(
          iconName: .help,
          action: self.controller.presentHelpMenu
        )
      }
    }
  }
}

#if DEBUG

extension TransferSignInViewController {
  static func previewDependencies(_ features: inout PreviewFeaturesContainer) {
    features.patch(
      \AccountImport.avatarPublisher,
      with: {
        Just<Data>(Data())
          .eraseErrorType()
          .eraseToAnyPublisher()
      }
    )
    features.patch(
      \AccountImport.accountDetailsPublisher,
      with: {
        Just(
          AccountImport.AccountDetails(
            domain: "https://passbolt.local",
            label: "Ada Lovelace",
            username: "ada@passbolt.com"
          )
        )
        .eraseErrorType()
        .eraseToAnyPublisher()
      }
    )
  }
}
#Preview {
  createPreview(
    TransferSignInView.self
  )
  .wrapInNavigationStack()
}
#endif
