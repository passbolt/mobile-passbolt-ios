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
import CommonModels
import Features
import NetworkClient
import TestExtensions
import XCTest

@testable import Resources

// swift-format-ignore: AlwaysUseLowerCamelCase, NeverUseImplicitlyUnwrappedOptionals
final class ResourceDetailsTests: TestCase {

  private var updatesSequence: AsyncVariable<Void>!

  override func featuresActorSetUp() async throws {
    try await super.featuresActorSetUp()

    self.features.usePassboltResourceDetails()

    features.usePlaceholder(for: AccountSessionData.self)
    features.usePlaceholder(for: AccountSession.self)
    features.usePlaceholder(for: NetworkClient.self)
    features.usePlaceholder(for: AccountDatabase.self)

    self.updatesSequence = .init(initial: Void())
    features.patch(
      \AccountSessionData.updatesSequence,
      with: always(
        self.updatesSequence
          .asAnyAsyncSequence()
      )
    )
    features.patch(
      \AccountDatabase.fetchResourceDetailsDSVs,
      with: .returning(
        .random()
      )
    )
  }

  override func featuresActorTearDown() async throws {
    try await super.featuresActorTearDown()
    self.updatesSequence = nil
  }

  func test_loading_fails_whenFetchingDetailsFails() async {
    await features.patch(
      \AccountDatabase.fetchResourceDetailsDSVs,
      with: .failingWith(
        MockIssue.error()
      )
    )
    await XCTAssertError(
      matches: MockIssue.self
    ) {
      try await self.testInstance(ResourceDetails.self, context: .random())
    }
  }

  func test_details_providesCachedDetails() async throws {
    let expectedResult: ResourceDetailsDSV = .random()
    await features.patch(
      \AccountDatabase.fetchResourceDetailsDSVs,
      with: .returning(
        expectedResult
      )
    )

    let feature: ResourceDetails = try await self.testInstance(
      context: .random()
    )

    await XCTAssertValue(
      equal: expectedResult
    ) {
      try await feature.details()
    }
  }

  func test_details_providesUpdatedDetails_whenUpdatesSequenceGeneratesValue() async throws {
    let expectedResult: ResourceDetailsDSV = .random()
    var results: Array<ResourceDetailsDSV> = [
      .random(),
      expectedResult,
    ]
    let nextResult: () -> ResourceDetailsDSV = {
      results.removeFirst()
    }
    await features.patch(
      \AccountDatabase.fetchResourceDetailsDSVs,
      with: .returning(
        nextResult()
      )
    )

    let feature: ResourceDetails = try await self.testInstance(
      context: .random()
    )

    await self.updatesSequence.send(Void())

    // wait for detached tasks
    try await Task.sleep(nanoseconds: NSEC_PER_MSEC)

    await XCTAssertValue(
      equal: expectedResult
    ) {
      try await feature.details()
    }
  }

  func test_decryptSecret_fails_whenDecryptionFails() async throws {
    await features.patch(
      \AccountSession.decryptMessage,
      with: alwaysThrow(
        MockIssue.error()
      )
    )
    await features.patch(
      \NetworkClient.resourceSecretRequest,
      with: .respondingWith(
        .init(
          header: .mock(),
          body: .init(data: "encrypted-data")
        )
      )
    )

    let feature: ResourceDetails = try await self.testInstance(
      context: .random()
    )

    await XCTAssertError(
      matches: MockIssue.self
    ) {
      try await feature.secret()
    }
  }

  func test_decryptSecret_fails_whenFetchingSecretFails() async throws {
    await features.patch(
      \NetworkClient.resourceSecretRequest,
      with: .failingWith(
        MockIssue.error()
      )
    )

    let feature: ResourceDetails = try await self.testInstance(
      context: .random()
    )

    await XCTAssertError(
      matches: MockIssue.self
    ) {
      try await feature.secret()
    }
  }

  func test_updates_forwardsUpdatesSequenceElements() async throws {

    let feature: ResourceDetails = try await self.testInstance(
      context: .random()
    )

    Task.detached(priority: .background) {
      try await Task.sleep(nanoseconds: 100 * NSEC_PER_MSEC)
      await self.updatesSequence.send(Void())
      await self.updatesSequence.send(Void())
    }

    await XCTAssertValue(
      equal: 3
    ) {
      await feature
        .detailsSequence()
        .prefix(3)
        .reduce(
          into: []
        ) { result, next in
          result.append(next)
        }
        .count
    }
  }

  func test_decryptSecret_returnsSecret_whenAllOperationsSucceed() async throws {
    let expectedResult: ResourceSecret = .init(
      rawValue: "{\"password\":\"secret\"}",
      values: ["password": "secret"]
    )
    await features.patch(
      \AccountSession.decryptMessage,
      with: always(
        expectedResult.rawValue
      )
    )
    await features.patch(
      \NetworkClient.resourceSecretRequest,
      with: .respondingWith(
        .init(
          header: .mock(),
          body: .init(data: "encrypted-data")
        )
      )
    )

    let feature: ResourceDetails = try await self.testInstance(
      context: .random()
    )

    await XCTAssertValue(
      equal: expectedResult
    ) {
      try await feature.secret()
    }
  }
}
