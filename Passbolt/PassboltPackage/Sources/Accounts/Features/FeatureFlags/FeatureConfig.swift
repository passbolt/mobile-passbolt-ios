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
import NetworkClient

import class Foundation.NSRecursiveLock

public protocol FeatureConfigItem {}

extension FeatureConfigItem {

  fileprivate static var featureFlagIdentifier: ObjectIdentifier { ObjectIdentifier(Self.self) }
}

public struct FeatureConfig {

  public var config: (FeatureConfigItem.Type) -> FeatureConfigItem?
  public var fetchIfNeeded: () -> AnyPublisher<Void, TheError>
}

extension FeatureConfig: Feature {

  public static func load(
    in environment: Environment,
    using features: FeatureFactory,
    cancellables: Cancellables
  ) -> FeatureConfig {
    let accountSession: AccountSession = features.instance()
    let diagnostics: Diagnostics = features.instance()
    let networkClient: NetworkClient = features.instance()

    var accountID: Account.LocalID?
    var all: Dictionary<ObjectIdentifier, FeatureConfigItem> = .init()
    let lock: NSRecursiveLock = .init()

    accountSession
      .statePublisher()
      .sink { state in
        lock.lock()
        defer { lock.unlock() }
        switch state {
        case let .authorizationRequired(account) where account.localID == accountID,
          let .authorized(account) where account.localID == accountID:
          break
        case let .authorizationRequired(account), let .authorized(account):
          accountID = account.localID
          all = .init()
        case .none:
          accountID = nil
          all = .init()
        }
      }
      .store(in: cancellables)

    func config(for featureType: FeatureConfigItem.Type) -> FeatureConfigItem? {
      lock.lock()
      defer { lock.unlock() }

      return all[featureType.featureFlagIdentifier]
    }

    func handle(response: ConfigResponse) {
      lock.lock()
      defer { lock.unlock() }

      if let legal = response.body.config.legal {
        all[Legal.featureFlagIdentifier] = Legal(
          termsUrl: legal.terms.url,
          privacyPolicyUrl: legal.privacyPolicy.url
        )
      }
    }

    func fetchIfNeeded() -> AnyPublisher<Void, TheError> {
      lock.lock()
      let isFetched: Bool = all.isEmpty
      lock.unlock()

      guard isFetched
      else {
        return Just(Void())
          .setFailureType(to: TheError.self)
          .eraseToAnyPublisher()
      }

      return networkClient.configRequest.make()
        .map { (response: ConfigResponse) in
          handle(response: response)
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
  ) -> F? {
    config(featureFlagType) as? F
  }
}

#if DEBUG
extension FeatureConfig {

  public static var placeholder: FeatureConfig {
    Self(
      config: Commons.placeholder("You have to provide mocks for used methods"),
      fetchIfNeeded: Commons.placeholder("You have to provide mocks for used methods")
    )
  }
}
#endif
