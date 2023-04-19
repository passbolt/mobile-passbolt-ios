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
final class ResourceDetailsControllerTests: MainActorTestCase {

  var updates: UpdatesSequenceSource!

  override func mainActorSetUp() {
    features
      .set(
        SessionScope.self,
        context: .init(
          account: .mock_ada,
          configuration: .mock_1
        )
      )
    features.usePlaceholder(for: OSPasteboard.self)
    features.usePlaceholder(for: SessionConfigurationLoader.self)
    updates = .init()
    features.patch(
      \SessionData.updatesSequence,
      with: updates.updatesSequence
    )
    features.patch(
      \Resources.resourceDetailsPublisher,
      with: always(
        Just(detailsViewResource)
          .eraseErrorType()
          .eraseToAnyPublisher()
      )
    )
  }

  override func mainActorTearDown() {
    updates = nil
  }

  func test_loadResourceDetails_succeeds_whenAvailable() async throws {
    features.patch(
      \SessionConfigurationLoader.configuration,
      with: always(FeatureFlags.PreviewPassword.enabled)
    )
    features.patch(
      \Resources.resourceDetailsPublisher,
      with: always(
        Just(detailsViewResource)
          .eraseErrorType()
          .eraseToAnyPublisher()
      )
    )

    let context: Resource.ID = detailsViewResource.id!
    let controller: ResourceDetailsController = try testController(context: context)
    let result: ResourceDetailsController.ResourceWithConfig? =
      try? await controller.resourceDetailsWithConfigPublisher()
      .asAsyncValue()

    XCTAssertNotNil(result)
    XCTAssertEqual(result?.resource.id, context)
  }

  func test_loadResourceDetails_succeeds_withSortedFields_whenAvailable() async throws {
    features.patch(
      \SessionConfigurationLoader.configuration,
      with: always(FeatureFlags.PreviewPassword.enabled)
    )
    var detailsViewResourceWithReorderedFields: Resource = detailsViewResource
    detailsViewResourceWithReorderedFields.type = .init(
      id: detailsViewResource.type.id,
      slug: detailsViewResource.type.slug,
      name: detailsViewResource.type._name,
      fields: detailsViewResource.type.fields.shuffled().asOrderedSet()
    )
    features.patch(
      \Resources.resourceDetailsPublisher,
      with: always(
        Just(detailsViewResourceWithReorderedFields)
          .eraseErrorType()
          .eraseToAnyPublisher()
      )
    )

    let context: Resource.ID = detailsViewResource.id!
    let controller: ResourceDetailsController = try testController(context: context)

    let expectedOrderedFields: OrderedSet<ResourceField> = [
      .name,
      .uri,
      .username,
      .password,
      .descriptionEncrypted,
    ]

    let result: ResourceDetailsController.ResourceWithConfig? =
      try? await controller.resourceDetailsWithConfigPublisher()
      .asAsyncValue()

    XCTAssertNotNil(result)
    XCTAssertEqual(result?.resource.id?.rawValue, context.rawValue)
    XCTAssertEqual(result?.resource.fields, expectedOrderedFields)
  }

  func test_loadResourceDetails_fails_whenErrorOnFetch() async throws {
    features.patch(
      \SessionConfigurationLoader.configuration,
      with: always(FeatureFlags.PreviewPassword.enabled)
    )
    features.patch(
      \Resources.resourceDetailsPublisher,
      with: always(
        Fail(error: MockIssue.error())
          .eraseToAnyPublisher()
      )
    )

    let context: Resource.ID = detailsViewResource.id!
    let controller: ResourceDetailsController = try testController(context: context)
    var result: Error?
    do {
      _ = try await controller.resourceDetailsWithConfigPublisher()
        .asAsyncValue()
      XCTFail()
    }
    catch {
      result = error
    }

    XCTAssertNotNil(result)
  }

  func test_toggleDecrypt_publishes_whenResourceFetch_succeeds() async throws {
    features.patch(
      \SessionConfigurationLoader.configuration,
      with: always(FeatureFlags.PreviewPassword.enabled)
    )
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

    let context: Resource.ID = detailsViewResource.id!
    let controller: ResourceDetailsController = try testController(context: context)
    let result: String? =
      try? await controller
      .toggleDecrypt(
        .password
      )
      .asAsyncValue()

    XCTAssertNotNil(result)
  }

