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
import UIComponents
import XCTest

@testable import Accounts
@testable import PassboltApp

// swift-format-ignore: AlwaysUseLowerCamelCase, NeverUseImplicitlyUnwrappedOptionals
@MainActor
final class HomeFilterControllerTests: MainActorTestCase {

  var networkClient: NetworkClient!

  override func mainActorSetUp() {
    features.usePlaceholder(for: AccountSettings.self)
    networkClient = .placeholder
  }

  override func mainActorTearDown() {
    networkClient = nil
  }

  func test_accountMenuPresentationPublisher_doesNotPublishInitially() {
    features.use(networkClient)

    let controller: HomeFilterController = testController()

    var result: Void?
    controller
      .accountMenuPresentationPublisher()
      .sink { _ in
        result = Void()
      }
      .store(in: cancellables)

    XCTAssertNil(result)
  }

  func test_accountMenuPresentationPublisher_publishesWhenRequested() {
    features
      .patch(
        \AccountSettings.currentAccountProfilePublisher,
        with: always(
          Just(validAccountWithProfile).eraseToAnyPublisher()
        )
      )
    features.use(networkClient)

    let controller: HomeFilterController = testController()

    var result: Void?
    controller
      .accountMenuPresentationPublisher()
      .sink { _ in
        result = Void()
      }
      .store(in: cancellables)

    controller.presentAccountMenu()

    XCTAssertNotNil(result)
  }

  func test_avatarImagePublisher_publishesImageData_fromMediaDownload() {
    features
      .patch(
        \AccountSettings.currentAccountProfilePublisher,
        with: always(
          Just(validAccountWithProfile)
            .eraseToAnyPublisher()
        )
      )
    let data: Data = Data([0x65, 0x66])
    networkClient.mediaDownload.execute = always(
      Just(data)
        .eraseErrorType()
        .eraseToAnyPublisher()
    )
    features.use(networkClient)

    let controller: HomeFilterController = testController()

    var result: Data?
    controller
      .avatarImagePublisher()
      .sink { imageData in
        result = imageData
      }
      .store(in: cancellables)

    XCTAssertEqual(result, data)
  }

  func test_avatarImagePublisher_fails_whenMediaDownloadFails() {
    features
      .patch(
        \AccountSettings.currentAccountProfilePublisher,
        with: always(
          Just(validAccountWithProfile)
            .eraseToAnyPublisher()
        )
      )
    networkClient.mediaDownload.execute = always(
      Fail<Data, Error>(error: MockIssue.error())
        .eraseToAnyPublisher()
    )
    features.use(networkClient)

    let controller: HomeFilterController = testController()

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

  func test_searchTextPublisher_publishesEmptyTextInitially() {
    features.use(networkClient)

    let controller: HomeFilterController = testController()

    var result: String?
    controller
      .searchTextPublisher()
      .sink { text in
        result = text
      }
      .store(in: cancellables)

    XCTAssertTrue(result?.isEmpty ?? false)
  }

  func test_searchTextPublisher_publishesTextUpdates() {
    features.use(networkClient)

    let controller: HomeFilterController = testController()

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

  func test_resourcesFilterPublisher_publishesEmptyFilterInitially() {
    features.use(networkClient)

    let controller: HomeFilterController = testController()

    var result: ResourcesFilter?
    controller
      .resourcesFilterPublisher()
      .sink { filter in
        result = filter
      }
      .store(in: cancellables)

    XCTAssertTrue(result?.isEmpty ?? false)
  }

  func test_resourcesFilterPublisher_publishesUpdatesOnTextUpdates() {
    features.use(networkClient)

    let controller: HomeFilterController = testController()

    var result: ResourcesFilter?
    controller
      .resourcesFilterPublisher()
      .sink { filter in
        result = filter
      }
      .store(in: cancellables)

    controller.updateSearchText("updated")

    XCTAssertEqual(result, ResourcesFilter(text: "updated"))
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
  avatarImageURL: "avatarImagePath",
  biometricsEnabled: false
)

private let validAccountWithProfile: AccountWithProfile = .init(
  account: validAccount,
  profile: validAccountProfile
)
