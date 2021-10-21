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

import Commons
import Crypto
import Features
import NetworkClient
import TestExtensions
import Users
import XCTest

@testable import Accounts
@testable import Resources

// swift-format-ignore: AlwaysUseLowerCamelCase, NeverUseImplicitlyUnwrappedOptionals
final class ResourceCreateFormTests: TestCase {

  var accountSession: AccountSession!
  var database: AccountDatabase!
  var networkClient: NetworkClient!
  var userPGPMessages: UserPGPMessages!

  override func setUp() {
    super.setUp()
    accountSession = .placeholder
    database = .placeholder
    networkClient = .placeholder
    userPGPMessages = .placeholder
  }

  override func tearDown() {
    accountSession = nil
    database = nil
    networkClient = nil
    userPGPMessages = nil
    super.tearDown()
  }

  func test_resourceTypePublisher_fails_whenNoResourceTypesAvailable() {
    features.use(accountSession)
    database.fetchResourcesTypesOperation.execute = always(Just([]).setFailureType(to: TheError.self).eraseToAnyPublisher())
    features.use(database)
    features.use(networkClient)
    features.use(userPGPMessages)

    let feature: ResourceCreateForm = testInstance()

    var result: TheError?
    feature
      .resourceTypePublisher()
      .sink(
        receiveCompletion: { completion in
          guard case let .failure(error) = completion
          else { return }
          result = error
        },
        receiveValue: { _ in }
      )
      .store(in: cancellables)

    XCTAssertEqual(result?.identifier, .invalidOrMissingResourceType)
  }

  func test_resourceTypePublisher_fails_whenNoValidResourceTypeAvailable() {
    features.use(accountSession)
    database.fetchResourcesTypesOperation.execute = always(Just([emptyResourceType]).setFailureType(to: TheError.self).eraseToAnyPublisher())
    features.use(database)
    features.use(networkClient)
    features.use(userPGPMessages)

    let feature: ResourceCreateForm = testInstance()

    var result: TheError?
    feature
      .resourceTypePublisher()
      .sink(
        receiveCompletion: { completion in
          guard case let .failure(error) = completion
          else { return }
          result = error
        },
        receiveValue: { _ in }
      )
      .store(in: cancellables)

    XCTAssertEqual(result?.identifier, .invalidOrMissingResourceType)
  }

  func test_resourceTypePublisher_publishesDefaultResourceType_whenValidResourceTypeAvailable() {
    features.use(accountSession)
    database.fetchResourcesTypesOperation.execute = always(Just([.init(id: "password-and-description", slug: "password-and-description", name: "password-and-description", fields: [])]).setFailureType(to: TheError.self).eraseToAnyPublisher())
    features.use(database)
    features.use(networkClient)
    features.use(userPGPMessages)

    let feature: ResourceCreateForm = testInstance()

    var result: ResourceType?
    feature
      .resourceTypePublisher()
      .sink(
        receiveCompletion: { _ in },
        receiveValue: { resourceType in
          result = resourceType
        }
      )
      .store(in: cancellables)

    XCTAssert(result?.isDefault ?? false)
  }

  func test_fieldValuePublisher_returnsNotPublishingPublisher_whenResourceFieldNotAvailable() {
    features.use(accountSession)
    database.fetchResourcesTypesOperation.execute = always(Just([defaultResourceType]).setFailureType(to: TheError.self).eraseToAnyPublisher())
    features.use(database)
    features.use(networkClient)
    features.use(userPGPMessages)

    let feature: ResourceCreateForm = testInstance()

    var result: Void?
    feature
      .fieldValuePublisher("unavailable")
      .sink(
        receiveCompletion: { completion in
          result = Void()
        },
        receiveValue: { _ in
          result = Void()
        }
      )
      .store(in: cancellables)

    XCTAssertNil(result)
  }

  func test_fieldValuePublisher_returnsInitiallyPublishingPublisher_whenResourceFieldAvailable() {
    features.use(accountSession)
    database.fetchResourcesTypesOperation.execute = always(Just([defaultResourceType]).setFailureType(to: TheError.self).eraseToAnyPublisher())
    features.use(database)
    features.use(networkClient)
    features.use(userPGPMessages)

    let feature: ResourceCreateForm = testInstance()

    var result: Validated<String>?
    feature
      .fieldValuePublisher("name")
      .sink(
        receiveCompletion: { _ in },
        receiveValue: { value in
          result = value
        }
      )
      .store(in: cancellables)

    XCTAssertEqual(result?.value, "")
  }

  func test_fieldValuePublisher_returnsPublisherPublishingChages_whenResourceFieldValueChanges() {
    features.use(accountSession)
    database.fetchResourcesTypesOperation.execute = always(Just([defaultResourceType]).setFailureType(to: TheError.self).eraseToAnyPublisher())
    features.use(database)
    features.use(networkClient)
    features.use(userPGPMessages)

    let feature: ResourceCreateForm = testInstance()

    var result: Validated<String>?
    feature
      .fieldValuePublisher("name")
      .sink(
        receiveCompletion: { _ in },
        receiveValue: { value in
          result = value
        }
      )
      .store(in: cancellables)

    feature
      .setFieldValue("updated", "name")
      .sinkDrop()
      .store(in: cancellables)

    XCTAssertEqual(result?.value, "updated")
  }

