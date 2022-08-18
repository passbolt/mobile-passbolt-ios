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
import UIComponents
import XCTest

@testable import Accounts
@testable import PassboltExtension

// swift-format-ignore: AlwaysUseLowerCamelCase, NeverUseImplicitlyUnwrappedOptionals
@MainActor
final class ResourcesFilterControllerTests: MainActorTestCase {

  var detailsUpdates: UpdatesSequenceSource!

  override func mainActorSetUp() {
    features.patch(
      \Session.currentAccount,
      with: always(validAccount)
    )
    detailsUpdates = .init()
    features.patch(
      \AccountDetails.updates,
      context: validAccount,
      with: detailsUpdates.updatesSequence
    )
    features.patch(
      \AccountDetails.profile,
      context: validAccount,
      with: always(validAccountWithProfile)
    )
    features.patch(
      \AccountDetails.avatarImage,
      context: validAccount,
      with: always(.init())
    )
  }

  override func mainActorTearDown() {
    detailsUpdates = .none
  }

  func test_switchAccount_closesSession() async throws {
    var result: Void?
    let uncheckedSendableResult: UncheckedSendable<Void?> = .init(
      get: { result },
      set: { result = $0 }
    )
    features.patch(
      \Session.close,
      with: { _ in
        uncheckedSendableResult.variable = Void()
      }
    )

    let controller: ResourcesFilterController = try await testController()

    controller.switchAccount()

    // wait for detached tasks - temporary solution
    try await Task.sleep(nanoseconds: 300 * NSEC_PER_MSEC)

    XCTAssertNotNil(result)
  }

  func test_avatarImagePublisher_publishesImageData_fromMediaDownload() async throws {
    let expectedResult: Data = .init([0x65, 0x66])
    features.patch(
      \AccountDetails.avatarImage,
      context: validAccount,
      with: always(expectedResult)
    )

    let controller: ResourcesFilterController = try await testController()

    let result: Data? =
      try? await controller
      .avatarImagePublisher()
      .asAsyncValue()

    XCTAssertEqual(result, expectedResult)
  }

  func test_avatarImagePublisher_fails_whenMediaDownloadFails() async throws {
    features.patch(
      \AccountDetails.avatarImage,
      context: validAccount,
      with: alwaysThrow(MockIssue.error())
    )

    let controller: ResourcesFilterController = try await testController()

    var result: Data?
    controller
      .avatarImagePublisher()
      .sink(
        receiveValue: { data in
          result = data
        }
      )
      .store(in: cancellables)

    XCTAssertNil(result)
  }

  func test_searchTextPublisher_publishesEmptyTextInitially() async throws {
    let controller: ResourcesFilterController = try await testController()

    var result: String?
    controller
      .searchTextPublisher()
      .sink { text in
        result = text
      }
      .store(in: cancellables)

    XCTAssertTrue(result?.isEmpty ?? false)
  }

  func test_searchTextPublisher_publishesTextUpdates() async throws {
    let controller: ResourcesFilterController = try await testController()

    var result: String?
    controller
      .searchTextPublisher()
      .sink { text in
        result = text
      }
      .store(in: cancellables)

    controller.updateSearchText("updated")

    XCTAssertEqual(result, "updated")
  }

  func test_resourcesFilterPublisher_publishesEmptyFilterInitially() async throws {
    let controller: ResourcesFilterController = try await testController()

    var result: ResourcesFilter?
    controller
      .resourcesFilterPublisher()
      .sink { filter in
        result = filter
      }
      .store(in: cancellables)

    XCTAssertTrue(result?.text.isEmpty ?? false)
  }

  func test_resourcesFilterPublisher_publishesUpdatesOnTextUpdates() async throws {
    let controller: ResourcesFilterController = try await testController()

    var result: ResourcesFilter?
    controller
      .resourcesFilterPublisher()
      .sink { filter in
        result = filter
      }
      .store(in: cancellables)

    controller.updateSearchText("updated")

    XCTAssertEqual(result, ResourcesFilter(sorting: .nameAlphabetically, text: "updated"))
  }
}

private let validAccount: Account = .init(
  localID: .init(rawValue: UUID.test.uuidString),
  domain: "passbolt.com",
  userID: .init(rawValue: UUID.test.uuidString),
  fingerprint: "fingerprint"
)

private let validAccountProfile: AccountProfile = .init(
  accountID: .init(rawValue: UUID.test.uuidString),
  label: "firstName lastName",
  username: "username",
  firstName: "firstName",
  lastName: "lastName",
  avatarImageURL: "avatarImagePath"
)

private let validAccountWithProfile: AccountWithProfile = .init(
  account: validAccount,
  profile: validAccountProfile
)
