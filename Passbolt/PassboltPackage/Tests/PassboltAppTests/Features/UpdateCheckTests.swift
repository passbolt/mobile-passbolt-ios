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

import Combine
import Features
import NetworkClient
import TestExtensions
import XCTest

@testable import PassboltApp

// swift-format-ignore: AlwaysUseLowerCamelCase, NeverUseImplicitlyUnwrappedOptionals
final class UpdateCheckTests: TestCase {

  func test_updateAvailable_throws_whenFetchingAvailableVersionFails() {
    features.patch(
      \NetworkClient.appVersionsAvailableRequest,
      with: .failingWith(.testError())
    )
    environment.appMeta.version = always("")

    let feature: UpdateCheck = testInstance()

    XCTAssertThrows(TheError.self, identifier: .versionCheckFailed) {
      try await feature.updateAvailable()
    }
  }

  func test_updateAvailable_throws_whenFetchedAvailableVersionIsMissing() {
    features.patch(
      \NetworkClient.appVersionsAvailableRequest,
      with: .respondingWith(.init(results: []))
    )
    environment.appMeta.version = always("")

    let feature: UpdateCheck = testInstance()

    XCTAssertThrows(TheError.self, identifier: .versionCheckFailed) {
      try await feature.updateAvailable()
    }
  }

  func test_updateAvailable_throws_whenFetchedAvailableVersionIsInvalid() {
    features.patch(
      \NetworkClient.appVersionsAvailableRequest,
      with: .respondingWith(.init(results: [.init(version: "invalid")]))
    )
    environment.appMeta.version = always("")

    let feature: UpdateCheck = testInstance()

    XCTAssertThrows(TheError.self, identifier: .versionCheckFailed) {
      try await feature.updateAvailable()
    }
  }

  func test_updateAvailable_throws_whenFetchedAvailableVersionIsNotFullyValid() {
    features.patch(
      \NetworkClient.appVersionsAvailableRequest,
      with: .respondingWith(.init(results: [.init(version: "1.3.x")]))
    )
    environment.appMeta.version = always("")

    let feature: UpdateCheck = testInstance()

    XCTAssertThrows(TheError.self, identifier: .versionCheckFailed) {
      try await feature.updateAvailable()
    }
  }

  func test_updateAvailable_throws_whenAppMetaVersionIsInvalid() {
    features.patch(
      \NetworkClient.appVersionsAvailableRequest,
      with: .respondingWith(.init(results: [.init(version: "1.3.x")]))
    )
    environment.appMeta.version = always("")

    let feature: UpdateCheck = testInstance()

    XCTAssertThrows(TheError.self, identifier: .versionCheckFailed) {
      try await feature.updateAvailable()
    }
  }

  func test_checkRequired_returnsTrue_whenNotCheckedYet() {
    features.usePlaceholder(for: NetworkClient.self)
    let feature: UpdateCheck = testInstance()

    XCTAssertTrue {
      await feature.checkRequired()
    }
  }

  func test_checkRequired_returnsTrue_whenCheckingFails() {
    features.patch(
      \NetworkClient.appVersionsAvailableRequest,
       with: .failingWith(.testError())
    )
    environment.appMeta.version = always("")

    let feature: UpdateCheck = testInstance()

    Task {
      try await feature.updateAvailable()
    }

    XCTAssertTrue {
      await feature.checkRequired()
    }
  }

  func test_checkRequired_returnsFalse_whenCheckingSucceeds() {
    features.patch(
      \NetworkClient.appVersionsAvailableRequest,
       with: .respondingWith(.init(results: [.init(version: "1.2.3")]))
    )
    environment.appMeta.version = always("1.2.3")

    let feature: UpdateCheck = testInstance()

    XCTAssertFalse {
      _ = try await feature.updateAvailable()
      return await feature.checkRequired()
    }
  }
}
