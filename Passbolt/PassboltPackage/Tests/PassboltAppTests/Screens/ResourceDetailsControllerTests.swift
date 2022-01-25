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
import TestExtensions
import UIComponents
import XCTest

@testable import Accounts
@testable import PassboltApp
@testable import Resources

// swift-format-ignore: AlwaysUseLowerCamelCase, NeverUseImplicitlyUnwrappedOptionals
final class ResourceDetailsControllerTests: TestCase {

  var featureConfig: FeatureConfig!
  var resources: Resources!
  var pasteboard: Pasteboard!

  override func setUp() {
    super.setUp()

    featureConfig = .placeholder
    resources = .placeholder
    pasteboard = .placeholder
  }

  override func tearDown() {
    super.tearDown()

    resources = nil
  }

  func test_loadResourceDetails_succeeds_whenAvailable() {
    featureConfig.config = { _ in FeatureConfig.PreviewPassword.enabled }
    resources.resourceDetailsPublisher = always(
      Just(detailsViewResource)
        .setFailureType(to: TheErrorLegacy.self)
        .eraseToAnyPublisher()
    )
    features.use(featureConfig)
    features.use(resources)
    features.use(pasteboard)

    let context: Resource.ID = "1"
    let controller: ResourceDetailsController = testInstance(context: context)
    var result: ResourceDetailsController.ResourceDetailsWithConfig!

    controller.resourceDetailsWithConfigPublisher()
      .sink(
        receiveCompletion: { completion in
          guard case .finished = completion
          else {
            XCTFail("Unexpected failure")
            return
          }
        },
        receiveValue: { resourceDetailsConfig in
          result = resourceDetailsConfig
        }
      )
      .store(in: cancellables)

    XCTAssertNotNil(result)
    XCTAssertEqual(result.resourceDetails.id.rawValue, context.rawValue)
  }

  func test_loadResourceDetails_succeeds_withSortedFields_whenAvailable() {
    featureConfig.config = { _ in FeatureConfig.PreviewPassword.enabled }
    resources.resourceDetailsPublisher = { _ in
      var detailsViewResourceWithReorderedFields: DetailsViewResource = detailsViewResource
      detailsViewResourceWithReorderedFields.properties.reverse()
      return Just(detailsViewResourceWithReorderedFields)
        .setFailureType(to: TheErrorLegacy.self)
        .eraseToAnyPublisher()
    }
    features.use(featureConfig)
    features.use(resources)
    features.use(pasteboard)

    let context: Resource.ID = "1"
    let controller: ResourceDetailsController = testInstance(context: context)

    let expectedOrderedFields: [ResourceField] = [
      .uri,
      .username,
      .password,
      .description,
    ]

    var result: ResourceDetailsController.ResourceDetailsWithConfig!

    controller.resourceDetailsWithConfigPublisher()
      .sink(
        receiveCompletion: { completion in
          guard case .finished = completion
          else {
            XCTFail("Unexpected failure")
            return
          }
        },
        receiveValue: { resourceDetailsConfig in
          result = resourceDetailsConfig
        }
      )
      .store(in: cancellables)

    XCTAssertNotNil(result)
    XCTAssertEqual(result.resourceDetails.id.rawValue, context.rawValue)
    XCTAssertEqual(result.resourceDetails.properties.map(\.field), expectedOrderedFields)
  }

  func test_loadResourceDetails_fails_whenErrorOnFetch() {
    resources.resourceDetailsPublisher = always(
      Fail(error: .testError()).eraseToAnyPublisher()
    )
    features.use(featureConfig)
    features.use(resources)
    features.use(pasteboard)

    let context: Resource.ID = "1"
    let controller: ResourceDetailsController = testInstance(context: context)
    var result: TheErrorLegacy!

    controller.resourceDetailsWithConfigPublisher()
      .sink(
        receiveCompletion: { completion in
          guard case let .failure(error) = completion
          else {
            XCTFail("Unexpected completion")
            return
          }
          result = error
        },
        receiveValue: { _ in
          XCTFail("Unexpected value")
        }
      )
      .store(in: cancellables)

    XCTAssertNotNil(result)
  }

