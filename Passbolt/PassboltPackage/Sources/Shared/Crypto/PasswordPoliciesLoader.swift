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

import Crypto
import FeatureScopes
import NetworkOperations

/// Session-scoped lazy loader for the server password policies.
///
/// Fetches `/password-policies/settings.json` on the first call within a session,
/// memoizes the result, and shares one in-flight request among concurrent callers.
/// Falls back to ``SecretGenerator/Configuration/default`` when the plugin is
/// disabled server-side or when the network call fails.
public struct PasswordPoliciesLoader: Sendable {

  public var policies: @Sendable () async -> SecretGenerator.Configuration
}

extension PasswordPoliciesLoader: LoadableFeature {

  #if DEBUG
  nonisolated public static var placeholder: PasswordPoliciesLoader {
    .init(policies: unimplemented0())
  }
  #endif

  fileprivate enum CacheState: Sendable {
    case empty
    case loading(Task<SecretGenerator.Configuration?, Never>)
    case loaded(SecretGenerator.Configuration)
  }

  fileprivate enum CacheResolution: Sendable {
    case ready(SecretGenerator.Configuration)
    case pending(Task<SecretGenerator.Configuration?, Never>)
  }

  @MainActor public static func load(
    using features: Features
  ) throws -> PasswordPoliciesLoader {

    let sessionConfiguration: SessionConfiguration = try features.sessionConfiguration()
    let fetchNetworkOperation: PasswordPoliciesFetchNetworkOperation = try features.instance()

    // When the plugin is disabled server-side, no network call is ever made — the loader
    // permanently serves the built-in default.
    let initialState: CacheState =
      sessionConfiguration.passwordPolicies.passwordPoliciesEnabled
      ? .empty
      : .loaded(.default)
    let cached: CriticalState<CacheState> = .init(initialState)

    @Sendable func fetch() async -> SecretGenerator.Configuration? {
      do {
        let dto: PasswordPoliciesDTO = try await fetchNetworkOperation()
        try dto.passwordGeneratorSettings.validate()
        return SecretGenerator.Configuration(
          id: .init(rawValue: dto.id.rawValue),
          defaultGenerator: dto.defaultGenerator,
          passwordGeneratorSettings: dto.passwordGeneratorSettings,
          passphraseGeneratorSettings: dto.passphraseGeneratorSettings,
          externalDictionaryCheck: dto.externalDictionaryCheck
        )
      }
      catch {
        error.logged()
        Diagnostics.logger.error("Failed to fetch password policies, using default configuration")
        return .none
      }
    }

    @Sendable func policies() async -> SecretGenerator.Configuration {
      // Single-flight: concurrent first calls share one fetch by awaiting the same Task.
      let resolution: CacheResolution = cached.access { (state: inout CacheState) -> CacheResolution in
        switch state {
        case .loaded(let configuration):
          return .ready(configuration)
        case .loading(let task):
          return .pending(task)
        case .empty:
          let task: Task<SecretGenerator.Configuration?, Never> = Task { await fetch() }
          state = .loading(task)
          return .pending(task)
        }
      }
      switch resolution {
      case .ready(let configuration):
        return configuration
      case .pending(let task):
        let fetched: SecretGenerator.Configuration? = await task.value
        // Promote loading → loaded only if this fetch is still the in-flight task.
        // Reset to empty on failure so a later call retries the fetch.
        cached.access { (state: inout CacheState) in
          guard case .loading(let inFlight) = state, inFlight == task else { return }
          if let fetched {
            state = .loaded(fetched)
          }
          else {
            state = .empty
          }
        }
        return fetched ?? .default
      }
    }

    return .init(policies: policies)
  }
}

extension FeaturesRegistry {

  internal mutating func usePasswordPoliciesLoader() {
    self.use(
      .lazyLoaded(
        PasswordPoliciesLoader.self,
        load: PasswordPoliciesLoader.load(using:)
      ),
      in: SessionScope.self
    )
  }
}
