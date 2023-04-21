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
import CommonModels
import Features
import SessionData
import TestExtensions
import UIComponents
import XCTest

@testable import Accounts
@testable import PassboltApp
@testable import Resources

// swift-format-ignore: AlwaysUseLowerCamelCase, NeverUseImplicitlyUnwrappedOptionals
@MainActor
final class ResourceMenuControllerTests: MainActorTestCase {

  override func mainActorSetUp() {
    features.usePlaceholder(for: OSPasteboard.self)
    features.usePlaceholder(for: OSLinkOpener.self)
    features.usePlaceholder(for: SessionConfigurationLoader.self)
    features.patch(
      \Resources.resourceDetailsPublisher,
      with: always(
        Just(detailsViewResource)
          .eraseErrorType()
          .eraseToAnyPublisher()
      )
    )
    features.patch(
      \Resources.loadResourceSecret,
      with: always(
        Just(resourceSecret)
          .eraseErrorType()
          .eraseToAnyPublisher()
      )
    )
    features.usePlaceholder(
      for: ResourceFavorites.self,
      context: detailsViewResource.id!
    )
  }

  func test_resourceDetailsPublisher_publishes_initially() async throws {

    let controller: ResourceMenuController = try testController(
      context: (
        resourceID: detailsViewResource.id!,
        showShare: { _ in /* NOP */ },
        showEdit: { _ in /* NOP */ },
        showDeleteAlert: { _ in /* NOP */ }
      )
    )
    var result: Resource?

    controller
      .resourceDetailsPublisher()
      .sink(
        receiveCompletion: { _ in
          XCTFail("Unexpected completion")
        },
        receiveValue: { value in
          result = value
        }
      )
      .store(in: cancellables)

    XCTAssertEqual(result?.id?.rawValue, detailsViewResource.id?.rawValue)
  }

  func test_availableActionsPublisher_publishesActionAvailable_initially() async throws {

    let controller: ResourceMenuController = try testController(
      context: (
        resourceID: detailsViewResource.id!,
        showShare: { _ in /* NOP */ },
        showEdit: { _ in /* NOP */ },
        showDeleteAlert: { _ in /* NOP */ }
      )
    )
    var result: Array<ResourceMenuController.Action>!

    controller.availableActionsPublisher()
      .sink { actions in
        result = actions
      }
      .store(in: cancellables)

    XCTAssertEqual(
      result,
      [
        .openURL, .copyURL, .copyUsername, .copyPassword, .copyDescription, .toggleFavorite(false), .share, .edit,
        .delete,
      ]
    )
  }

  func test_performAction_copiesSecretToPasteboard_forCopyPasswordAction() async throws {
    var result: String? = nil
    features.patch(
      \OSPasteboard.put,
      with: {
        result = $0
      }
    )

    let controller: ResourceMenuController = try testController(
      context: (
        resourceID: detailsViewResource.id!,
        showShare: { _ in /* NOP */ },
        showEdit: { _ in /* NOP */ },
        showDeleteAlert: { _ in /* NOP */ }
      )
    )

    // temporary wait for detached tasks
    try await Task.sleep(nanoseconds: 300 * NSEC_PER_MSEC)

    try await controller
      .performAction(.copyPassword)
      .asAsyncValue()

    XCTAssertEqual(result, resourceSecret.value(for: .unknownNamed("password"))?.stringValue)
  }

  func test_performAction_copiesURLToPasteboard_forCopyURLAction() async throws {
    var result: String? = nil
    features.patch(
      \OSPasteboard.put,
      with: {
        result = $0
      }
    )

    let controller: ResourceMenuController = try testController(
      context: (
        resourceID: detailsViewResource.id!,
        showShare: { _ in /* NOP */ },
        showEdit: { _ in /* NOP */ },
        showDeleteAlert: { _ in /* NOP */ }
      )
    )

    controller
      .performAction(.copyURL)
      .sinkDrop()
      .store(in: cancellables)

    XCTAssertEqual(result, detailsViewResource.value(for: .unknownNamed("uri"))?.stringValue)
  }

  func test_performAction_opensURL_forOpenURLAction() async throws {
    var result: URLString? = nil
    features.patch(
      \OSLinkOpener.openURL,
      with: { (url) async throws -> Void in
        result = url
      }
    )

    let controller: ResourceMenuController = try testController(
      context: (
        resourceID: detailsViewResource.id!,
        showShare: { _ in /* NOP */ },
        showEdit: { _ in /* NOP */ },
        showDeleteAlert: { _ in /* NOP */ }
      )
    )

    controller
      .performAction(.openURL)
      .sinkDrop()
      .store(in: cancellables)

    // temporary wait for detached tasks
    try await Task.sleep(nanoseconds: 300 * NSEC_PER_MSEC)

    XCTAssertEqual(result?.rawValue, detailsViewResource.value(for: .unknownNamed("uri"))?.stringValue)
  }

  func test_performAction_fails_forOpenURLAction_whenOpeningFails() async throws {
    features.patch(
      \OSLinkOpener.openURL,
      with: { (_) async throws -> Void in
        throw MockIssue.error()
      }
    )

    let controller: ResourceMenuController = try testController(
      context: (
        resourceID: detailsViewResource.id!,
        showShare: { _ in /* NOP */ },
        showEdit: { _ in /* NOP */ },
        showDeleteAlert: { _ in /* NOP */ }
      )
    )

    var result: Error?
    controller
      .performAction(.openURL)
      .sink(
        receiveCompletion: { completion in
          guard case let .failure(error) = completion
          else { return }
          result = error
        },
        receiveValue: {}
      )
      .store(in: cancellables)

    // temporary wait for detached tasks
    try await Task.sleep(nanoseconds: 300 * NSEC_PER_MSEC)

    XCTAssertError(result, matches: MockIssue.self)
  }

