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

import Commons
import TestExtensions
import XCTest

@testable import Accounts
@testable import NetworkClient

final class FeatureConfigTests: TestCase {

  var accountSession: AccountSession!
  var networkClient: NetworkClient!

  override func setUp() {
    super.setUp()

    accountSession = .placeholder
    networkClient = .placeholder
  }

  override func tearDown() {
    accountSession = nil
    networkClient = nil
    super.tearDown()
  }

  func test_fetchAndStoreFeatureConfigLegal_Succeeds() {
    let config: Config = .init(
      legal: .init(
        privacyPolicy: .init(url: "https://passbolt.com/privacy"),
        terms: .init(url: "https://passbolt.com/terms")
      )
    )

    networkClient.configRequest = .respondingWith(
      .init(header: .mock(), body: .init(config: config))
    )

    accountSession.statePublisher = always(
      Just(.authorized(validAccount)).eraseToAnyPublisher()
    )

    features.use(accountSession)
    features.use(networkClient)

    let featureConfig: FeatureConfig = testInstance()

    featureConfig.fetchIfNeeded()
      .sink(
        receiveCompletion: { _ in },
        receiveValue: { _ in }
      )
      .store(in: cancellables)

    let result: FeatureConfig.Legal! = featureConfig.configuration()

    XCTAssertEqual(result.privacyPolicyUrl, config.legal!.privacyPolicy.url)
    XCTAssertEqual(result.termsUrl, config.legal!.terms.url)
  }

  func test_fetchAndStoreFeatureConfigLegal_Fails() {
    networkClient.configRequest = .failingWith(.testError())

    accountSession.statePublisher = always(
      Just(.authorized(validAccount)).eraseToAnyPublisher()
    )

    features.use(accountSession)
    features.use(networkClient)

    let featureFlags: FeatureConfig = testInstance()

    featureFlags.fetchIfNeeded()
      .sink(
        receiveCompletion: { _ in },
        receiveValue: { _ in }
      )
      .store(in: cancellables)

    let result: FeatureConfig.Legal! = featureFlags.configuration()

    XCTAssertNil(result)
  }

  func test_clearStoredFeatureConfig_whenAccountSession_becomesNone() {
    let config: Config = .init(
      legal: .init(
        privacyPolicy: .init(url: "https://passbolt.com/privacy"),
        terms: .init(url: "https://passbolt.com/terms")
      )
    )

    networkClient.configRequest = .respondingWith(
      .init(header: .mock(), body: .init(config: config))
    )

    let accountStatePublisher: CurrentValueSubject<AccountSession.State, Never> = .init(.authorized(validAccount))

    accountSession.statePublisher = always(
      accountStatePublisher.eraseToAnyPublisher()
    )

    features.use(accountSession)
    features.use(networkClient)

    let featureConfig: FeatureConfig = testInstance()

    featureConfig.fetchIfNeeded()
      .sink(
        receiveCompletion: { _ in },
        receiveValue: { _ in }
      )
      .store(in: cancellables)

    accountStatePublisher.send(.none(lastUsed: validAccount))

    let result: FeatureConfig.Legal! = featureConfig.configuration()

    XCTAssertNil(result)
  }

  func
    test_clearStoredFeatureConfig_whenAccountSession_becomesAuthorizationRequired_andAccountID_matchesStoredAccountID()
  {
    let config: Config = .init(
      legal: .init(
        privacyPolicy: .init(url: "https://passbolt.com/privacy"),
        terms: .init(url: "https://passbolt.com/terms")
      )
    )

    networkClient.configRequest = .respondingWith(
      .init(header: .mock(), body: .init(config: config))
    )

    let accountStatePublisher: CurrentValueSubject<AccountSession.State, Never> = .init(.authorized(validAccount))

    accountSession.statePublisher = always(
      accountStatePublisher.eraseToAnyPublisher()
    )

    features.use(accountSession)
    features.use(networkClient)

    let featureConfig: FeatureConfig = testInstance()

    featureConfig.fetchIfNeeded()
      .sink(
        receiveCompletion: { _ in },
        receiveValue: { _ in }
      )
      .store(in: cancellables)

    accountStatePublisher.send(.authorizationRequired(validAccount))

    let result: FeatureConfig.Legal! = featureConfig.configuration()

    XCTAssertEqual(result.privacyPolicyUrl, config.legal!.privacyPolicy.url)
    XCTAssertEqual(result.termsUrl, config.legal!.terms.url)
  }
}

private let validAccount: Account = .init(
  localID: .init(rawValue: UUID.test.uuidString),
  domain: "https://passbolt.dev",
  userID: "USER_ID",
  fingerprint: "FINGERPRINT"
)
