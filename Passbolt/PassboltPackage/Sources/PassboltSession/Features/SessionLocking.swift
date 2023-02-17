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

  internal var ensureAutolock: @Sendable () -> Void
}

extension SessionLocking: LoadableFeature {

  internal typealias Context = Account

  #if DEBUG
  internal nonisolated static var placeholder: Self {
    Self(
      ensureAutolock: unimplemented0()
    )
  }
  #endif
}

extension SessionLocking {

  @MainActor fileprivate static func load(
    features: Features,
    context account: Account,
    cancellables: Cancellables
  ) throws -> Self {
    let asyncExecutor: AsyncExecutor = try features.instance()
    let appLifecycle: ApplicationLifecycle = features.instance()
    let sesionState: SessionState = try features.instance()
    #warning("TODO: FIXME: scopes! - it should be only in session scope but it is trigerred from authorization, it has to be adjusting to session state")
    let observationStart: Once = .init {
      appLifecycle
        .lifecyclePublisher()
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

extension FeaturesRegistry {

  internal mutating func usePassboltSessionLocking() {
    self.use(
      .lazyLoaded(
        SessionLocking.self,
        load: SessionLocking
          .load(features:context:cancellables:)
      )
    )
  }
}
