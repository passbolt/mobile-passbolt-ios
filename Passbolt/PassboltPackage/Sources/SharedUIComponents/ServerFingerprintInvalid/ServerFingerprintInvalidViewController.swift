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

public final class ServerFingerprintInvalidViewController: ViewController {

  public struct Context: Sendable {
    internal let accountID: Account.LocalID
    internal let fingerprint: Fingerprint?
    internal let backAction: @Sendable () async throws -> Void

    public init(
      accountID: Account.LocalID,
      fingerprint: Fingerprint?,
      backAction: @Sendable @escaping () async throws -> Void
    ) {
      self.accountID = accountID
      self.fingerprint = fingerprint
      self.backAction = backAction
    }
  }

  public struct ViewState: Equatable {
    let fingerprint: Fingerprint?
    var newKeyAccepted: Bool = false
  }

  public nonisolated let viewState: ViewStateSource<ViewState>
  private let context: Context

  private let navigationToSelf: NavigationToServerFingerprintInvalid
  private let serverFingerprintStorage: ServerFingerprintStorage

  public init(context: Context, features: Features) throws {
    self.context = context
    self.navigationToSelf = try features.instance()
    self.serverFingerprintStorage = try features.instance()

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
      try serverFingerprintStorage.storeServerFingerprint(
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

  internal func back() async {
    await consumingErrors {
      try await self.context.backAction()
    }
  }
}
