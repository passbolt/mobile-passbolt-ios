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
import DatabaseOperations
import FeatureScopes

public struct PasswordGenerationService: Sendable {

  public typealias Configuration = PasswordPoliciesDSV

  public var generate: @Sendable () async throws -> String
  public var currentConfiguration: @Sendable () async -> Configuration
  public var updateConfiguration: @Sendable (Configuration) async -> Void
}

extension PasswordGenerationService: LoadableFeature {

  #if DEBUG
  nonisolated public static var placeholder: PasswordGenerationService {
    Self(
      generate: unimplemented0(),
      currentConfiguration: unimplemented0(),
      updateConfiguration: unimplemented1()
    )
  }
  #endif

  fileprivate enum CacheState: Sendable {
    case empty
    /// Fetch in progress. `nil` payload means the fetch failed and the caller should use `.default`.
    case loading(Task<Configuration?, Never>)
    case loaded(Configuration)
  }

  fileprivate enum CacheResolution: Sendable {
    case ready(Configuration)
    case pending(Task<Configuration?, Never>)
  }

  @MainActor public static func load(
    using features: Features
  ) throws -> PasswordGenerationService {

    let fetchPasswordPoliciesOperation: PasswordPoliciesFetchDatabaseOperation = try features.instance()
    let secretGenerator: SecretGenerator = try features.instance()

    let cached: CriticalState<CacheState> = .init(.empty)

    @Sendable func fetch() async -> Configuration? {
      do {
        return try await fetchPasswordPoliciesOperation.execute(())
      }
      catch {
        error.logged()
        Diagnostics.logger.error("Failed to fetch password policies, using default configuration")
        return .none
      }
    }

    @Sendable func currentConfiguration() async -> Configuration {
      // Single-flight: concurrent first calls share one fetch by awaiting the same Task.
      let resolution: CacheResolution = cached.access { (state: inout CacheState) -> CacheResolution in
        switch state {
        case .loaded(let configuration):
          return .ready(configuration)
        case .loading(let task):
          return .pending(task)
        case .empty:
          let task: Task<Configuration?, Never> = Task { await fetch() }
          state = .loading(task)
          return .pending(task)
        }
      }
      switch resolution {
      case .ready(let configuration):
        return configuration
      case .pending(let task):
        let fetched: Configuration? = await task.value
        // Promote loading → loaded only if this fetch is still the in-flight task
        // (i.e. updateConfiguration didn't overwrite it). Reset to empty on failure
        // so a later call retries the fetch.
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

    @Sendable func updateConfiguration(_ newConfiguration: Configuration) async {
      cached.set(.loaded(newConfiguration))
    }

    @Sendable func generate() async throws -> String {
      let configuration: Configuration = await currentConfiguration()
      return try secretGenerator.generate(configuration)
    }

    return .init(
      generate: generate,
      currentConfiguration: currentConfiguration,
      updateConfiguration: updateConfiguration(_:)
    )
  }
}

extension FeaturesRegistry {

  internal mutating func usePasswordGenerationService() {
    self.use(
      .lazyLoaded(
        PasswordGenerationService.self,
        load: PasswordGenerationService.load(using:)
      ),
      in: ResourceEditScope.self
    )
  }
}
