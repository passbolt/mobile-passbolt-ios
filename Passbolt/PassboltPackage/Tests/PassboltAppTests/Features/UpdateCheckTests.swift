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
import TestExtensions
import XCTest

@testable import PassboltApp

// swift-format-ignore: AlwaysUseLowerCamelCase, NeverUseImplicitlyUnwrappedOptionals
final class UpdateCheckTests: MainActorTestCase {

  func test_updateAvailable_throws_whenFetchingAvailableVersionFails() async throws {
    self.environment.appMeta.version = always("")
    features.patch(
      \AppVersionsFetchNetworkOperation.execute,
      with: alwaysThrow(MockIssue.error())
    )

    let feature: UpdateCheck = try await testInstance()
    var result: Error?
    do {
      try await feature.updateAvailable()
      XCTFail()
    }
    catch {
      result = error
    }
    XCTAssertError(result, matches: MockIssue.self)
  }

  func test_updateAvailable_throws_whenFetchedAvailableVersionIsMissing() async throws {
    self.environment.appMeta.version = always("")
    features.patch(
      \AppVersionsFetchNetworkOperation.execute,
      with: always(
        .init(
          results: []
        )
      )
    )

    let feature: UpdateCheck = try await testInstance()

    var result: Error?
    do {
      try await feature.updateAvailable()
      XCTFail()
    }
    catch {
      result = error
    }
    XCTAssertError(result, matches: TheErrorLegacy.self, verification: { $0.identifier == .versionCheckFailed })
  }

  func test_updateAvailable_throws_whenFetchedAvailableVersionIsInvalid() async throws {
    self.environment.appMeta.version = always("")
    features.patch(
      \AppVersionsFetchNetworkOperation.execute,
      with: always(
        .init(
          results: [
            .init(
              version: "invalid"
            )
          ]
        )
      )
    )

    let feature: UpdateCheck = try await testInstance()

    var result: Error?
    do {
      try await feature.updateAvailable()
      XCTFail()
    }
    catch {
      result = error
    }
    XCTAssertError(result, matches: TheErrorLegacy.self, verification: { $0.identifier == .versionCheckFailed })
  }

  func test_updateAvailable_throws_whenFetchedAvailableVersionIsNotFullyValid() async throws {
    self.environment.appMeta.version = always("")
    features.patch(
      \AppVersionsFetchNetworkOperation.execute,
      with: always(
        .init(
          results: [
            .init(
              version: "1.3.x"
            )
          ]
        )
      )
    )

    let feature: UpdateCheck = try await testInstance()

    var result: Error?
    do {
      try await feature.updateAvailable()
      XCTFail()
    }
    catch {
      result = error
    }
    XCTAssertError(result, matches: TheErrorLegacy.self, verification: { $0.identifier == .versionCheckFailed })
  }

  func test_updateAvailable_throws_whenAppMetaVersionIsInvalid() async throws {
    self.environment.appMeta.version = always("")
    features.patch(
      \AppVersionsFetchNetworkOperation.execute,
      with: always(
        .init(
          results: [
            .init(
              version: "1.3.x"
            )
          ]
        )
      )
    )

    let feature: UpdateCheck = try await testInstance()

    var result: Error?
    do {
      try await feature.updateAvailable()
      XCTFail()
    }
    catch {
      result = error
    }
    XCTAssertError(result, matches: TheErrorLegacy.self, verification: { $0.identifier == .versionCheckFailed })
  }

  func test_checkRequired_returnsTrue_whenNotCheckedYet() async throws {
    features.usePlaceholder(for: AppVersionsFetchNetworkOperation.self)

    let feature: UpdateCheck = try await testInstance()

    let result = await feature.checkRequired()
    XCTAssertTrue(result)
  }

  func test_checkRequired_returnsTrue_whenCheckingFails() async throws {
    self.environment.appMeta.version = always("")
    await features.patch(
      \AppVersionsFetchNetworkOperation.execute,
      with: alwaysThrow(MockIssue.error())
    )

    let feature: UpdateCheck = try await testInstance()

    _ = try? await feature.updateAvailable()

    let result = await feature.checkRequired()
    XCTAssertTrue(result)
  }

  func test_checkRequired_returnsFalse_whenCheckingSucceeds() async throws {
    self.environment.appMeta.version = always("1.2.3")
    features.patch(
      \AppVersionsFetchNetworkOperation.execute,
      with: always(
        .init(
          results: [
            .init(
              version: "1.2.3"
            )
          ]
        )
      )
    )

    let feature: UpdateCheck = try await testInstance()

    _ = try await feature.updateAvailable()
    let result = await feature.checkRequired()

    XCTAssertFalse(result)
  }
}
