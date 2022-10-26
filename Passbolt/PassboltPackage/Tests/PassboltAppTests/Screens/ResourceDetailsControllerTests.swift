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
    features.usePlaceholder(for: Pasteboard.self)
    features.usePlaceholder(for: SessionConfiguration.self)
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
      \SessionConfiguration.configuration,
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

    let context: Resource.ID = "1"
    let controller: ResourceDetailsController = try await testController(context: context)
    let result: ResourceDetailsController.ResourceDetailsWithConfig? =
      try? await controller.resourceDetailsWithConfigPublisher()
      .asAsyncValue()

    XCTAssertNotNil(result)
    XCTAssertEqual(result?.resourceDetails.id.rawValue, context.rawValue)
  }

  func test_loadResourceDetails_succeeds_withSortedFields_whenAvailable() async throws {
    features.patch(
      \SessionConfiguration.configuration,
      with: always(FeatureFlags.PreviewPassword.enabled)
    )
    var detailsViewResourceWithReorderedFields: ResourceDetailsDSV = detailsViewResource
    detailsViewResourceWithReorderedFields.fields.reverse()
    features.patch(
      \Resources.resourceDetailsPublisher,
      with: always(
        Just(detailsViewResourceWithReorderedFields)
          .eraseErrorType()
          .eraseToAnyPublisher()
      )
    )

    let context: Resource.ID = "1"
    let controller: ResourceDetailsController = try await testController(context: context)

    let expectedOrderedFields: [ResourceFieldName] = [
      .uri,
      .username,
      .password,
      .description,
    ]

    let result: ResourceDetailsController.ResourceDetailsWithConfig? =
      try? await controller.resourceDetailsWithConfigPublisher()
      .asAsyncValue()

    XCTAssertNotNil(result)
    XCTAssertEqual(result?.resourceDetails.id.rawValue, context.rawValue)
    XCTAssertEqual(result?.resourceDetails.fields.map(\.name), expectedOrderedFields)
  }

  func test_loadResourceDetails_fails_whenErrorOnFetch() async throws {
    features.patch(
      \SessionConfiguration.configuration,
      with: always(FeatureFlags.PreviewPassword.enabled)
    )
    features.patch(
      \Resources.resourceDetailsPublisher,
      with: always(
        Fail(error: MockIssue.error())
          .eraseToAnyPublisher()
      )
    )

    let context: Resource.ID = "1"
    let controller: ResourceDetailsController = try await testController(context: context)
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
      \SessionConfiguration.configuration,
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

    let context: Resource.ID = "1"
    let controller: ResourceDetailsController = try await testController(context: context)
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
      \SessionConfiguration.configuration,
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

    let context: Resource.ID = "1"
    let controller: ResourceDetailsController = try await testController(context: context)
    var result: Error?
    do {
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
      \SessionConfiguration.configuration,
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

    let context: Resource.ID = "1"
    let controller: ResourceDetailsController = try await testController(context: context)

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
      \SessionConfiguration.configuration,
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

    let context: Resource.ID = "1"
    let controller: ResourceDetailsController = try await testController(context: context)
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
      \SessionConfiguration.configuration,
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
      \Pasteboard.put,
      with: {
        pasteboardContent = $0
      }
    )

    let context: Resource.ID = "1"
    let controller: ResourceDetailsController = try await testController(context: context)

    // temporary wait for detached tasks
    try await Task.sleep(nanoseconds: 300 * NSEC_PER_MSEC)

    try await controller
      .copyFieldValue(.username)
      .asAsyncValue()

    XCTAssertNotNil(pasteboardContent)
    XCTAssertEqual(pasteboardContent, detailsViewResource.username)
  }

  func test_copyFieldDescription_succeeds() async throws {
    features.patch(
      \SessionConfiguration.configuration,
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
      \Pasteboard.put,
      with: {
        pasteboardContent = $0
      }
    )

    let context: Resource.ID = "1"
    let controller: ResourceDetailsController = try await testController(context: context)

    // temporary wait for detached tasks
    try await Task.sleep(nanoseconds: 300 * NSEC_PER_MSEC)

    try await controller
      .copyFieldValue(.description)
      .asAsyncValue()

    XCTAssertNotNil(pasteboardContent)
    XCTAssertEqual(pasteboardContent, detailsViewResource.description)
  }

  func test_copyFieldEncryptedDescription_succeeds() async throws {
    features.patch(
      \SessionConfiguration.configuration,
      with: always(FeatureFlags.PreviewPassword.enabled)
    )
    features.patch(
      \Resources.resourceDetailsPublisher,
      with: always(
        Just(encryptedDescriptionResourceDetails)
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
      \Pasteboard.put,
      with: {
        pasteboardContent = $0
      }
    )

    let context: Resource.ID = "1"
    let controller: ResourceDetailsController = try await testController(context: context)

    // temporary wait for detached tasks
    try await Task.sleep(nanoseconds: 300 * NSEC_PER_MSEC)

    try await controller
      .copyFieldValue(.description)
      .asAsyncValue()

    XCTAssertNotNil(pasteboardContent)
    XCTAssertEqual(pasteboardContent, resourceSecret.description)
  }

  func test_copyFieldURI_succeeds() async throws {
    features.patch(
      \SessionConfiguration.configuration,
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
      \Pasteboard.put,
      with: {
        pasteboardContent = $0
      }
    )

    let context: Resource.ID = "1"
    let controller: ResourceDetailsController = try await testController(context: context)

    // temporary wait for detached tasks
    try await Task.sleep(nanoseconds: 300 * NSEC_PER_MSEC)

    try await controller
      .copyFieldValue(.uri)
      .asAsyncValue()

    XCTAssertNotNil(pasteboardContent)
    XCTAssertEqual(pasteboardContent, detailsViewResource.url)
  }

  func test_copyFieldPassword_succeeds() async throws {
    features.patch(
      \SessionConfiguration.configuration,
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
      \Pasteboard.put,
      with: {
        pasteboardContent = $0
      }
    )

    let context: Resource.ID = "1"
    let controller: ResourceDetailsController = try await testController(context: context)

    // temporary wait for detached tasks
    try await Task.sleep(nanoseconds: 300 * NSEC_PER_MSEC)

    try await controller
      .copyFieldValue(.password)
      .asAsyncValue()

    XCTAssertNotNil(pasteboardContent)
    XCTAssertEqual(pasteboardContent, resourceSecret.password)
  }

  func test_resourceDeleteAlertPresentationPublisher_publishesResourceID_whenPresentDeleteResourceAlertCalled()
    async throws
  {
    features.patch(
      \SessionConfiguration.configuration,
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

    let context: Resource.ID = "1"
    let controller: ResourceDetailsController = try await testController(context: context)
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

private let detailsViewResource: ResourceDetailsDSV = .init(
  id: .init(rawValue: "1"),
  permissionType: .owner,
  name: "Passphrase",
  url: "https://passbolt.com",
  username: "passbolt@passbolt.com",
  description: "Passbolt",
  fields: [
    .init(name: .username, valueType: .string, required: true, encrypted: false, maxLength: nil),
    .init(name: .password, valueType: .string, required: true, encrypted: true, maxLength: nil),
    .init(name: .uri, valueType: .string, required: true, encrypted: false, maxLength: nil),
    .init(name: .description, valueType: .string, required: true, encrypted: false, maxLength: nil),
  ],
  favoriteID: .none,
  location: .init(),
  permissions: [],
  tags: []
)

private let encryptedDescriptionResourceDetails: ResourceDetailsDSV = .init(
  id: .init(rawValue: "1"),
  permissionType: .owner,
  name: "Passphrase",
  url: "https://passbolt.com",
  username: "passbolt@passbolt.com",
  description: nil,
  fields: [
    .init(name: .username, valueType: .string, required: true, encrypted: false, maxLength: nil),
    .init(name: .password, valueType: .string, required: true, encrypted: true, maxLength: nil),
    .init(name: .uri, valueType: .string, required: true, encrypted: false, maxLength: nil),
    .init(name: .description, valueType: .string, required: true, encrypted: true, maxLength: nil),
  ],
  favoriteID: .none,
  location: .init(),
  permissions: [],
  tags: []
)

private let resourceSecret: ResourceSecret = try! .from(
  decrypted: #"{"password": "passbolt", "description": "encrypted"}"#,
  using: .init()
)