  func test_fieldValuePublisher_returnsPublisherPublishingValidatedValue_withResourceFieldValueValidation() {
    features.use(accountSession)
    database.fetchResourcesTypesOperation.execute = always(Just([defaultResourceType]).setFailureType(to: TheError.self).eraseToAnyPublisher())
    features.use(database)
    features.use(networkClient)
    features.use(userPGPMessages)

    let feature: ResourceCreateForm = testInstance()

    var result: Validated<String>?
    feature
      .fieldValuePublisher("name")
      .sink(
        receiveCompletion: { _ in },
        receiveValue: { value in
          result = value
        }
      )
      .store(in: cancellables)

    XCTAssert(!(result?.isValid ?? false))

    feature
      .setFieldValue("updated", "name")
      .sinkDrop()
      .store(in: cancellables)

    XCTAssert(result?.isValid ?? false)
  }

  func test_setFieldValue_fails_whenResourceFieldNotAvailable() {
    features.use(accountSession)
    database.fetchResourcesTypesOperation.execute = always(Just([defaultResourceType]).setFailureType(to: TheError.self).eraseToAnyPublisher())
    features.use(database)
    features.use(networkClient)
    features.use(userPGPMessages)

    let feature: ResourceCreateForm = testInstance()

    var result: TheError?
    feature
      .setFieldValue("updated", "unavailable")
      .sink(
        receiveCompletion: { completion in
          guard case let .failure(error) = completion
          else { return }
          result = error
        },
        receiveValue: {}
      )
      .store(in: cancellables)

    XCTAssertEqual(result?.identifier, .invalidOrMissingResourceType)
  }

  func test_setFieldValue_succeeds_whenResourceFieldAvailable() {
    features.use(accountSession)
    database.fetchResourcesTypesOperation.execute = always(Just([defaultResourceType]).setFailureType(to: TheError.self).eraseToAnyPublisher())
    features.use(database)
    features.use(networkClient)
    features.use(userPGPMessages)

    let feature: ResourceCreateForm = testInstance()

    var result: Void?
    feature
      .setFieldValue("updated", "name")
      .sink(
        receiveCompletion: { _ in },
        receiveValue: {
          result = Void()
        }
      )
      .store(in: cancellables)

    XCTAssertNotNil(result)
  }

  func test_createResource_fails_whenFetchResourcesTypesOperationFails() {
    features.use(accountSession)
    database.fetchResourcesTypesOperation.execute = always(
      Fail(error: .testError())
        .eraseToAnyPublisher()
    )
    features.use(database)
    features.use(networkClient)
    features.use(userPGPMessages)

    let feature: ResourceCreateForm = testInstance()

    var result: TheError?
    feature
      .createResource()
      .sink(
        receiveCompletion: { completion in
          guard case let .failure(error) = completion
          else { return }
          result = error
        },
        receiveValue: { _ in }
      )
      .store(in: cancellables)

    XCTAssertEqual(result?.identifier, .testError)
  }

  func test_createResource_fails_whenFieldsValidationFails() {
    features.use(accountSession)
    database.fetchResourcesTypesOperation.execute = always(
      Just([defaultShrinkedResourceType])
        .setFailureType(to: TheError.self)
        .eraseToAnyPublisher()
    )
    features.use(database)
    features.use(networkClient)
    features.use(userPGPMessages)

    let feature: ResourceCreateForm = testInstance()

    var result: TheError?
    feature
      .createResource()
      .sink(
        receiveCompletion: { completion in
          guard case let .failure(error) = completion
          else { return }
          result = error
        },
        receiveValue: { _ in }
      )
      .store(in: cancellables)

    XCTAssertEqual(result?.identifier, .validation)
  }

  func test_createResource_fails_whenNoActiveUserSession() {
    accountSession.statePublisher = always(
      Just(.none(lastUsed: nil))
        .eraseToAnyPublisher()
    )
    features.use(accountSession)
    database.fetchResourcesTypesOperation.execute = always(
      Just([defaultShrinkedResourceType])
        .setFailureType(to: TheError.self)
        .eraseToAnyPublisher()
    )
    features.use(database)
    features.use(networkClient)
    features.use(userPGPMessages)

    let feature: ResourceCreateForm = testInstance()

    feature
      .setFieldValue("name", "name")
      .sinkDrop()
      .store(in: cancellables)

    var result: TheError?
    feature
      .createResource()
      .sink(
        receiveCompletion: { completion in
          guard case let .failure(error) = completion
          else { return }
          result = error
        },
        receiveValue: { _ in }
      )
      .store(in: cancellables)

    XCTAssertEqual(result?.identifier, .authorizationRequired)
  }

