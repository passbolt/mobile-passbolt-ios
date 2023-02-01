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

import Accounts
import SessionData
import TestExtensions
import XCTest

@testable import PassboltResources
@testable import Resources

// swift-format-ignore: AlwaysUseLowerCamelCase, NeverUseImplicitlyUnwrappedOptionals
final class ResourceDetailsTests: LoadableFeatureTestCase<ResourceDetails> {

  override class var testedImplementationScope: any FeaturesScope.Type { SessionScope.self }

  override class func testedImplementationRegister(
    _ registry: inout FeaturesRegistry
  ) {
    registry.usePassboltResourceDetails()
  }

  private var updatesSequence: UpdatesSequenceSource!

  override func prepare() throws {
    self.set(
      SessionScope.self,
      context: .init(
        account: .mock_ada,
        configuration: .mock_1
      )
    )
    use(Session.placeholder)
    use(SessionData.placeholder)
    use(SessionCryptography.placeholder)
    self.updatesSequence = .init()
    patch(
      \SessionData.updatesSequence,
      with: self.updatesSequence.updatesSequence
    )
    patch(
      \ResourceDetailsFetchDatabaseOperation.execute,
      with: always(.mock_1)
    )
    use(ResourceSecretFetchNetworkOperation.placeholder)
  }

  override func cleanup() throws {
    self.updatesSequence = nil
  }

  func test_details_providesCachedDetails() async throws {
    let expectedResult: ResourceDetailsDSV = .mock_1
    patch(
      \ResourceDetailsFetchDatabaseOperation.execute,
      with: always(expectedResult)
    )

    let feature: ResourceDetails = try await self.testedInstance(
      context: .mock_1
    )

    await XCTAssertValue(
      equal: expectedResult
    ) {
      try await feature.details()
    }
  }

  func test_details_providesUpdatedDetails_whenUpdatesSequenceGeneratesValue() async throws {
    let expectedResult: ResourceDetailsDSV = .mock_1
    var results: Array<ResourceDetailsDSV> = [
      .mock_1,
      expectedResult,
    ]
    let nextResult: () -> ResourceDetailsDSV = {
      results.removeFirst()
    }
    patch(
      \ResourceDetailsFetchDatabaseOperation.execute,
      with: always(nextResult())
    )

    let feature: ResourceDetails = try await self.testedInstance(
      context: .mock_1
    )

    _ = try await feature.details()

    self.updatesSequence.sendUpdate()

    await XCTAssertValue(
      equal: expectedResult
    ) {
      try await feature.details()
    }
  }

  func test_decryptSecret_fails_whenDecryptionFails() async throws {
    patch(
      \SessionCryptography.decryptMessage,
      with: alwaysThrow(
        MockIssue.error()
      )
    )
    patch(
      \ResourceSecretFetchNetworkOperation.execute,
      with: always(.init(data: "encrypted-data"))
    )

    let feature: ResourceDetails = try await self.testedInstance(
      context: .mock_1
    )

    await XCTAssertError(
      matches: MockIssue.self
    ) {
      try await feature.secret()
    }
  }

  func test_decryptSecret_fails_whenFetchingSecretFails() async throws {
    patch(
      \ResourceSecretFetchNetworkOperation.execute,
      with: alwaysThrow(MockIssue.error())
    )

    let feature: ResourceDetails = try await self.testedInstance(
      context: .mock_1
    )

    await XCTAssertError(
      matches: MockIssue.self
    ) {
      try await feature.secret()
    }
  }

  func test_decryptSecret_returnsSecret_whenAllOperationsSucceed() async throws {
    let expectedResult: ResourceSecret = .init(
      rawValue: "{\"password\":\"secret\"}",
      values: ["password": "secret"]
    )
    patch(
      \SessionCryptography.decryptMessage,
      with: always(expectedResult.rawValue)
    )
    patch(
      \ResourceSecretFetchNetworkOperation.execute,
      with: always(.init(data: "encrypted-data"))
    )

    let feature: ResourceDetails = try await self.testedInstance(
      context: .mock_1
    )

    await XCTAssertValue(
      equal: expectedResult
    ) {
      try await feature.secret()
    }
  }
}