  func test_toggleDecrypt_publishes_whenResourceFetch_succeeds() {
    resources.resourceDetailsPublisher = always(
      Empty().eraseToAnyPublisher()
    )
    resources.loadResourceSecret = always(
      Just(resourceSecret).setFailureType(to: TheErrorLegacy.self).eraseToAnyPublisher()
    )
    features.use(featureConfig)
    features.use(resources)
    features.use(pasteboard)

    let context: Resource.ID = "1"
    let controller: ResourceDetailsController = testInstance(context: context)
    var result: String!

    controller
      .toggleDecrypt(
        .password
      )
      .sink { completion in
        guard case .finished = completion
        else {
          XCTFail("Unexpected error")
          return
        }
      } receiveValue: { decrypted in
        result = decrypted
      }
      .store(in: cancellables)

    XCTAssertNotNil(result)
  }

  func test_toggleDecrypt_publishesError_whenResourceFetch_fails() {
    resources.resourceDetailsPublisher = always(
      Empty().eraseToAnyPublisher()
    )
    resources.loadResourceSecret = always(
      Fail(error: .testError()).eraseToAnyPublisher()
    )
    features.use(featureConfig)
    features.use(resources)
    features.use(pasteboard)

    let context: Resource.ID = "1"
    let controller: ResourceDetailsController = testInstance(context: context)
    var result: TheErrorLegacy!

    controller
      .toggleDecrypt(.password)
      .sink(
        receiveCompletion: { completion in
          guard case let .failure(error) = completion
          else {
            XCTFail("Unexpected completion")
            return
          }
          result = error
        },
        receiveValue: { _ in
          XCTFail("Unexpected value")
        }
      )
      .store(in: cancellables)

    XCTAssertNotNil(result)
  }

  func test_toggleDecrypt_publishesNil_whenTryingToDecryptAlreadyDecrypted() {
    resources.resourceDetailsPublisher = always(
      Empty().eraseToAnyPublisher()
    )
    resources.loadResourceSecret = always(
      Just(resourceSecret).setFailureType(to: TheErrorLegacy.self).eraseToAnyPublisher()
    )
    features.use(featureConfig)
    features.use(resources)
    features.use(pasteboard)

    let context: Resource.ID = "1"
    let controller: ResourceDetailsController = testInstance(context: context)
    var result: String!

    controller
      .toggleDecrypt(
        .password
      )
      .sinkDrop()
      .store(in: cancellables)

    controller
      .toggleDecrypt(.password)
      .sink { completion in
        guard case .finished = completion
        else {
          XCTFail("Unexpected error")
          return
        }
      } receiveValue: { decrypted in
        result = decrypted
      }
      .store(in: cancellables)

    XCTAssertNil(result)
  }

  func test_resourceMenuPresentationPublisher_publishesResourceID_whenPresentResourceMenuCalled() {
    resources.resourceDetailsPublisher = always(
      Empty().eraseToAnyPublisher()
    )
    resources.loadResourceSecret = always(
      Empty().eraseToAnyPublisher()
    )
    features.use(featureConfig)
    features.use(resources)
    features.use(pasteboard)

    let context: Resource.ID = "1"
    let controller: ResourceDetailsController = testInstance(context: context)
    var result: Resource.ID!

    controller.resourceMenuPresentationPublisher()
      .sink { resourceID in
        result = resourceID
      }
      .store(in: cancellables)

    controller.presentResourceMenu()

    XCTAssertEqual(result, context)
  }

  func test_copyFieldUsername_succeeds() {
    featureConfig.config = { _ in FeatureConfig.PreviewPassword.enabled }
    resources.resourceDetailsPublisher = always(
      Just(detailsViewResource)
        .setFailureType(to: TheErrorLegacy.self)
        .eraseToAnyPublisher()
    )
    features.use(featureConfig)
    features.use(resources)

    var pasteboardContent: String? = nil

    pasteboard.put = { string in
      pasteboardContent = string
    }

    features.use(pasteboard)

    let context: Resource.ID = "1"
    let controller: ResourceDetailsController = testInstance(context: context)

    controller
      .copyFieldValue(.username)
      .sinkDrop()
      .store(in: cancellables)

    XCTAssertNotNil(pasteboardContent)
    XCTAssertEqual(pasteboardContent, detailsViewResource.username)
  }