  func test_toggleDecrypt_publishesError_whenResourceFetch_fails() async throws {
    features.patch(
      \SessionConfigurationLoader.configuration,
      with: always(FeatureFlags.PreviewPassword.enabled)
    )
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
        Fail(error: MockIssue.error())
          .eraseToAnyPublisher()
      )
    )

    let context: Resource.ID = detailsViewResource.id!
    let controller: ResourceDetailsController = try testController(context: context)
    var result: Error?
    do {
      _ =
        try await controller
        .toggleDecrypt(.password)
        .asAsyncValue()
      XCTFail()
    }
    catch {
      result = error
    }

    XCTAssertNotNil(result)
  }

  func test_toggleDecrypt_publishesNil_whenTryingToDecryptAlreadyDecrypted() async throws {
    features.patch(
      \SessionConfigurationLoader.configuration,
      with: always(FeatureFlags.PreviewPassword.enabled)
    )
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

    let context: Resource.ID = detailsViewResource.id!
    let controller: ResourceDetailsController = try testController(context: context)

    _ =
      try await controller
      .toggleDecrypt(
        .password
      )
      .asAsyncValue()

    let result: String? =
      try? await controller
      .toggleDecrypt(.password)
      .asAsyncValue()

    XCTAssertNil(result)
  }

  func test_resourceMenuPresentationPublisher_publishesResourceID_whenPresentResourceMenuCalled() async throws {
    features.patch(
      \SessionConfigurationLoader.configuration,
      with: always(FeatureFlags.PreviewPassword.enabled)
    )
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

    let context: Resource.ID = detailsViewResource.id!
    let controller: ResourceDetailsController = try testController(context: context)
    var result: Resource.ID!

    controller.resourceMenuPresentationPublisher()
      .sink { resourceID in
        result = resourceID
      }
      .store(in: cancellables)

    controller.presentResourceMenu()

    XCTAssertEqual(result, context)
  }

  func test_copyFieldUsername_succeeds() async throws {
    features.patch(
      \SessionConfigurationLoader.configuration,
      with: always(FeatureFlags.PreviewPassword.enabled)
    )
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
    var pasteboardContent: String? = nil
    features.patch(
      \OSPasteboard.put,
      with: {
        pasteboardContent = $0
      }
    )

    let context: Resource.ID = detailsViewResource.id!
    let controller: ResourceDetailsController = try testController(context: context)

    // temporary wait for detached tasks
    try await Task.sleep(nanoseconds: 300 * NSEC_PER_MSEC)

    try await controller
      .copyFieldValue(.username)
      .asAsyncValue()

    XCTAssertNotNil(pasteboardContent)
    XCTAssertEqual(pasteboardContent, detailsViewResource.value(for: .unknownNamed("username"))?.stringValue)
  }

  func test_copyFieldDescription_succeeds() async throws {
    features.patch(
      \SessionConfigurationLoader.configuration,
      with: always(FeatureFlags.PreviewPassword.enabled)
    )
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
    var pasteboardContent: String? = nil
    features.patch(
      \OSPasteboard.put,
      with: {
        pasteboardContent = $0
      }
    )

    let context: Resource.ID = detailsViewResource.id!
    let controller: ResourceDetailsController = try testController(context: context)

    // temporary wait for detached tasks
    try await Task.sleep(nanoseconds: 300 * NSEC_PER_MSEC)

    try await controller
      .copyFieldValue(.description)
      .asAsyncValue()

    XCTAssertNotNil(pasteboardContent)
    XCTAssertEqual(pasteboardContent, resourceSecret.value(for: .unknownNamed("description"))?.stringValue)
  }

  func test_copyFieldEncryptedDescription_succeeds() async throws {
    features.patch(
      \SessionConfigurationLoader.configuration,
      with: always(FeatureFlags.PreviewPassword.enabled)
    )
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
    var pasteboardContent: String? = nil
    features.patch(
      \OSPasteboard.put,
      with: {
        pasteboardContent = $0
      }
    )

    let context: Resource.ID = detailsViewResource.id!
    let controller: ResourceDetailsController = try testController(context: context)

    // temporary wait for detached tasks
    try await Task.sleep(nanoseconds: 300 * NSEC_PER_MSEC)

    try await controller
      .copyFieldValue(.description)
      .asAsyncValue()

    XCTAssertNotNil(pasteboardContent)
    XCTAssertEqual(pasteboardContent, resourceSecret.value(for: .unknownNamed("description"))?.stringValue)
  }

  func test_copyFieldURI_succeeds() async throws {
    features.patch(
      \SessionConfigurationLoader.configuration,
      with: always(FeatureFlags.PreviewPassword.enabled)
    )
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
    var pasteboardContent: String? = nil
    features.patch(
      \OSPasteboard.put,
      with: {
        pasteboardContent = $0
      }
    )

    let context: Resource.ID = detailsViewResource.id!
    let controller: ResourceDetailsController = try testController(context: context)

    // temporary wait for detached tasks
    try await Task.sleep(nanoseconds: 300 * NSEC_PER_MSEC)

    try await controller
      .copyFieldValue(.uri)
      .asAsyncValue()

    XCTAssertNotNil(pasteboardContent)
    XCTAssertEqual(pasteboardContent, detailsViewResource.value(for: .unknownNamed("uri"))?.stringValue)
  }

  func test_copyFieldPassword_succeeds() async throws {
    features.patch(
      \SessionConfigurationLoader.configuration,
      with: always(FeatureFlags.PreviewPassword.enabled)
    )
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
    var pasteboardContent: String? = nil
    features.patch(
      \OSPasteboard.put,
      with: {
        pasteboardContent = $0
      }
    )

    let context: Resource.ID = detailsViewResource.id!
    let controller: ResourceDetailsController = try testController(context: context)

    // temporary wait for detached tasks
    try await Task.sleep(nanoseconds: 300 * NSEC_PER_MSEC)

    try await controller
      .copyFieldValue(.password)
      .asAsyncValue()

    XCTAssertNotNil(pasteboardContent)
    XCTAssertEqual(pasteboardContent, resourceSecret.value(for: .unknownNamed("password"))?.stringValue)
  }

  func test_resourceDeleteAlertPresentationPublisher_publishesResourceID_whenPresentDeleteResourceAlertCalled()
    async throws
  {
    features.patch(
      \SessionConfigurationLoader.configuration,
      with: always(FeatureFlags.PreviewPassword.enabled)
    )
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

    let context: Resource.ID = detailsViewResource.id!
    let controller: ResourceDetailsController = try testController(context: context)
    var result: Resource.ID?

    controller.resourceDeleteAlertPresentationPublisher()
      .sink { resourceID in
        result = resourceID
      }
      .store(in: cancellables)

    controller.presentDeleteResourceAlert(context)

    XCTAssertEqual(result, context)
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

private let resourceSecret: ResourceSecret = try! .from(
  decrypted: #"{"password": "passbolt", "description": "encrypted"}"#,
  using: .init()
)
