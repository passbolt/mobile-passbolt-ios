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
import NetworkOperations
import OSFeatures
import Session
import SessionData

import struct Foundation.URL

extension SessionConfigurationLoader {

  @MainActor fileprivate static func load(
    features: Features
  ) throws -> Self {

    let session: Session = try features.instance()
    let configurationFetchNetworkOperation: ConfigurationFetchNetworkOperation = try features.instance()

    let configuration: ComputedVariable<Dictionary<AnyHashable, FeatureConfigItem>> = .init(
      // TODO: we should update only on account changes
      // not on all session changes...
      transformed: session.updates
        //        .currentAccountSequence()
        //        .map { _ in Void() },
    ) { _ in
      try await fetchConfiguration()
    }

    @Sendable nonisolated func fetchConfiguration() async throws -> Dictionary<AnyHashable, FeatureConfigItem> {
      Diagnostics.logger.info("Fetching server configuration...")
      guard case .some = try? await session.currentAccount()
      else {
        Diagnostics.logger.info("...server configuration fetching skipped!")
        return .init()
      }
      let rawConfiguration: ConfigurationFetchNetworkOperationResult.Config
      do {
        rawConfiguration = try await configurationFetchNetworkOperation().config
      }
      catch {
				Diagnostics.logger.info("...server configuration fetching failed!")
        throw error
      }

      var configuration: Dictionary<AnyHashable, FeatureConfigItem> = .init()

      if let legal: ConfigurationFetchNetworkOperationResult.Legal = rawConfiguration.legal {
        configuration[FeatureFlags.Legal.identifier] = { () -> FeatureFlags.Legal in
          let termsURL: URL? = .init(string: legal.terms.url)
          let privacyPolicyURL: URL? = .init(string: legal.privacyPolicy.url)

          switch (termsURL, privacyPolicyURL) {
          case (.none, .none):
            return .none
          case let (.some(termsURL), .none):
            return .terms(termsURL)
          case let (.none, .some(privacyPolicyURL)):
            return .privacyPolicy(privacyPolicyURL)
          case let (.some(termsURL), .some(privacyPolicyURL)):
            return .both(termsURL: termsURL, privacyPolicyURL: privacyPolicyURL)
          }
        }()
      }
      else {
        configuration[FeatureFlags.Legal.identifier] = FeatureFlags.Legal.default
      }

      if let folders: ConfigurationPlugins.Folders = rawConfiguration.plugins.firstElementOfType(), folders.enabled {
        configuration[FeatureFlags.Folders.identifier] = FeatureFlags.Folders.enabled(
          version: folders.version
        )
      }
      else {
        configuration[FeatureFlags.Folders.identifier] = FeatureFlags.Folders.default
      }

      if let previewPassword: ConfigurationPlugins.PreviewPassword = rawConfiguration.plugins.firstElementOfType() {
        configuration[FeatureFlags.PreviewPassword.identifier] = { () -> FeatureFlags.PreviewPassword in
          if previewPassword.enabled {
            return .enabled
          }
          else {
            return .disabled
          }
        }()
      }
      else {
        configuration[FeatureFlags.PreviewPassword.identifier] = FeatureFlags.PreviewPassword.default
      }

      if let tags: ConfigurationPlugins.Tags = rawConfiguration.plugins.firstElementOfType(), tags.enabled {
        configuration[FeatureFlags.Tags.identifier] = FeatureFlags.Tags.enabled
      }
      else {
        configuration[FeatureFlags.Tags.identifier] = FeatureFlags.Tags.default
      }

      if let totp: ConfigurationPlugins.TOTP = rawConfiguration.plugins.firstElementOfType(), totp.enabled {
        configuration[FeatureFlags.TOTP.identifier] = FeatureFlags.TOTP.enabled
      }
      else {
        configuration[FeatureFlags.TOTP.identifier] = FeatureFlags.TOTP.default
      }

      Diagnostics.logger.info("...server configuration fetched!")

      return configuration
    }

    @Sendable nonisolated func fetchIfNeeded() async throws {
      _ = try await configuration.value
    }

    @Sendable nonisolated func configuration(
      _ itemType: FeatureConfigItem.Type
    ) async -> FeatureConfigItem? {
      try? await configuration.value[itemType.identifier]
    }

    return Self(
      fetchIfNeeded: fetchIfNeeded,
      configuration: configuration(_:)
    )
  }
}

extension FeaturesRegistry {

  internal mutating func usePassboltSessionConfigurationLoader() {
    self.use(
      .lazyLoaded(
        SessionConfigurationLoader.self,
        load: SessionConfigurationLoader.load(features:)
      )
    )
  }
}

extension Array where Element == ConfigurationPlugin {

  fileprivate func firstElementOfType<T>(
    _ ofType: T.Type = T.self
  ) -> T?
  where T: ConfigurationPlugin {
    first { $0 is T } as? T
  }
}