  func test_copyFieldDescription_succeeds() {
    featureConfig.config = { _ in FeatureConfig.PreviewPassword.enabled }
    resources.resourceDetailsPublisher = always(
      Just(detailsViewResource)
        .setFailureType(to: TheErrorLegacy.self)
        .eraseToAnyPublisher()
    )
    features.use(featureConfig)
    features.use(resources)

    var pasteboardContent: String? = nil

    pasteboard.put = { string in
      pasteboardContent = string
    }

    features.use(pasteboard)

    let context: Resource.ID = "1"
    let controller: ResourceDetailsController = testInstance(context: context)

    controller
      .copyFieldValue(.description)
      .sinkDrop()
      .store(in: cancellables)

    XCTAssertNotNil(pasteboardContent)
    XCTAssertEqual(pasteboardContent, detailsViewResource.description)
  }

  func test_copyFieldEncryptedDescription_succeeds() {
    featureConfig.config = { _ in FeatureConfig.PreviewPassword.enabled }
    resources.resourceDetailsPublisher = always(
      Just(encryptedDescriptionDetailsViewResource)
        .setFailureType(to: TheErrorLegacy.self)
        .eraseToAnyPublisher()
    )
    features.use(featureConfig)
    resources.loadResourceSecret = always(
      Just(resourceSecret)
        .setFailureType(to: TheErrorLegacy.self)
        .eraseToAnyPublisher()
    )
    features.use(resources)

    var pasteboardContent: String? = nil

    pasteboard.put = { string in
      pasteboardContent = string
    }

    features.use(pasteboard)

    let context: Resource.ID = "1"
    let controller: ResourceDetailsController = testInstance(context: context)

    controller
      .copyFieldValue(.description)
      .sinkDrop()
      .store(in: cancellables)

    XCTAssertNotNil(pasteboardContent)
    XCTAssertEqual(pasteboardContent, resourceSecret.description)
  }

  func test_copyFieldURI_succeeds() {
    featureConfig.config = { _ in FeatureConfig.PreviewPassword.enabled }
    resources.resourceDetailsPublisher = always(
      Just(detailsViewResource)
        .setFailureType(to: TheErrorLegacy.self)
        .eraseToAnyPublisher()
    )
    features.use(featureConfig)
    features.use(resources)

    var pasteboardContent: String? = nil

    pasteboard.put = { string in
      pasteboardContent = string
    }

    features.use(pasteboard)

    let context: Resource.ID = "1"
    let controller: ResourceDetailsController = testInstance(context: context)

    controller
      .copyFieldValue(.uri)
      .sinkDrop()
      .store(in: cancellables)

    XCTAssertNotNil(pasteboardContent)
    XCTAssertEqual(pasteboardContent, detailsViewResource.url)
  }

  func test_copyFieldPassword_succeeds() {
    featureConfig.config = { _ in FeatureConfig.PreviewPassword.enabled }
    resources.resourceDetailsPublisher = always(
      Just(detailsViewResource)
        .setFailureType(to: TheErrorLegacy.self)
        .eraseToAnyPublisher()
    )
    features.use(featureConfig)
    resources.loadResourceSecret = always(
      Just(resourceSecret)
        .setFailureType(to: TheErrorLegacy.self)
        .eraseToAnyPublisher()
    )
    features.use(resources)

    var pasteboardContent: String? = nil

    pasteboard.put = { string in
      pasteboardContent = string
    }

    features.use(pasteboard)

    let context: Resource.ID = "1"
    let controller: ResourceDetailsController = testInstance(context: context)

    controller
      .copyFieldValue(.password)
      .sinkDrop()
      .store(in: cancellables)

    XCTAssertNotNil(pasteboardContent)
    XCTAssertEqual(pasteboardContent, resourceSecret.password)
  }

