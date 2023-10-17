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
import FeatureScopes
import Features
import TestExtensions
import UIComponents
import XCTest

@testable import Accounts
@testable import PassboltApp

// swift-format-ignore: AlwaysUseLowerCamelCase, NeverUseImplicitlyUnwrappedOptionals
@available(iOS 16.0.0, *)
@MainActor
final class HomeSearchControllerTests: MainActorTestCase {

  var detailsUpdates: Updates!

  override func mainActorSetUp() {
    features
      .set(
        SessionScope.self,
        context: .init(
          account: .mock_ada,
          configuration: .mock_1
        )
      )
    features.patch(
      \Session.currentAccount,
      with: always(Account.mock_ada)
    )
    features.usePlaceholder(for: HomePresentation.self)
    detailsUpdates = .init()
    features.patch(
      \AccountDetails.updates,
      with: detailsUpdates.asAnyUpdatable()
    )
    features.patch(
      \AccountDetails.profile,
      with: always(AccountWithProfile.mock_ada)
    )
    features.patch(
      \AccountDetails.avatarImage,
      with: always(.init())
    )
  }

  override func mainActorTearDown() {
    detailsUpdates = .none
  }

  func test_presentAccountMenu_navigatesToAccountMenu() async throws {
    let result: UnsafeSendable<Void?> = .init(.none)
    self.features
      .patch(
        \NavigationToAccountMenu.mockPerform,
        with: { _, _ async throws -> Void in
          result.value = Void()
        }
      )

    let controller: HomeSearchController = try await testController(
      context: { _ in /* NOP */ }
    )

    try await controller.presentAccountMenu()

    XCTAssertNotNil(result.value)
  }

  func test_homePresentationMenuPresentationPublisher_doesNotPublish_initially() async throws {
    features
      .patch(
        \HomePresentation.currentPresentationModePublisher,
        with: always(
          Just(HomePresentationMode.plainResourcesList)
            .eraseToAnyPublisher()
        )
      )

    let controller: HomeSearchController = try await testController(
      context: { _ in /* NOP */ }
    )

    var result: Void?
    controller
      .homePresentationMenuPresentationPublisher()
      .sink { _ in
        result = Void()
      }
      .store(in: cancellables)

    XCTAssertNil(result)
  }

  func test_homePresentationMenuPresentationPublisher_publishes_whenRequested() async throws {
    features
      .patch(
        \HomePresentation.currentPresentationModePublisher,
        with: always(
          Just(HomePresentationMode.plainResourcesList)
            .eraseToAnyPublisher()
        )
      )

    let controller: HomeSearchController = try await testController(
      context: { _ in /* NOP */ }
    )

    var result: Void?
    controller
      .homePresentationMenuPresentationPublisher()
      .sink { _ in
        result = Void()
      }
      .store(in: cancellables)

    controller.presentHomePresentationMenu()

    XCTAssertNotNil(result)
  }

  func test_homePresentationMenuPresentationPublisher_publishesCurrentPresentationMode_whenRequested() async throws {
    await features
      .patch(
        \HomePresentation.currentPresentationModePublisher,
        with: always(
          Just(HomePresentationMode.plainResourcesList)
            .eraseToAnyPublisher()
        )
      )

    let controller: HomeSearchController = try await testController(
      context: { _ in /* NOP */ }
    )

    var result: HomePresentationMode?
    controller
      .homePresentationMenuPresentationPublisher()
      .sink { mode in
        result = mode
      }
      .store(in: cancellables)

    controller.presentHomePresentationMenu()

    XCTAssertEqual(result, .plainResourcesList)
  }

  func test_avatarImagePublisher_publishesImageData_fromMediaDownload() async throws {
    let data: Data = .init([65, 66])
    features.patch(
      \AccountDetails.avatarImage,
      with: always(data)
    )
    let controller: HomeSearchController = try await testController(
      context: { _ in /* NOP */ }
    )

    var result: Data? =
      try? await controller
      .avatarImagePublisher()
      .asAsyncValue()

    XCTAssertEqual(result, data)
  }

  func test_avatarImagePublisher_fails_whenMediaDownloadFails() async throws {
    features.patch(
      \AccountDetails.avatarImage,
      with: alwaysThrow(MockIssue.error())
    )

    let controller: HomeSearchController = try await testController(
      context: { _ in /* NOP */ }
    )

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
    let controller: HomeSearchController = try await testController(
      context: { _ in /* NOP */ }
    )

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
    let controller: HomeSearchController = try await testController(
      context: { _ in /* NOP */ }
    )

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

  func test_context_searchTextUpdate_isCalledWithSearchText_initially() async throws {
    var result: String?
    let _: HomeSearchController = try await testController(
      context: { text in result = text }
    )

    XCTAssertEqual(result, "")
  }

  func test_context_searchTextUpdate_isCalledWithSearchText_whenSearchTextIsUpdated() async throws {
    var result: String?
    let controller: HomeSearchController = try await testController(
      context: { text in result = text }
    )

    controller.updateSearchText("updated")

    XCTAssertEqual(result, "updated")
  }
}
