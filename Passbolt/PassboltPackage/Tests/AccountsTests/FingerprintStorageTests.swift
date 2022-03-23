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
import Crypto
import Features
import NetworkClient
import TestExtensions
import XCTest

@testable import Accounts

// swift-format-ignore: AlwaysUseLowerCamelCase, NeverUseImplicitlyUnwrappedOptionals
final class FingerprintStorageTests: TestCase {

  var accountDataStore: AccountsDataStore!

  override func featuresActorSetUp() async throws {
    try await super.featuresActorSetUp()
    accountDataStore = .placeholder
  }

  override func featuresActorTearDown() async throws {
    accountDataStore = nil
    try await super.featuresActorTearDown()
  }

  func test_loadServerFingerprint_succeeds_withNil_whenNoFingerprintWasStored() async throws {
    let storedFingerprint: Fingerprint? = nil
    accountDataStore.loadServerFingerprint = always(.success(storedFingerprint))
    await features.use(accountDataStore)

    let feature: FingerprintStorage = try await testInstance()
    var result: Fingerprint?

    switch await feature.loadServerFingerprint(.init(rawValue: "ACCOUNT_ID")) {
    case let .success(serverFingerprint):
      result = serverFingerprint
    case .failure:
      break
    }

    XCTAssertNil(result)
  }

  func test_loadServerFingerprint_succeeds_whenDataStoreLoadSucceeds() async throws {
    accountDataStore.loadServerFingerprint = always(.success("FINGERPRINT"))
    await features.use(accountDataStore)

    let feature: FingerprintStorage = try await testInstance()
    var result: Fingerprint? = nil

    switch await feature.loadServerFingerprint(.init(rawValue: "ACCOUNT_ID")) {
    case let .success(serverFingerprint):
      result = serverFingerprint
    case .failure:
      break
    }

    XCTAssertEqual(result?.rawValue, "FINGERPRINT")
  }

  func test_loadServerFingerprint_fails() async throws {
    accountDataStore.loadServerFingerprint = always(.failure(MockIssue.error()))
    await features.use(accountDataStore)

    let feature: FingerprintStorage = try await testInstance()
    var result: Error?

    switch await feature.loadServerFingerprint(.init(rawValue: "ACCOUNT_ID")) {
    case .success:
      break
    case let .failure(error):
      result = error
    }

    XCTAssertError(result, matches: MockIssue.self)
  }

  func test_storeServerFingerprint_succeeds_whenDataStoreSaveSucceeds() async throws {
    var storedFingerprint: Fingerprint? = nil

    accountDataStore.loadServerFingerprint = always(.success(storedFingerprint))
    accountDataStore.storeServerFingerprint = { _, fingerprint in
      storedFingerprint = fingerprint
      return .success(())
    }

    await features.use(accountDataStore)

    let feature: FingerprintStorage = try await testInstance()
    var result: Fingerprint?

    _ = await feature.storeServerFingerprint(.init(rawValue: "ACCOUNT_ID"), .init(rawValue: "FINGERPRINT"))

    switch await feature.loadServerFingerprint(.init(rawValue: "ACCOUNT_ID")) {
    case let .success(serverFingerprint):
      result = serverFingerprint
    case .failure:
      break
    }

    XCTAssertEqual(result, storedFingerprint)
  }

  func test_storeServerFingerprint_fails() async throws {
    accountDataStore.loadServerFingerprint = always(.success("FINGERPRINT"))
    accountDataStore.storeServerFingerprint = always(.failure(MockIssue.error()))

    await features.use(accountDataStore)

    let feature: FingerprintStorage = try await testInstance()
    var result: Error?

    switch await feature.storeServerFingerprint(.init(rawValue: "ACCOUNT_ID"), .init(rawValue: "FINGERPRINT")) {
    case .success:
      break
    case let .failure(error):
      result = error
    }

    XCTAssertError(result, matches: MockIssue.self)
  }
}
