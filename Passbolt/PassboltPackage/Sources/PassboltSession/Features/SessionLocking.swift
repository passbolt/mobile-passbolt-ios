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
              // Resolving account preferences requires the session configuration, which is fetched
              // over the network on first use. The result is kept here so that the setting can be
              // read later without suspending.
              let resolvedPreferences: CriticalState<AccountPreferences?> = .init(.none)

              @Sendable func accountPreferences() async throws -> AccountPreferences {
                if let resolved: AccountPreferences = resolvedPreferences.get() {
                  return resolved
                }  // else - resolve below
                let sessionConfigurationLoader: SessionConfigurationLoader = try await features.instance()
                let configuration: SessionConfiguration =
                  try await sessionConfigurationLoader.sessionConfiguration()
                let sessionScopeFeatures: Features =
                  try await features
                  .branch(scope: AccountScope.self, context: account)
                  .branch(scope: SessionScope.self, context: .init(account: account, configuration: configuration))
                let resolved: AccountPreferences = try await sessionScopeFeatures.instance()
                resolvedPreferences.access { (state: inout AccountPreferences?) in
                  state = resolved
                }
                return resolved
              }

              /// Reads the setting from its keychain storage, resolving account preferences if needed.
              /// Returns `.none` when it could not be read, so that a failed read is never mistaken
              /// for the setting being turned off - the keychain is unreadable while the device is
              /// locked, which is exactly when the wipe decision is being made.
              @Sendable func readWipePassphraseOnBackground() async -> Bool? {
                do {
                  return try await accountPreferences()
                    .readPassphraseWipeOnBackground()
                }
                catch {
                  error.logged()
                  return .none
                }
              }

              // Warms up `resolvedPreferences` concurrently with the lifecycle loop, so that the
              // loop can start observing immediately instead of waiting for a network request.
              let preferencesTask: Task<Void, Never> = .detached {
                _ = try? await accountPreferences()
              }
              defer { preferencesTask.cancel() }

              var backgroundEnteredAt: MonotonicTimestamp? = .none
              // The setting is kept in the keychain using `kSecAttrAccessibleWhenUnlockedThisDeviceOnly`,
              // so it can be read only while the device is unlocked. The last successfully read value is
              // cached here and refreshed on `willResignActive`, which always precedes `didEnterBackground`
              // and still happens before the device can lock.
              //
              // It is deliberately not read before entering the loop - resolving account preferences
              // loads the session configuration over the network, and `appLifecycle.lifecycle` is a shared
              // publisher without replay, so every transition emitted before the iteration starts would be
              // lost, leaving the passphrase cached for the whole background period.
              var wipePassphraseOnBackground: Bool = false
              var wipePassphraseOnBackgroundRead: Bool = false

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
                case (.none, .willResignActive):
                  // `willResignActive` always precedes `didEnterBackground` and still happens
                  // while the device is unlocked, so it is the last chance to read the setting
                  // from the keychain.
                  if let preferences: AccountPreferences = resolvedPreferences.get() {
                    do {
                      wipePassphraseOnBackground = try preferences.readPassphraseWipeOnBackground()
                      wipePassphraseOnBackgroundRead = true
                    }
                    catch {
                      // keep the last successfully read setting, the keychain is
                      // already unreachable when the device has just been locked
                      error.logged()
                    }
                  }

                case (.none, .didEnterBackground):
                  backgroundEnteredAt = osTime.monotonicTimestamp()
                  if !wipePassphraseOnBackgroundRead,
                    let read: Bool = await readWipePassphraseOnBackground()
                  {
                    wipePassphraseOnBackground = read
                    wipePassphraseOnBackgroundRead = true
                  }
                  if wipePassphraseOnBackground {
                    // forced - the setting asks for the cache to be gone as soon as the
                    // application is in background, so running tasks must not postpone it
                    sessionState.passphraseWipe(true)
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
                        // forced - the grace period already passed, postponing the wipe until
                        // running tasks finish would keep the passphrase cached indefinitely
                        await sessionState.passphraseWipe(true)
                      }
                    }
                  }

                case (.none, .willEnterForeground):
                  deferredTask.access { task in
                    task?.cancel()
                    task = .none
                  }
                  if let enteredBackgroundAt: MonotonicTimestamp = backgroundEnteredAt,
                    osTime.monotonicTimestamp().elapsed(since: enteredBackgroundAt)
                      >= passphraseWipeDelaySeconds
                  {
                    Diagnostics.logger
                      .info("Background time exceeded passphrase wipe delay, wiping passphrase cache...")
                    // forced - same reason as the deferred wipe above, the grace period passed
                    sessionState.passphraseWipe(true)
                  }  // else - still within the grace period, keep the cache
                  backgroundEnteredAt = .none
                  try sessionState.requestAuthorizationIfNeeded(.passphrase(account))
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
