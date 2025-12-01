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

import Accounts
import Display

internal final class ServerFingerprintInvalidViewController: ViewController {

  internal struct Context {
    let accountID: Account.LocalID
    let fingerprint: Fingerprint?
  }

  internal struct ViewState: Equatable {
    let fingerprint: Fingerprint?
    var newKeyAccepted: Bool = false
  }

  nonisolated let viewState: ViewStateSource<ViewState>
  private let context: Context

  private let navigationToSelf: NavigationToServerFingerprintInvalid
  private let accountsDataStore: AccountsDataStore

  internal init(context: Context, features: Features) throws {
    self.context = context
    self.navigationToSelf = try features.instance()
    self.accountsDataStore = try features.instance()

    self.viewState = .init(
      initial: .init(
        fingerprint: context.fingerprint
      )
    )
  }

  internal func acceptNewKey() async {
    guard let fingerprint = context.fingerprint
    else {
      return
    }
    do {
      try accountsDataStore.storeServerFingerprint(
        context.accountID,
        fingerprint
      )
      try await navigationToSelf.revert()
    }
    catch {
      SnackBarMessageEvent.send(.error("server.fingerprint.save.failed"))
    }
  }

  internal func checkmarkTapped() {
    withAnimation {
      self.viewState.update { state in
        state.newKeyAccepted.toggle()
      }
    }
  }
}
