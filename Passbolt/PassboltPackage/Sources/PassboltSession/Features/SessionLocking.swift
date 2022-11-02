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

// MARK: - Interface

internal struct SessionLocking {

  internal var ensureAutolock: @Sendable () -> Void
}

extension SessionLocking: LoadableFeature {

  internal typealias Context = Account

  #if DEBUG
  internal nonisolated static var placeholder: Self {
    Self(
      ensureAutolock: unimplemented()
    )
  }
  #endif
}

extension SessionLocking {

  @MainActor fileprivate static func load(
    features: FeatureFactory,
    context account: Account,
    cancellables: Cancellables
  ) async throws -> Self {
    unowned let features: FeatureFactory = features
    await features.assertScope(identifier: account)
    let asyncExecutor: AsyncExecutor = features.instance(of: AsyncExecutor.self)
      .detach()
    let environmentBridge: EnvironmentLegacyBridge = features.instance()
    let appLifeCycle: AppLifeCycle = environmentBridge.environment.appLifeCycle
    let sesionState: SessionState = try await features.instance()

    let observationStart: Once = .init {
      appLifeCycle
        .lifeCyclePublisher()
        .sink { transition in
          asyncExecutor.schedule(.replace) { @SessionActor in
            switch transition {
            case .didBecomeActive, .willResignActive, .willTerminate:
              break  // NOP

            case .didEnterBackground:
              sesionState.passphraseWipe()

            case .willEnterForeground:
              do {
                try sesionState
                  .authorizationRequested(.passphrase(account))
              }
              catch {
                // ignore errors
                error
                  .asTheError()
                  .asAssertionFailure()
              }
            }
          }
        }
        .store(in: cancellables)
    }

    @Sendable nonisolated func ensureAutolock() {
      observationStart.executeIfNeeded()
    }

    return Self(
      ensureAutolock: ensureAutolock
    )
  }
}

extension FeatureFactory {

  internal func usePassboltSessionLocking() {
    self.use(
      .lazyLoaded(
        SessionLocking.self,
        load: SessionLocking
          .load(features:context:cancellables:)
      )
    )
  }
}
