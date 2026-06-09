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
import FeatureScopes
import Features
import OSFeatures
import SessionData

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
    let osTime: OSTime = features.instance()

    // Currently hardcoded to 60s, but could be made configurable if needed
    let passphraseWipeDelaySeconds: Seconds = 60

    let lockingTask: CriticalState<LockingTask?> = .init(.none)
    let deferredTask: CriticalState<Task<Void, Never>?> = .init(.none)

    @Sendable nonisolated func ensureLocking(
      for account: Account
    ) {
      lockingTask.access { (currentTask: inout LockingTask?) in
        guard currentTask?.account != account else { return }
        currentTask?.task.cancel()

        currentTask = .init(
          account: account,
          task: .detached { @Sendable @SessionActor in
            Diagnostics.logger.info("Session auto locking enabled!")
            defer {
              deferredTask.access { task in
                task?.cancel()
                task = .none
              }
            }
            do {
              @Sendable func shouldWipePassphraseOnBackground() async -> Bool {
                do {
                  let sessionConfigurationLoader: SessionConfigurationLoader = try await features.instance()
                  let configuration: SessionConfiguration =
                    try await sessionConfigurationLoader.sessionConfiguration()
                  let sessionScopeFeatures: Features =
                    try await features
                    .branch(scope: AccountScope.self, context: account)
                    .branch(scope: SessionScope.self, context: .init(account: account, configuration: configuration))
                  let accountPreferences: AccountPreferences = try await sessionScopeFeatures.instance()
                  return accountPreferences.passphraseWipeOnBackground.value
                }
                catch {
                  error.logged()
                  return false  // default to not wiping passphrase on background if we can't determine the setting
                }
              }

              for try await update in appLifecycle.lifecycle {
                Diagnostics.logger.info("Application transition: \(update.rawValue)")

                // Check if account changed
                guard sessionState.account() == account
                else {
                  deferredTask.access { task in
                    task?.cancel()
                    task = .none
                  }
                  continue
                }  // account has changed
                switch (sessionState.pendingAuthorization(), update) {
                case (.none, .didEnterBackground):
                  if await shouldWipePassphraseOnBackground() {
                    sessionState.passphraseWipe(false)
                  }
                  else {
                    Diagnostics.logger.info("Deferring passphrase wipe...")
                    deferredTask.access { task in
                      task?.cancel()
                      task = Task.detached {
                        do {
                          try await osTime.waitFor(passphraseWipeDelaySeconds)
                        }
                        catch is CancellationError {
                          // NOP - just cancelled
                        }
                        catch {
                          Diagnostics.logger.warning("Deferred passphrase wipe timer interrupted: \(error)")
                        }
                        guard !Task.isCancelled, await sessionState.account() == account else { return }
                        await sessionState.passphraseWipe(false)
                      }
                    }
                  }

                case (.none, .willEnterForeground):
                  try sessionState.requestAuthorizationIfNeeded(.passphrase(account))
                  deferredTask.access { task in
                    task?.cancel()
                    task = .none
                  }
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