  func test_performAction_copiesUsernameToPasteboard_forCopyUsernameAction() async throws {
    var result: String? = nil
    features.patch(
      \OSPasteboard.put,
      with: {
        result = $0
      }
    )

    let controller: ResourceMenuController = try testController(
      context: (
        resourceID: detailsViewResource.id!,
        showShare: { _ in /* NOP */ },
        showEdit: { _ in /* NOP */ },
        showDeleteAlert: { _ in /* NOP */ }
      )
    )

    controller
      .performAction(.copyUsername)
      .sinkDrop()
      .store(in: cancellables)

    XCTAssertEqual(result, detailsViewResource.value(for: .unknownNamed("username"))?.stringValue)
  }

  func test_performAction_copiesDescriptionToPasteboard_forCopyDescriptionAction_withUnencryptedDescription()
    async throws
  {
    features.patch(
      \Resources.resourceDetailsPublisher,
      with: always(
        Just(detailsViewResourceWithUnencryptedDescription)
          .eraseErrorType()
          .eraseToAnyPublisher()
      )
    )
    var result: String? = nil
    features.patch(
      \OSPasteboard.put,
      with: {
        result = $0
      }
    )

    let controller: ResourceMenuController = try testController(
      context: (
        resourceID: detailsViewResource.id!,
        showShare: { _ in /* NOP */ },
        showEdit: { _ in /* NOP */ },
        showDeleteAlert: { _ in /* NOP */ }
      )
    )

    controller
      .performAction(.copyDescription)
      .sinkDrop()
      .store(in: cancellables)

    XCTAssertEqual(result, detailsViewResourceWithUnencryptedDescription.value(for: .unknownNamed("description"))?.stringValue)
  }

  func test_performAction_copiesDescriptionToPasteboard_forCopyDescriptionAction_withEncryptedDescription() async throws
  {
    features.patch(
      \Resources.resourceDetailsPublisher,
      with: always(
        Just(detailsViewResource)
          .eraseErrorType()
          .eraseToAnyPublisher()
      )
    )

    var result: String? = nil
    features.patch(
      \OSPasteboard.put,
      with: {
        result = $0
      }
    )

    let controller: ResourceMenuController = try testController(
      context: (
        resourceID: detailsViewResource.id!,
        showShare: { _ in /* NOP */ },
        showEdit: { _ in /* NOP */ },
        showDeleteAlert: { _ in /* NOP */ }
      )
    )

    // temporary wait for detached tasks
    try await Task.sleep(nanoseconds: 300 * NSEC_PER_MSEC)

    try await controller
      .performAction(.copyDescription)
      .asAsyncValue()

    XCTAssertEqual(result, "encrypted description")
  }

  func test_performAction_triggersShowDeleteAlert_forDeleteAction() async throws {
    features.patch(
      \Resources.resourceDetailsPublisher,
      with: always(
        Just(detailsViewResource)
          .eraseErrorType()
          .eraseToAnyPublisher()
      )
    )

    var result: Resource.ID?

    let controller: ResourceMenuController = try testController(
      context: (
        resourceID: detailsViewResource.id!,
        showShare: { _ in /* NOP */ },
        showEdit: { _ in /* NOP */ },
        showDeleteAlert: { resourceID in result = resourceID }
      )
    )

    controller
      .performAction(.delete)
      .sinkDrop()
      .store(in: cancellables)

    XCTAssertEqual(result, detailsViewResource.id!)
  }
}

private let detailsViewResource: Resource = {
  var mock: Resource = .init(
    id: .mock_1,
    path: .init(),
    favoriteID: .none,
    type: .mock_default,
    permission: .owner,
    tags: [
      .init(
        id: .mock_1,
        slug: .init(rawValue: "mock_1"),
        shared: false
      )
    ],
    permissions: [
      .user(
        id: .mock_1,
        permission: .owner,
        permissionID: .mock_1
      )
    ],
    modified: .init(rawValue: 0)
  )
  try! mock.set(.string("Mock_1"), for: .unknownNamed("name"))
  try! mock.set(.string("https://passbolt.com"), for: .unknownNamed("uri"))
  try! mock.set(.string("passbolt@passbolt.com"), for: .unknownNamed("username"))
  return mock
}()

private let detailsViewResourceWithUnencryptedDescription: Resource = {
  var mock: Resource = .init(
    id: .mock_1,
    path: .init(),
    favoriteID: .none,
    type: .init(
      id: .mock_1,
      slug: .mock_1,
      name: "mock_1",
      fields: [
        .name,
        .username,
        .uri,
        .password,
        .description,
      ]
    ),
    permission: .owner,
    tags: [
      .init(
        id: .mock_1,
        slug: .init(rawValue: "mock_1"),
        shared: false
      )
    ],
    permissions: [
      .user(
        id: .mock_1,
        permission: .owner,
        permissionID: .mock_1
      )
    ],
    modified: .init(rawValue: 0)
  )
  try! mock.set(.string("Mock_1"), for: .unknownNamed("name"))
  try! mock.set(.string("https://passbolt.com"), for: .unknownNamed("uri"))
  try! mock.set(.string("passbolt@passbolt.com"), for: .unknownNamed("username"))
  try! mock.set(.string("Passbolt"), for: .unknownNamed("description"))
  return mock
}()

private let resourceSecret: ResourceSecret = try! .from(
  decrypted: #"{"password" : "passbolt", "description": "encrypted description"}"#,
  using: .init()
)