  func test_resourceDeleteAlertPresentationPublisher_publishesResourceID_whenPresentDeleteResourceAlertCalled() {
    featureConfig.config = { _ in FeatureConfig.PreviewPassword.enabled }
    resources.resourceDetailsPublisher = always(
      Just(detailsViewResource)
        .setFailureType(to: TheErrorLegacy.self)
        .eraseToAnyPublisher()
    )
    features.use(featureConfig)
    features.use(resources)
    features.use(pasteboard)

    let context: Resource.ID = "1"
    let controller: ResourceDetailsController = testInstance(context: context)
    var result: Resource.ID?

    controller.resourceDeleteAlertPresentationPublisher()
      .sink { resourceID in
        result = resourceID
      }
      .store(in: cancellables)

    controller.presentDeleteResourceAlert(context)

    XCTAssertEqual(result, context)
  }

  func test_resourceDeletionPublisher_triggersRefreshIfNeeded_whenDeletion_succeeds() {
    var resourcesList: Array<ListViewResource> = [
      ListViewResource(
        id: "resource_1",
        permission: .read,
        name: "Resoure 1",
        url: "passbolt.com",
        username: "test"
      )
    ]
    featureConfig.config = { _ in FeatureConfig.PreviewPassword.enabled }
    resources.resourceDetailsPublisher = always(
      Just(detailsViewResource)
        .setFailureType(to: TheErrorLegacy.self)
        .eraseToAnyPublisher()
    )
    resources.filteredResourcesListPublisher = always(
      Just(resourcesList)
        .eraseToAnyPublisher()
    )
    resources.deleteResource = { resourceID in
      resourcesList.removeAll { $0.id == resourceID }
      return Just(())
        .setFailureType(to: TheErrorLegacy.self)
        .eraseToAnyPublisher()
    }

    var result: Void?

    resources.refreshIfNeeded = {
      result = Void()
      return Just(())
        .ignoreOutput()
        .setFailureType(to: TheErrorLegacy.self)
        .eraseToAnyPublisher()
    }
    features.use(resources)
    features.use(featureConfig)
    features.use(pasteboard)

    let context: Resource.ID = "1"
    let controller: ResourceDetailsController = testInstance(context: context)

    controller
      .resourceDeletionPublisher(resourcesList.first!.id)
      .sinkDrop()
      .store(in: cancellables)

    XCTAssertNotNil(result)
    XCTAssertTrue(resourcesList.isEmpty)
  }
}

private let detailsViewResource: DetailsViewResource = .init(
  id: .init(rawValue: "1"),
  permission: .owner,
  name: "Passphrase",
  url: "https://passbolt.com",
  username: "passbolt@passbolt.com",
  description: "Passbolt",
  properties: [
    .init(name: "username", typeString: "string", required: true, encrypted: false, maxLength: nil)!,
    .init(name: "password", typeString: "string", required: true, encrypted: true, maxLength: nil)!,
    .init(name: "uri", typeString: "string", required: true, encrypted: false, maxLength: nil)!,
    .init(name: "description", typeString: "string", required: true, encrypted: false, maxLength: nil)!,
  ]
)

private let encryptedDescriptionDetailsViewResource: DetailsViewResource = .init(
  id: .init(rawValue: "1"),
  permission: .owner,
  name: "Passphrase",
  url: "https://passbolt.com",
  username: "passbolt@passbolt.com",
  description: nil,
  properties: [
    .init(name: "username", typeString: "string", required: true, encrypted: false, maxLength: nil)!,
    .init(name: "password", typeString: "string", required: true, encrypted: true, maxLength: nil)!,
    .init(name: "uri", typeString: "string", required: true, encrypted: false, maxLength: nil)!,
    .init(name: "description", typeString: "string", required: true, encrypted: true, maxLength: nil)!,
  ]
)

private let resourceSecret: ResourceSecret = .from(
  decrypted: #"{"password": "passbolt", "description": "encrypted"}"#,
  using: .init()
)!
