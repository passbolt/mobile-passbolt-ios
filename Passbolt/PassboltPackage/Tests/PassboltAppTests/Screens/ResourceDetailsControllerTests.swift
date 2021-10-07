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

@testable import Accounts
import Combine
import Features
@testable import Resources
import TestExtensions
import UIComponents
import XCTest

@testable import PassboltApp

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
        .setFailureType(to: TheError.self)
        .eraseToAnyPublisher()
    )
    features.use(featureConfig)
    features.use(resources)
    features.use(pasteboard)

    let context: Resource.ID = "1"
    let controller: ResourceDetailsController = testInstance(context: context)
    var result: ResourceDetailsController.ResourceDetailsWithConfig!

    controller.resourceDetailsWithConfigPublisher()
      .sink(receiveCompletion: { completion in
        guard case .finished = completion
        else {
          XCTFail("Unexpected failure")
          return
        }
      }, receiveValue: { resourceDetailsConfig in
        result = resourceDetailsConfig
      })
      .store(in: cancellables)

    XCTAssertNotNil(result)
    XCTAssertEqual(result.resourceDetails.id.rawValue, context.rawValue)
  }

  func test_loadResourceDetails_succeeds_withSortedFields_whenAvailable() {
    featureConfig.config = { _ in FeatureConfig.PreviewPassword.enabled }
    resources.resourceDetailsPublisher = { _ in
      var detailsViewResourceWithReorderedFields: DetailsViewResource = detailsViewResource
      detailsViewResourceWithReorderedFields.fields.reverse()
      return Just(detailsViewResourceWithReorderedFields)
        .setFailureType(to: TheError.self)
        .eraseToAnyPublisher()
    }
    features.use(featureConfig)
    features.use(resources)
    features.use(pasteboard)

    let context: Resource.ID = "1"
    let controller: ResourceDetailsController = testInstance(context: context)

    let expectedOrderedFields: [ResourceDetailsController.ResourceDetails.Field] = [
      .username(required: true, encrypted: false, maxLength: nil),
      .password(required: true, encrypted: true, maxLength: nil),
      .uri(required: true, encrypted: false, maxLength: nil),
      .description(required: true, encrypted: false, maxLength: nil)
    ]

    var result: ResourceDetailsController.ResourceDetailsWithConfig!

    controller.resourceDetailsWithConfigPublisher()
      .sink(receiveCompletion: { completion in
        guard case .finished = completion
        else {
          XCTFail("Unexpected failure")
          return
        }
      }, receiveValue: { resourceDetailsConfig in
        result = resourceDetailsConfig
      })
      .store(in: cancellables)

    XCTAssertNotNil(result)
    XCTAssertEqual(result.resourceDetails.id.rawValue, context.rawValue)
    XCTAssertEqual(result.resourceDetails.fields, expectedOrderedFields)
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
    var result: TheError!

    controller.resourceDetailsWithConfigPublisher()
      .sink(receiveCompletion: { completion in
        guard case let .failure(error) = completion
        else {
          XCTFail("Unexpected completion")
          return
        }
        result = error
      }, receiveValue: { _ in
        XCTFail("Unexpected value")
      })
      .store(in: cancellables)

    XCTAssertNotNil(result)
  }

  func test_toggleDecrypt_publishes_whenResourceFetch_succeeds() {
    resources.resourceDetailsPublisher = always(
      Empty().eraseToAnyPublisher()
    )
    resources.loadResourceSecret = always(
      Just(resourceSecret).setFailureType(to: TheError.self).eraseToAnyPublisher()
    )
    features.use(featureConfig)
    features.use(resources)
    features.use(pasteboard)

    let context: Resource.ID = "1"
    let controller: ResourceDetailsController = testInstance(context: context)
    var result: String!

    controller
      .toggleDecrypt(
        .password(
          required: true,
          encrypted: true,
          maxLength: nil
        )
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
    var result: TheError!

    controller
      .toggleDecrypt(
        .password(
          required: true,
          encrypted: true,
          maxLength: nil
        )
      )
      .sink(receiveCompletion: { completion in
        guard case let .failure(error) = completion
        else {
          XCTFail("Unexpected completion")
          return
        }
        result = error
      }, receiveValue: { _ in
        XCTFail("Unexpected value")
      })
      .store(in: cancellables)

    XCTAssertNotNil(result)
  }

  func test_toggleDecrypt_publishesNil_whenTryingToDecryptAlreadyDecrypted() {
    resources.resourceDetailsPublisher = always(
      Empty().eraseToAnyPublisher()
    )
    resources.loadResourceSecret = always(
      Just(resourceSecret).setFailureType(to: TheError.self).eraseToAnyPublisher()
    )
    features.use(featureConfig)
    features.use(resources)
    features.use(pasteboard)

    let context: Resource.ID = "1"
    let controller: ResourceDetailsController = testInstance(context: context)
    var result: String!

    controller
      .toggleDecrypt(
        .password(
          required: true,
          encrypted: true,
          maxLength: nil
        )
      )
      .sinkDrop()
      .store(in: cancellables)

    controller
      .toggleDecrypt(
        .password(
          required: true,
          encrypted: true,
          maxLength: nil
        )
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
        .setFailureType(to: TheError.self)
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
      .copyFieldValue(.username(required: true, encrypted: false, maxLength: nil))
      .sinkDrop()
      .store(in: cancellables)

    XCTAssertNotNil(pasteboardContent)
    XCTAssertEqual(pasteboardContent, detailsViewResource.username)
  }

  func test_copyFieldDescription_succeeds() {
    featureConfig.config = { _ in FeatureConfig.PreviewPassword.enabled }
    resources.resourceDetailsPublisher = always(
      Just(detailsViewResource)
        .setFailureType(to: TheError.self)
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
      .copyFieldValue(.description(required: true, encrypted: false, maxLength: nil))
      .sinkDrop()
      .store(in: cancellables)

    XCTAssertNotNil(pasteboardContent)
    XCTAssertEqual(pasteboardContent, detailsViewResource.description)
  }

  func test_copyFieldEncryptedDescription_succeeds() {
    featureConfig.config = { _ in FeatureConfig.PreviewPassword.enabled }
    resources.resourceDetailsPublisher = always(
      Just(encryptedDescriptionDetailsViewResource)
        .setFailureType(to: TheError.self)
        .eraseToAnyPublisher()
    )
    features.use(featureConfig)
    resources.loadResourceSecret = always(
      Just(resourceSecret)
        .setFailureType(to: TheError.self)
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
      .copyFieldValue(.description(required: true, encrypted: true, maxLength: nil))
      .sinkDrop()
      .store(in: cancellables)

    XCTAssertNotNil(pasteboardContent)
    XCTAssertEqual(pasteboardContent, resourceSecret.description)
  }

  func test_copyFieldURI_succeeds() {
    featureConfig.config = { _ in FeatureConfig.PreviewPassword.enabled }
    resources.resourceDetailsPublisher = always(
      Just(detailsViewResource)
        .setFailureType(to: TheError.self)
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
      .copyFieldValue(.uri(required: true, encrypted: false, maxLength: 0))
      .sinkDrop()
      .store(in: cancellables)

    XCTAssertNotNil(pasteboardContent)
    XCTAssertEqual(pasteboardContent, detailsViewResource.url)
  }

  func test_copyFieldPassword_succeeds() {
    featureConfig.config = { _ in FeatureConfig.PreviewPassword.enabled }
    resources.resourceDetailsPublisher = always(
      Just(detailsViewResource)
        .setFailureType(to: TheError.self)
        .eraseToAnyPublisher()
    )
    features.use(featureConfig)
    resources.loadResourceSecret = always(
      Just(resourceSecret)
        .setFailureType(to: TheError.self)
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
      .copyFieldValue(.password(required: true, encrypted: true, maxLength: nil))
      .sinkDrop()
      .store(in: cancellables)

    XCTAssertNotNil(pasteboardContent)
    XCTAssertEqual(pasteboardContent, resourceSecret.password)
  }
}

private let detailsViewResource: DetailsViewResource = .init(
  id: .init(rawValue: "1"),
  permission: .owner,
  name: "Passphrase",
  url: "https://passbolt.com",
  username: "passbolt@passbolt.com",
  description: "Passbolt",
  fields: [
    .string(name: "username", required: true, encrypted: false, maxLength: nil),
    .string(name: "password", required: true, encrypted: true, maxLength: nil),
    .string(name: "uri", required: true, encrypted: false, maxLength: nil),
    .string(name: "description", required: true, encrypted: false, maxLength: nil)
  ])

private let encryptedDescriptionDetailsViewResource: DetailsViewResource = .init(
  id: .init(rawValue: "1"),
  permission: .owner,
  name: "Passphrase",
  url: "https://passbolt.com",
  username: "passbolt@passbolt.com",
  description: nil,
  fields: [
    .string(name: "username", required: true, encrypted: false, maxLength: nil),
    .string(name: "password", required: true, encrypted: true, maxLength: nil),
    .string(name: "uri", required: true, encrypted: false, maxLength: nil),
    .string(name: "description", required: true, encrypted: true, maxLength: nil)
  ])

private let resourceSecret: ResourceSecret = .from(
  decrypted: #"{"password": "passbolt", "description": "encrypted"}"#,
  using: .init()
)!
