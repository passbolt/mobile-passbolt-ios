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

import Features
import OSFeatures

// MARK: - Interface

internal struct SessionLocking {

  internal var ensureLocking: @Sendable (Account) -> Void
}

extension SessionLocking: LoadableFeature {

  #if DEBUG
  internal nonisolated static var placeholder: Self {
    Self(
      ensureLocking: unimplemented1()
    )
  }
  #endif
}

extension SessionLocking {

  private struct LockingTask {

    fileprivate let account: Account
    fileprivate let task: Task<Void, Never>
  }

  @MainActor fileprivate static func load(
    features: Features
  ) throws -> Self {
    let appLifecycle: ApplicationLifecycle = features.instance()
    let sessionState: SessionState = try features.instance()

    let lockingTask: CriticalState<LockingTask?> = .init(.none)

    @Sendable nonisolated func ensureLocking(
      for account: Account
    ) {
      lockingTask.access { (currentTask: inout LockingTask?) in
        guard currentTask?.account != account else { return }
        currentTask?.task.cancel()
        currentTask = .init(
          account: account,
          task: .detached { @SessionActor in
            Diagnostics.logger.info("Session auto locking enabled!")
            do {
              for try await update in appLifecycle.lifecycle {
                guard sessionState.account() == account
                else { break }  // account has changed
                switch (sessionState.pendingAuthorization(), update) {
                case (.none, .didEnterBackground):
                  sessionState.passphraseWipe()

                case (.none, .willEnterForeground):
                  try sessionState.authorizationRequested(.passphrase(account))

                case _:
                  break  // ignore
                }
              }
            }
            catch is Cancelled {
              // NOP - just cancelled
            }
            catch {
              error.logged(
                info: .message("Session locking broken!")
              )
            }
          }
        )
      }
    }

    return Self(
      ensureLocking: ensureLocking(for:)
    )
  }
}

extension FeaturesRegistry {

  internal mutating func usePassboltSessionLocking() {
    self.use(
      .lazyLoaded(
        SessionLocking.self,
        load: SessionLocking
          .load(features:)
      )
    )
  }
}
