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
import TestExtensions
import XCTest

@testable import Accounts
@testable import NetworkClient

final class FeatureConfigTests: TestCase {

  var accountSession: AccountSession!
  var networkClient: NetworkClient!

  override func featuresActorSetUp() async throws {
    try await super.featuresActorSetUp()
    accountSession = .placeholder
    networkClient = .placeholder
  }

  override func featuresActorTearDown() async throws {
    accountSession = nil
    networkClient = nil
    try await super.featuresActorTearDown()
  }

  func test_fetchAndStoreFeatureConfigLegal_succeeds() async throws {
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

    await features.use(accountSession)
    await features.use(networkClient)

    let featureConfig: FeatureConfig = try await testInstance()

    try await featureConfig.fetchIfNeeded()

    let result: FeatureFlags.Legal = await featureConfig.configuration()
    let expectedTermsURL: URL! = .init(string: config.legal!.terms.url)
    let expectedPrivacyPolicyURL: URL! = .init(string: config.legal!.privacyPolicy.url)

    XCTAssertEqual(result, .both(termsURL: expectedTermsURL, privacyPolicyURL: expectedPrivacyPolicyURL))
  }

  func test_fetchAndStoreFeatureConfigLegal_recoversWithDefault_whenfetchFails() async throws {
    networkClient.configRequest = .failingWith(MockIssue.error())

    accountSession.statePublisher = always(
      Just(.authorized(validAccount)).eraseToAnyPublisher()
    )

    await features.use(accountSession)
    await features.use(networkClient)

    let featureFlags: FeatureConfig = try await testInstance()

    try? await featureFlags.fetchIfNeeded()

    let result: FeatureFlags.Legal = await featureFlags.configuration()

    XCTAssertEqual(result, .default)
  }

  func test_clearStoredFeatureConfig_whenAccountSession_becomesDefault() async throws {
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

    let accountStatePublisher: CurrentValueSubject<AccountSessionState, Never> = .init(.authorized(validAccount))

    accountSession.statePublisher = always(
      accountStatePublisher.eraseToAnyPublisher()
    )

    await features.use(accountSession)
    await features.use(networkClient)

    let featureConfig: FeatureConfig = try await testInstance()

    try await featureConfig.fetchIfNeeded()

    accountStatePublisher.send(.none(lastUsed: validAccount))

    // temporary wait for detached tasks
    try await Task.sleep(nanoseconds: 100 * NSEC_PER_MSEC)

    let result: FeatureFlags.Legal = await featureConfig.configuration()

    XCTAssertEqual(result, .default)
  }

  func
    test_clearStoredFeatureConfig_whenAccountSession_becomesAuthorizationRequired_andAccountID_matchesStoredAccountID()
    async throws
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

    let accountStatePublisher: CurrentValueSubject<AccountSessionState, Never> = .init(.authorized(validAccount))

    accountSession.statePublisher = always(
      accountStatePublisher.eraseToAnyPublisher()
    )

    await features.use(accountSession)
    await features.use(networkClient)

    let featureConfig: FeatureConfig = try await testInstance()

    try await featureConfig.fetchIfNeeded()

    accountStatePublisher.send(.authorizationRequired(validAccount))

    let result: FeatureFlags.Legal = await featureConfig.configuration()

    let expectedTermsURL: URL! = .init(string: config.legal!.terms.url)
    let expectedPrivacyPolicyURL: URL! = .init(string: config.legal!.privacyPolicy.url)

    XCTAssertEqual(result, .both(termsURL: expectedTermsURL, privacyPolicyURL: expectedPrivacyPolicyURL))
  }

  func test_fetchAndStoreFeatureConfigWithAllPluginsEnabled_succeeds() async throws {
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

    await features.use(accountSession)
    await features.use(networkClient)

    let featureConfig: FeatureConfig = try await testInstance()

    try await featureConfig.fetchIfNeeded()

    let folders: FeatureFlags.Folders = await featureConfig.configuration()
    let previewPassword: FeatureFlags.PreviewPassword = await featureConfig.configuration()
    let tags: FeatureFlags.Tags = await featureConfig.configuration()

    XCTAssertEqual(folders, .enabled(version: "1.0.2"))
    XCTAssertEqual(previewPassword, .enabled)
    XCTAssertEqual(tags, .enabled)
  }

  func test_fetchAndStoreFeatureConfigWithNoPlugins_succeeds_withDefaultValues() async throws {
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

    await features.use(accountSession)
    await features.use(networkClient)

    let featureConfig: FeatureConfig = try await testInstance()

    try await featureConfig.fetchIfNeeded()

    let folders: FeatureFlags.Folders = await featureConfig.configuration()
    let previewPassword: FeatureFlags.PreviewPassword = await featureConfig.configuration()
    let tags: FeatureFlags.Tags = await featureConfig.configuration()

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
