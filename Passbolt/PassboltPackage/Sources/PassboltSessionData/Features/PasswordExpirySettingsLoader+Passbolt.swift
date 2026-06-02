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

import FeatureScopes
import NetworkOperations
import SessionData

extension PasswordExpirySettingsLoader {

  fileprivate enum CacheState: Sendable {
    case empty
    case loading(Task<Result<PasswordExpirySettings, Error>, Never>)
    case loaded(PasswordExpirySettings)
  }

  fileprivate enum CacheResolution: Sendable {
    case ready(PasswordExpirySettings)
    case pending(Task<Result<PasswordExpirySettings, Error>, Never>)
  }

  @MainActor fileprivate static func load(
    using features: Features
  ) throws -> Self {

    let fetchNetworkOperation: PasswordExpirySettingsFetchNetworkOperation = try features.instance()

    let cached: CriticalState<CacheState> = .init(.empty)

    @Sendable func fetch() async -> Result<PasswordExpirySettings, Error> {
      do {
        let settings: PasswordExpirySettings = try await fetchNetworkOperation()
        return .success(settings)
      }
      catch {
        error.logged()
        Diagnostics.logger.error("Failed to fetch password expiry settings")
        return .failure(error)
      }
    }

    @Sendable func settings() async throws -> PasswordExpirySettings {
      let resolution: CacheResolution = cached.access { (state: inout CacheState) -> CacheResolution in
        switch state {
        case .loaded(let settings):
          return .ready(settings)
        case .loading(let task):
          return .pending(task)
        case .empty:
          let task: Task<Result<PasswordExpirySettings, Error>, Never> = Task { await fetch() }
          state = .loading(task)
          return .pending(task)
        }
      }
      switch resolution {
      case .ready(let settings):
        return settings
      case .pending(let task):
        let result: Result<PasswordExpirySettings, Error> = await task.value
        cached.access { (state: inout CacheState) in
          guard case .loading(let inFlight) = state, inFlight == task else { return }
          switch result {
          case .success(let settings):
            state = .loaded(settings)
          case .failure:
            state = .empty
          }
        }
        return try result.get()
      }
    }

    return .init(settings: settings)
  }
}

extension FeaturesRegistry {

  internal mutating func usePassboltPasswordExpirySettingsLoader() {
    self.use(
      .lazyLoaded(
        PasswordExpirySettingsLoader.self,
        load: PasswordExpirySettingsLoader.load(using:)
      ),
      in: SessionScope.self
    )
  }
}
