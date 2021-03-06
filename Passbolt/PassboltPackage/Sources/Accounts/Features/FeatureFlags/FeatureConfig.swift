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

import CommonModels
import Features
import NetworkClient

import struct Foundation.URL

extension FeatureConfigItem {

  fileprivate static var featureFlagIdentifier: ObjectIdentifier { ObjectIdentifier(Self.self) }
}

public struct FeatureConfig {

  public var config: @AccountSessionActor (FeatureConfigItem.Type) -> FeatureConfigItem?
  public var fetchIfNeeded: @AccountSessionActor () async throws -> Void
}

extension FeatureConfig: Feature {

  public static func load(
    in environment: AppEnvironment,
    using features: FeatureFactory,
    cancellables: Cancellables
  ) async throws -> FeatureConfig {
    let accountSession: AccountSession = try await features.instance()
    let diagnostics: Diagnostics = try await features.instance()
    let networkClient: NetworkClient = try await features.instance()

    var accountID: Account.LocalID?
    var configuration: Dictionary<ObjectIdentifier, FeatureConfigItem> = .init()

    accountSession
      .statePublisher()
      .sink { state in
        cancellables.executeOnAccountSessionActor {
          switch state {
          case let .authorizationRequired(account) where account.localID == accountID,
            let .authorized(account) where account.localID == accountID,
            let .authorizedMFARequired(account, _) where account.localID == accountID:
            break
          case let .authorizationRequired(account), let .authorized(account), let .authorizedMFARequired(account, _):
            accountID = account.localID
            configuration = .init()
          case .none:
            accountID = nil
            configuration = .init()
          }
        }
      }
      .store(in: cancellables)

    @AccountSessionActor func config(for featureType: FeatureConfigItem.Type) -> FeatureConfigItem {
      return configuration[featureType.featureFlagIdentifier] ?? featureType.default
    }

    @AccountSessionActor func handle(response: ConfigResponse) {
      let config: Config = response.body.config

      if let legal: Config.Legal = config.legal {
        configuration[FeatureFlags.Legal.featureFlagIdentifier] = { () -> FeatureFlags.Legal in
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
        configuration[FeatureFlags.Legal.featureFlagIdentifier] = FeatureFlags.Legal.default
      }

      if let folders: Config.Folders = config.plugins.firstElementOfType(), folders.enabled {
        configuration[FeatureFlags.Folders.featureFlagIdentifier] = FeatureFlags.Folders.enabled(
          version: folders.version
        )
      }
      else {
        configuration[FeatureFlags.Folders.featureFlagIdentifier] = FeatureFlags.Folders.default
      }

      if let previewPassword: Config.PreviewPassword = config.plugins.firstElementOfType() {
        configuration[FeatureFlags.PreviewPassword.featureFlagIdentifier] = { () -> FeatureFlags.PreviewPassword in
          if previewPassword.enabled {
            return .enabled
          }
          else {
            return .disabled
          }
        }()
      }
      else {
        configuration[FeatureFlags.PreviewPassword.featureFlagIdentifier] = FeatureFlags.PreviewPassword.default
      }

      if let tags: Config.Tags = config.plugins.firstElementOfType(), tags.enabled {
        configuration[FeatureFlags.Tags.featureFlagIdentifier] = FeatureFlags.Tags.enabled
      }
      else {
        configuration[FeatureFlags.Tags.featureFlagIdentifier] = FeatureFlags.Tags.default
      }
    }

    @AccountSessionActor func fetchIfNeeded() async throws {
      guard configuration.isEmpty
      else { return }

      diagnostics.diagnosticLog("Fetching server configuration...")

      let response: ConfigResponse = try await networkClient.configRequest.makeAsync()
      handle(response: response)
      diagnostics.diagnosticLog("...server configuration fetched!")
    }

    return Self(
      config: config,
      fetchIfNeeded: fetchIfNeeded
    )
  }
}

extension FeatureConfig {

  @AccountSessionActor public func configuration<F: FeatureConfigItem>(
    for featureFlagType: F.Type = F.self
  ) -> F {
    config(featureFlagType) as? F ?? .default
  }
}

extension FeatureConfig {

  public var featureUnload: @FeaturesActor () async throws -> Void { {} }
}

extension Array where Element == Plugin {

  fileprivate func firstElementOfType<T>(_ ofType: T.Type = T.self) -> T? {
    first { $0 is T } as? T
  }
}

#if DEBUG
extension FeatureConfig {

  public static var placeholder: FeatureConfig {
    Self(
      config: unimplemented("You have to provide mocks for used methods"),
      fetchIfNeeded: unimplemented("You have to provide mocks for used methods")
    )
  }
}
#endif
