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

  public var config: (FeatureConfigItem.Type) -> FeatureConfigItem?
  public var fetchIfNeeded: () -> AnyPublisher<Void, TheErrorLegacy>
}

extension FeatureConfig: Feature {

  public static func load(
    in environment: AppEnvironment,
    using features: FeatureFactory,
    cancellables: Cancellables
  ) -> FeatureConfig {
    let accountSession: AccountSession = features.instance()
    let diagnostics: Diagnostics = features.instance()
    let networkClient: NetworkClient = features.instance()

    var accountID: Account.LocalID?
    let all: CurrentValueSubject<Dictionary<ObjectIdentifier, FeatureConfigItem>, Never> = .init(.init())

    accountSession
      .statePublisher()
      .sink { state in
        switch state {
        case let .authorizationRequired(account) where account.localID == accountID,
          let .authorized(account) where account.localID == accountID,
          let .authorizedMFARequired(account, _) where account.localID == accountID:
          break
        case let .authorizationRequired(account), let .authorized(account), let .authorizedMFARequired(account, _):
          accountID = account.localID
          all.value = .init()
        case .none:
          accountID = nil
          all.value = .init()
        }
      }
      .store(in: cancellables)

    func config(for featureType: FeatureConfigItem.Type) -> FeatureConfigItem {
      return all.value[featureType.featureFlagIdentifier] ?? featureType.default
    }

    func handle(response: ConfigResponse) {
      let config: Config = response.body.config

      if let legal: Config.Legal = config.legal {
        all.value[FeatureFlags.Legal.featureFlagIdentifier] = { () -> FeatureFlags.Legal in
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
        all.value[FeatureFlags.Legal.featureFlagIdentifier] = FeatureFlags.Legal.default
      }

      if let folders: Config.Folders = config.plugins.firstElementOfType(), folders.enabled {
        all.value[FeatureFlags.Folders.featureFlagIdentifier] = FeatureFlags.Folders.enabled(version: folders.version)
      }
      else {
        all.value[FeatureFlags.Folders.featureFlagIdentifier] = FeatureFlags.Folders.default
      }

      if let previewPassword: Config.PreviewPassword = config.plugins.firstElementOfType() {
        all.value[FeatureFlags.PreviewPassword.featureFlagIdentifier] = { () -> FeatureFlags.PreviewPassword in
          if previewPassword.enabled {
            return .enabled
          }
          else {
            return .disabled
          }
        }()
      }
      else {
        all.value[FeatureFlags.PreviewPassword.featureFlagIdentifier] = FeatureFlags.PreviewPassword.default
      }

      if let tags: Config.Tags = config.plugins.firstElementOfType(), tags.enabled {
        all.value[FeatureFlags.Tags.featureFlagIdentifier] = FeatureFlags.Tags.enabled
      }
      else {
        all.value[FeatureFlags.Tags.featureFlagIdentifier] = FeatureFlags.Tags.default
      }
    }

    func fetchIfNeeded() -> AnyPublisher<Void, TheErrorLegacy> {
      let isFetched: Bool = all.value.isEmpty

      guard isFetched
      else {
        return Just(Void())
          .setFailureType(to: TheErrorLegacy.self)
          .eraseToAnyPublisher()
      }

      diagnostics.diagnosticLog("Fetching server configuration...")

      return networkClient
        .configRequest
        .make()
        .mapErrorsToLegacy()
        .map { (response: ConfigResponse) in
          handle(response: response)
          diagnostics.diagnosticLog("...server configuration fetched!")
          return Void()
        }
        .collectErrorLog(using: diagnostics)
        .eraseToAnyPublisher()
    }

    return Self(
      config: config,
      fetchIfNeeded: fetchIfNeeded
    )
  }
}

extension FeatureConfig {

  public func configuration<F: FeatureConfigItem>(
    for featureFlagType: F.Type = F.self
  ) -> F {
    config(featureFlagType) as? F ?? .default
  }
}

extension FeatureConfig {

  public var featureUnload: () -> Bool { { true } }
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
