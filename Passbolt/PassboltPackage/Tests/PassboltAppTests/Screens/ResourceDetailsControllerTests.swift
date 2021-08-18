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

  var accountDatabase: AccountDatabase!
  var resources: Resources!

  override func setUp() {
    super.setUp()

    accountDatabase = .placeholder
    resources = .placeholder
  }

  override func tearDown() {
    super.tearDown()

    accountDatabase = nil
    resources = nil
  }

  func test_loadResourceDetails_succeeds_whenAvailable() {
    accountDatabase.fetchDetailsViewResources = FetchDetailsViewResourcesOperation(execute: { _ in
      Just(detailsViewResource).setFailureType(to: TheError.self).eraseToAnyPublisher()
    })

    features.use(accountDatabase)
    features.use(resources)

    let context: Resource.ID = "1"
    let controller: ResourceDetailsController = testInstance(context: context)
    var result: ResourceDetailsController.ResourceDetails!

    controller.loadResourceDetails()
      .sink(receiveCompletion: { completion in
        guard case .finished = completion
        else {
          XCTFail("Unexpected failure")
          return
        }
      }, receiveValue: { resourceDetails in
        result = resourceDetails
      })
      .store(in: cancellables)

    XCTAssertNotNil(result)
    XCTAssertEqual(result.id.rawValue, context.rawValue)
  }

  func test_loadResourceDetails_succeeds_withSortedFields_whenAvailable() {
    accountDatabase.fetchDetailsViewResources = FetchDetailsViewResourcesOperation(execute: { _ in
      var detailsViewResourceWithReorderedFields: DetailsViewResource = detailsViewResource
      detailsViewResourceWithReorderedFields.fields.reverse()
      return Just(detailsViewResourceWithReorderedFields).setFailureType(to: TheError.self).eraseToAnyPublisher()
    })

    features.use(accountDatabase)
    features.use(resources)

    let context: Resource.ID = "1"
    let controller: ResourceDetailsController = testInstance(context: context)

    let expectedOrderedFields: [ResourceDetailsController.ResourceDetails.Field] = [
      .username(required: true, encrypted: false, maxLength: nil),
      .password(required: true, encrypted: true, maxLength: nil),
      .uri(required: true, encrypted: false, maxLength: nil),
      .description(required: true, encrypted: false, maxLength: nil)
    ]

    var result: ResourceDetailsController.ResourceDetails!

    controller.loadResourceDetails()
      .sink(receiveCompletion: { completion in
        guard case .finished = completion
        else {
          XCTFail("Unexpected failure")
          return
        }
      }, receiveValue: { resourceDetails in
        result = resourceDetails
      })
      .store(in: cancellables)

    XCTAssertNotNil(result)
    XCTAssertEqual(result.id.rawValue, context.rawValue)
    XCTAssertEqual(result.fields, expectedOrderedFields)
  }

  func test_loadResourceDetails_fails_whenErrorOnFetch() {
    accountDatabase.fetchDetailsViewResources = FetchDetailsViewResourcesOperation(execute: { _ in
      Fail(error: .testError()).eraseToAnyPublisher()
    })

    features.use(accountDatabase)
    features.use(resources)

    let context: Resource.ID = "1"
    let controller: ResourceDetailsController = testInstance(context: context)
    var result: TheError!

    controller.loadResourceDetails()
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
    resources.loadResourceSecret = always(
      Just(resourceSecret).setFailureType(to: TheError.self).eraseToAnyPublisher()
    )
    features.use(resources)

    features.use(accountDatabase)

    let context: Resource.ID = "1"
    let controller: ResourceDetailsController = testInstance(context: context)
    var result: String!

    controller.toggleDecrypt("password")
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
    resources.loadResourceSecret = always(
      Fail(error: .testError()).eraseToAnyPublisher()
    )
    features.use(resources)

    features.use(accountDatabase)

    let context: Resource.ID = "1"
    let controller: ResourceDetailsController = testInstance(context: context)
    var result: TheError!

    controller.toggleDecrypt("password")
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
    resources.loadResourceSecret = always(
      Just(resourceSecret).setFailureType(to: TheError.self).eraseToAnyPublisher()
    )
    features.use(resources)

    features.use(accountDatabase)

    let context: Resource.ID = "1"
    let controller: ResourceDetailsController = testInstance(context: context)
    var result: String!

    controller.toggleDecrypt("password")
      .sinkDrop()
      .store(in: cancellables)

    controller.toggleDecrypt("password")
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

private let resourceSecret: ResourceSecret = .from(
  decrypted: #"["password" : "passbolt"]"#,
  using: .init()
)!