  func test_createResource_fails_whenEncryptMessageForUserFails() {
    accountSession.statePublisher = always(
      Just(.authorized(validAccount))
        .eraseToAnyPublisher()
    )
    features.use(accountSession)
    database.fetchResourcesTypesOperation.execute = always(
      Just([defaultShrinkedResourceType])
        .setFailureType(to: TheError.self)
        .eraseToAnyPublisher()
    )
    features.use(database)
    features.use(networkClient)
    userPGPMessages.encryptMessageForUser = always(
      Fail(error: .testError())
        .eraseToAnyPublisher()
    )
    features.use(userPGPMessages)

    let feature: ResourceCreateForm = testInstance()

    feature
      .setFieldValue("name", "name")
      .sinkDrop()
      .store(in: cancellables)

    var result: TheError?
    feature
      .createResource()
      .sink(
        receiveCompletion: { completion in
          guard case let .failure(error) = completion
          else { return }
          result = error
        },
        receiveValue: { _ in }
      )
      .store(in: cancellables)

    XCTAssertEqual(result?.identifier, .testError)
  }

  func test_createResource_fails_whenCreateResourceRequestFails() {
    accountSession.statePublisher = always(
      Just(.authorized(validAccount))
        .eraseToAnyPublisher()
    )
    features.use(accountSession)
    database.fetchResourcesTypesOperation.execute = always(
      Just([defaultShrinkedResourceType])
        .setFailureType(to: TheError.self)
        .eraseToAnyPublisher()
    )
    features.use(database)
    networkClient.createResourceRequest.execute = always(
      Fail(error: .testError())
        .eraseToAnyPublisher()
    )
    features.use(networkClient)
    userPGPMessages.encryptMessageForUser = always(
      Just("encrypted-message")
        .setFailureType(to: TheError.self)
        .eraseToAnyPublisher()
    )
    features.use(userPGPMessages)

    let feature: ResourceCreateForm = testInstance()

    feature
      .setFieldValue("name", "name")
      .sinkDrop()
      .store(in: cancellables)

    var result: TheError?
    feature
      .createResource()
      .sink(
        receiveCompletion: { completion in
          guard case let .failure(error) = completion
          else { return }
          result = error
        },
        receiveValue: { _ in }
      )
      .store(in: cancellables)

    XCTAssertEqual(result?.identifier, .testError)
  }

  func test_createResource_succeeds_whenAllOperationsSucceed() {
    accountSession.statePublisher = always(
      Just(.authorized(validAccount))
        .eraseToAnyPublisher()
    )
    features.use(accountSession)
    database.fetchResourcesTypesOperation.execute = always(
      Just([defaultShrinkedResourceType])
        .setFailureType(to: TheError.self)
        .eraseToAnyPublisher()
    )
    features.use(database)
    networkClient.createResourceRequest.execute = always(
      Just(.init(
        header: .mock(),
        body: .init(resourceID: "resource-id")
      ))
      .setFailureType(to: TheError.self)
      .eraseToAnyPublisher()
    )
    features.use(networkClient)
    userPGPMessages.encryptMessageForUser = always(
      Just("encrypted-message")
        .setFailureType(to: TheError.self)
        .eraseToAnyPublisher()
    )
    features.use(userPGPMessages)

    let feature: ResourceCreateForm = testInstance()

    feature
      .setFieldValue("name", "name")
      .sinkDrop()
      .store(in: cancellables)

    var result: Resource.ID?
    feature
      .createResource()
      .sink(
        receiveCompletion: { _ in },
        receiveValue: { resourceID in
          result = resourceID
        }
      )
      .store(in: cancellables)

    XCTAssertEqual(result, "resource-id")
  }
}

private let emptyResourceType: ResourceType = .init(
  id: "empty",
  slug: "empty",
  name: "empty",
  fields: []
)

private let defaultShrinkedResourceType: ResourceType = .init(
  id: "password-and-description-shrinked",
  slug: "password-and-description",
  name: "password-and-description-shrinked",
  fields: [
    .string(name: "name", required: true, encrypted: false, maxLength: nil),
  ]
)

private let defaultResourceType: ResourceType = .init(
  id: "password-and-description",
  slug: "password-and-description",
  name: "password-and-description",
  fields: [
    .string(name: "name", required: true, encrypted: false, maxLength: nil),
    .string(name: "uri", required: false, encrypted: false, maxLength: nil),
    .string(name: "username", required: false, encrypted: false, maxLength: nil),
    .string(name: "password", required: true, encrypted: true, maxLength: nil),
    .string(name: "description", required: false, encrypted: true, maxLength: nil),
  ]
)

private let validAccount: Account = .init(
  localID: .init(rawValue: UUID.test.uuidString),
  domain: "https://passbolt.dev",
  userID: "USER_ID",
  fingerprint: "FINGERPRINT"
)
