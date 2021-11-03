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

  func test_fetchAndStoreFeatureConfigLegal_succeeds() {
    let config: Config = .init(
      legal: .init(
        privacyPolicy: .init(url: "https://passbolt.com/privacy"),
        terms: .init(url: "https://passbolt.com/terms")
      ),
      plugins: []
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
      .sinkDrop()
      .store(in: cancellables)

    let result: FeatureConfig.Legal = featureConfig.configuration()
    let expectedTermsURL: URL! = .init(string: config.legal!.terms.url)
    let expectedPrivacyPolicyURL: URL! = .init(string: config.legal!.privacyPolicy.url)

    XCTAssertEqual(result, .both(termsURL: expectedTermsURL, privacyPolicyURL: expectedPrivacyPolicyURL))
  }

  func test_fetchAndStoreFeatureConfigLegal_recoversWithDefault_whenfetchFails() {
    networkClient.configRequest = .failingWith(.testError())

    accountSession.statePublisher = always(
      Just(.authorized(validAccount)).eraseToAnyPublisher()
    )

    features.use(accountSession)
    features.use(networkClient)

    let featureFlags: FeatureConfig = testInstance()

    featureFlags.fetchIfNeeded()
      .sinkDrop()
      .store(in: cancellables)

    let result: FeatureConfig.Legal = featureFlags.configuration()

    XCTAssertEqual(result, .default)
  }

  func test_clearStoredFeatureConfig_whenAccountSession_becomesDefault() {
    let config: Config = .init(
      legal: .init(
        privacyPolicy: .init(url: "https://passbolt.com/privacy"),
        terms: .init(url: "https://passbolt.com/terms")
      ),
      plugins: []
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
      .sinkDrop()
      .store(in: cancellables)

    accountStatePublisher.send(.none(lastUsed: validAccount))

    let result: FeatureConfig.Legal = featureConfig.configuration()

    XCTAssertEqual(result, .default)
  }

  func
    test_clearStoredFeatureConfig_whenAccountSession_becomesAuthorizationRequired_andAccountID_matchesStoredAccountID()
  {
    let config: Config = .init(
      legal: .init(
        privacyPolicy: .init(url: "https://passbolt.com/privacy"),
        terms: .init(url: "https://passbolt.com/terms")
      ),
      plugins: []
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
      .sinkDrop()
      .store(in: cancellables)

    accountStatePublisher.send(.authorizationRequired(validAccount))

    let result: FeatureConfig.Legal = featureConfig.configuration()

    let expectedTermsURL: URL! = .init(string: config.legal!.terms.url)
    let expectedPrivacyPolicyURL: URL! = .init(string: config.legal!.privacyPolicy.url)

    XCTAssertEqual(result, .both(termsURL: expectedTermsURL, privacyPolicyURL: expectedPrivacyPolicyURL))
  }

  func test_fetchAndStoreFeatureConfigWithAllPluginsEnabled_succeeds() {
    let config: Config = .init(
      legal: nil,
      plugins: [
        Config.Folders(enabled: true, version: "1.0.2"),
        Config.PreviewPassword(enabled: true),
        Config.Tags(enabled: true, version: "1.0.1"),
      ]
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
      .sinkDrop()
      .store(in: cancellables)

    let folders: FeatureConfig.Folders = featureConfig.configuration()
    let previewPassword: FeatureConfig.PreviewPassword = featureConfig.configuration()
    let tags: FeatureConfig.Tags = featureConfig.configuration()

    XCTAssertEqual(folders, .enabled(version: "1.0.2"))
    XCTAssertEqual(previewPassword, .enabled)
    XCTAssertEqual(tags, .enabled)
  }

  func test_fetchAndStoreFeatureConfigWithNoPlugins_succeeds_withDefaultValues() {
    let config: Config = .init(
      legal: nil,
      plugins: []
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
      .sinkDrop()
      .store(in: cancellables)

    let folders: FeatureConfig.Folders = featureConfig.configuration()
    let previewPassword: FeatureConfig.PreviewPassword = featureConfig.configuration()
    let tags: FeatureConfig.Tags = featureConfig.configuration()

    XCTAssertEqual(folders, .default)
    XCTAssertEqual(previewPassword, .default)
    XCTAssertEqual(tags, .default)
  }
}

private let validAccount: Account = .init(
  localID: .init(rawValue: UUID.test.uuidString),
  domain: "https://passbolt.dev",
  userID: "USER_ID",
  fingerprint: "FINGERPRINT"
)
