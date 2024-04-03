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

import CommonModels
import Display
import FeatureScopes
import NetworkOperations

internal final class DUOAuthorizationViewController: ViewController {

  internal struct ViewState: Equatable {

    internal var request: DUOWebAuthorizationRequest?
  }

  internal let viewState: ViewStateSource<ViewState>

  private var finishAuthorization: ((Result<(String, String, String), Error>) -> Void)?

  private let duoAuthorizationNetworkOperation: DUOAuthorizationPromptNetworkOperation
  private let session: Session

  internal init(
    context: Void,
    features: Features
  ) throws {
    self.duoAuthorizationNetworkOperation = try features.instance()
    self.session = try features.instance()

    self.viewState = .init(
      initial: .init(
        request: .none
      )
    )
  }
}

extension DUOAuthorizationViewController {

  internal func requestAuthorization() async {
    assert(self.finishAuthorization == nil, "Can't begin authorization when there is one already pending.")
    do {
      let response: DUOAuthorizationPromptNetworkOperationResult = try await self.duoAuthorizationNetworkOperation()

      self.viewState.update(
        \.request,
        to: .init(
          url: response.authorizationURL,
          token: response.stateID
        )
      )

      let tokens: (code: String, duoToken: String, passboltToken: String) = try await future { fulfill in
        self.finishAuthorization = fulfill
      }
      self.finishAuthorization = .none
      self.viewState.update(\.request, to: .none)

      try await self.session.authorizeMFA(
        .duo(
          self.session.currentAccount(),
          duoCode: tokens.code,  // duoCode
          duoToken: tokens.duoToken,  // duoToken
          passboltToken: tokens.passboltToken,  // passboltToken
          rememberDevice: false  // remember option is not supported yet
        )
      )
    }
    catch {
      self.finishAuthorization = .none
      self.viewState.update { (viewState: inout ViewState) in
        viewState.request = .none
      }
      SnackBarMessageEvent.send(
        .error(
          error.logged(
            info: .message("DUO authorization failed!")
          )
        )
      )
    }
  }

  internal func handleAuthorization(
    duoCode: String,
    duoToken: String,
    passboltToken: String
  ) {
    self.finishAuthorization?(
      .success(
        (
          duoCode: duoCode,
          duoToken: duoToken,
          passboltToken: passboltToken
        )
      )
    )
  }

  internal func handleAuthorization(
    error: Error
  ) {
    self.finishAuthorization?(.failure(error))
  }
}
