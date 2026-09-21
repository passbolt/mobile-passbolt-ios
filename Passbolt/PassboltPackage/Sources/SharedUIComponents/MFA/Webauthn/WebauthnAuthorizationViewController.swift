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
import CommonModels
import Display
import FeatureScopes
import NetworkOperations
import Session

internal final class WebauthnAuthorizationViewController: ViewController {

  internal struct ViewState: Equatable {

    internal var rememberDevice: Bool = true
  }

  internal nonisolated let viewState: ViewStateSource<ViewState>

  private let ceremony: WebauthnDelegatedCeremony
  private let webauthnDelegatedPromptNetworkOperation: WebauthnDelegatedPromptNetworkOperation
  private let session: Session

  internal init(
    context: Void,
    features: Features
  ) throws {
    self.webauthnDelegatedPromptNetworkOperation = try features.instance()
    self.session = try features.instance()
    self.ceremony = .init()

    self.viewState = .init(
      initial: .init()
    )
  }
}

extension WebauthnAuthorizationViewController {

  internal func updatePresentationAnchor(
    _ anchor: ASPresentationAnchor?
  ) {
    self.ceremony.updatePresentationAnchor(anchor)
  }

  internal func requestAuthorization() async {
    let rememberDevice: Bool = await self.viewState.current.rememberDevice
    do {
      let account: Account = try await self.session.currentAccount()
      let prompt: WebauthnDelegatedPromptNetworkOperationResult =
        try await self.webauthnDelegatedPromptNetworkOperation()

      let exchangeCode: String =
        try await self.ceremony
        .authorize(
          domain: account.domain,
          ceremonyToken: prompt.ceremonyToken
        )

      try await self.session
        .authorizeMFA(
          .webauthn(
            account,
            exchangeCode: exchangeCode,
            rememberDevice: rememberDevice
          )
        )
    }
    catch {
      self.handle(error: error)
    }
  }

  private func handle(
    error: Error
  ) {
    switch error {
    case is Cancelled:
      break  // the user closed the ceremony, not an error

    default:
      SnackBarMessageEvent.send(
        .error(
          error.logged(
            info: .message("Passkey authorization failed!")
          )
        )
      )
    }
  }
}
