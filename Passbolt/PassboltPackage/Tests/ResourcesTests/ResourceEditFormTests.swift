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

import CommonDataModels
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
final class ResourceEditFormTests: TestCase {

  var accountSession: AccountSession!
  var database: AccountDatabase!
  var resources: Resources!
  var networkClient: NetworkClient!
  var userPGPMessages: UserPGPMessages!

  override func setUp() {
    super.setUp()
    accountSession = .placeholder
    database = .placeholder
    resources = .placeholder
    networkClient = .placeholder
    userPGPMessages = .placeholder
  }

  override func tearDown() {
    accountSession = nil
    database = nil
    resources = nil
    networkClient = nil
    userPGPMessages = nil
    super.tearDown()
  }

  func test_resourceTypePublisher_fails_whenNoResourceTypesAvailable() {
    features.use(accountSession)
    database.fetchResourcesTypesOperation.execute = always(
      Just([]).setFailureType(to: TheError.self).eraseToAnyPublisher()
    )
    features.use(database)
    features.use(resources)
    features.use(networkClient)
    features.use(userPGPMessages)

    let feature: ResourceEditForm = testInstance()

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
    database.fetchResourcesTypesOperation.execute = always(
      Just([emptyResourceType]).setFailureType(to: TheError.self).eraseToAnyPublisher()
    )
    features.use(database)
    features.use(resources)
    features.use(networkClient)
    features.use(userPGPMessages)

    let feature: ResourceEditForm = testInstance()

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
    database.fetchResourcesTypesOperation.execute = always(
      Just([
        .init(
          id: "password-and-description",
          slug: "password-and-description",
          name: "password-and-description",
          fields: []
        )
      ]).setFailureType(to: TheError.self).eraseToAnyPublisher()
    )
    features.use(database)
    features.use(resources)
    features.use(networkClient)
    features.use(userPGPMessages)

    let feature: ResourceEditForm = testInstance()

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
    database.fetchResourcesTypesOperation.execute = always(
      Just([defaultResourceType]).setFailureType(to: TheError.self).eraseToAnyPublisher()
    )
    features.use(database)
    features.use(resources)
    features.use(networkClient)
    features.use(userPGPMessages)

    let feature: ResourceEditForm = testInstance()

    var result: Void?
    feature
      .fieldValuePublisher(.undefined(name: "unavailable"))
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
    database.fetchResourcesTypesOperation.execute = always(
      Just([defaultResourceType])
        .setFailureType(to: TheError.self)
        .eraseToAnyPublisher()
    )
    features.use(database)
    features.use(resources)
    features.use(networkClient)
    features.use(userPGPMessages)

    let feature: ResourceEditForm = testInstance()

    var result: Validated<ResourceFieldValue>?
    feature
      .fieldValuePublisher(.name)
      .sink(
        receiveCompletion: { _ in },
        receiveValue: { value in
          result = value
        }
      )
      .store(in: cancellables)

    XCTAssertEqual(result?.value, .string(""))
  }

  func test_fieldValuePublisher_returnsPublisherPublishingChages_whenResourceFieldValueChanges() {
    features.use(accountSession)
    database.fetchResourcesTypesOperation.execute = always(
      Just([defaultResourceType])
        .setFailureType(to: TheError.self)
        .eraseToAnyPublisher()
    )
    features.use(database)
    features.use(resources)
    features.use(networkClient)
    features.use(userPGPMessages)

    let feature: ResourceEditForm = testInstance()

    var result: Validated<ResourceFieldValue>?
    feature
      .fieldValuePublisher(.name)
      .sink(
        receiveCompletion: { _ in },
        receiveValue: { value in
          result = value
        }
      )
      .store(in: cancellables)

    feature
      .setFieldValue(.string("updated"), .name)
      .sinkDrop()
      .store(in: cancellables)

    XCTAssertEqual(result?.value, .string("updated"))
  }

  func test_fieldValuePublisher_returnsPublisherPublishingValidatedValue_withResourceFieldValueValidation() {
    features.use(accountSession)
    database.fetchResourcesTypesOperation.execute = always(
      Just([defaultResourceType])
        .setFailureType(to: TheError.self)
        .eraseToAnyPublisher()
    )
    features.use(database)
    features.use(resources)
    features.use(networkClient)
    features.use(userPGPMessages)

    let feature: ResourceEditForm = testInstance()

    var result: Validated<ResourceFieldValue>?
    feature
      .fieldValuePublisher(.name)
      .sink(
        receiveCompletion: { _ in },
        receiveValue: { value in
          result = value
        }
      )
      .store(in: cancellables)

    XCTAssert(!(result?.isValid ?? false))

    feature
      .setFieldValue(.string("updated"), .name)
      .sinkDrop()
      .store(in: cancellables)

    XCTAssert(result?.isValid ?? false)
  }

  func test_setFieldValue_fails_whenResourceFieldNotAvailable() {
    features.use(accountSession)
    database.fetchResourcesTypesOperation.execute = always(
      Just([defaultResourceType])
        .setFailureType(to: TheError.self)
        .eraseToAnyPublisher()
    )
    features.use(database)
    features.use(resources)
    features.use(networkClient)
    features.use(userPGPMessages)

    let feature: ResourceEditForm = testInstance()

    var result: TheError?
    feature
      .setFieldValue(.string("updated"), .undefined(name: "unavailable"))
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
    database.fetchResourcesTypesOperation.execute = always(
      Just([defaultResourceType])
        .setFailureType(to: TheError.self)
        .eraseToAnyPublisher()
    )
    features.use(database)
    features.use(resources)
    features.use(networkClient)
    features.use(userPGPMessages)

    let feature: ResourceEditForm = testInstance()

    var result: Void?
    feature
      .setFieldValue(.string("updated"), .name)
      .sink(
        receiveCompletion: { _ in },
        receiveValue: {
          result = Void()
        }
      )
      .store(in: cancellables)

    XCTAssertNotNil(result)
  }

  func test_sendForm_fails_whenFetchResourcesTypesOperationFails() {
    features.use(accountSession)
    database.fetchResourcesTypesOperation.execute = always(
      Fail(error: .testError())
        .eraseToAnyPublisher()
    )
    features.use(database)
    features.use(resources)
    features.use(networkClient)
    features.use(userPGPMessages)

    let feature: ResourceEditForm = testInstance()

    var result: TheError?
    feature
      .sendForm()
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

  func test_sendForm_fails_whenFieldsValidationFails() {
    features.use(accountSession)
    database.fetchResourcesTypesOperation.execute = always(
      Just([defaultShrinkedResourceType])
        .setFailureType(to: TheError.self)
        .eraseToAnyPublisher()
    )
    features.use(database)
    features.use(resources)
    features.use(networkClient)
    features.use(userPGPMessages)

    let feature: ResourceEditForm = testInstance()

    var result: TheError?
    feature
      .sendForm()
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

  func test_sendForm_fails_whenNoActiveUserSession() {
    accountSession.statePublisher = always(
      Just(.none(lastUsed: nil))
        .eraseToAnyPublisher()
    )
    accountSession.requestAuthorizationPrompt = always(Void())
    features.use(accountSession)
    database.fetchResourcesTypesOperation.execute = always(
      Just([defaultShrinkedResourceType])
        .setFailureType(to: TheError.self)
        .eraseToAnyPublisher()
    )
    features.use(database)
    features.use(resources)
    features.use(networkClient)
    features.use(userPGPMessages)

    let feature: ResourceEditForm = testInstance()

    feature
      .setFieldValue(.string(name), .name)
      .sinkDrop()
      .store(in: cancellables)

    var result: TheError?
    feature
      .sendForm()
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

  func test_sendForm_fails_whenEncryptMessageForUserFails() {
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
    features.use(resources)
    features.use(networkClient)
    userPGPMessages.encryptMessageForUser = always(
      Fail(error: .testError())
        .eraseToAnyPublisher()
    )
    features.use(userPGPMessages)

    let feature: ResourceEditForm = testInstance()

    feature
      .setFieldValue(.string(name), .name)
      .sinkDrop()
      .store(in: cancellables)

    var result: TheError?
    feature
      .sendForm()
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

  func test_sendForm_fails_whenCreateResourceRequestFails() {
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
    features.use(resources)
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

    let feature: ResourceEditForm = testInstance()

    feature
      .setFieldValue(.string("name"), .name)
      .sinkDrop()
      .store(in: cancellables)

    var result: TheError?
    feature
      .sendForm()
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

  func test_sendForm_succeeds_whenAllOperationsSucceed() {
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
    features.use(resources)
    networkClient.createResourceRequest.execute = always(
      Just(
        .init(
          header: .mock(),
          body: .init(resourceID: "resource-id")
        )
      )
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

    let feature: ResourceEditForm = testInstance()

    feature
      .setFieldValue(.string("name"), .name)
      .sinkDrop()
      .store(in: cancellables)

    var result: Resource.ID?
    feature
      .sendForm()
      .sink(
        receiveCompletion: { _ in },
        receiveValue: { resourceID in
          result = resourceID
        }
      )
      .store(in: cancellables)

    XCTAssertEqual(result, "resource-id")
  }

  func test_resourceEdit_fails_whenFetchingEditViewResourceFromDatabaseFails() {
    features.use(accountSession)
    database.fetchResourcesTypesOperation.execute = always(
      Just([
        .init(
          id: "password-and-description",
          slug: "password-and-description",
          name: "password-and-description",
          fields: []
        )
      ]).setFailureType(to: TheError.self).eraseToAnyPublisher()
    )
    database.fetchEditViewResourceOperation.execute = always(
      Fail(error: .testError())
        .eraseToAnyPublisher()
    )
    features.use(database)
    features.use(resources)
    features.use(networkClient)
    features.use(userPGPMessages)

    let feature: ResourceEditForm = testInstance()

    var result: TheError?
    feature
      .editResource(.init(rawValue: "resource-id"))
      .sink(
        receiveCompletion: { completion in
          guard case let .failure(error) = completion
          else { return }
          result = error
        },
        receiveValue: { /* NOP */  }
      )
      .store(in: cancellables)

    XCTAssertEqual(result?.identifier, .testError)
  }

  func test_resourceEdit_fails_whenFetchingResourceSecretFails() {
    features.use(accountSession)
    database.fetchResourcesTypesOperation.execute = always(
      Just([
        .init(
          id: "password-and-description",
          slug: "password-and-description",
          name: "password-and-description",
          fields: []
        )
      ]).setFailureType(to: TheError.self).eraseToAnyPublisher()
    )
    database.fetchEditViewResourceOperation.execute = always(
      Just(
        .init(
          id: "resource-id",
          type: .init(
            id: "resource-type-id",
            slug: "resource-slug",
            name: "resource type",
            fields: []
          ),
          permission: .owner,
          name: "resource name",
          url: nil,
          username: nil,
          description: nil
        )
      )
      .setFailureType(to: TheError.self)
      .eraseToAnyPublisher()
    )
    features.use(database)
    resources.loadResourceSecret = always(
      Fail(error: .testError())
        .eraseToAnyPublisher()
    )
    features.use(resources)
    features.use(networkClient)
    features.use(userPGPMessages)

    let feature: ResourceEditForm = testInstance()

    var result: TheError?
    feature
      .editResource(.init(rawValue: "resource-id"))
      .sink(
        receiveCompletion: { completion in
          guard case let .failure(error) = completion
          else { return }
          result = error
        },
        receiveValue: { /* NOP */  }
      )
      .store(in: cancellables)

    XCTAssertEqual(result?.identifier, .testError)
  }

  func test_resourceEdit_succeeds_whenLoadingResourceDataSucceeds() {
    features.use(accountSession)
    database.fetchResourcesTypesOperation.execute = always(
      Just([
        .init(
          id: "password-and-description",
          slug: "password-and-description",
          name: "password-and-description",
          fields: []
        )
      ]).setFailureType(to: TheError.self).eraseToAnyPublisher()
    )
    database.fetchEditViewResourceOperation.execute = always(
      Just(
        .init(
          id: "resource-id",
          type: .init(
            id: "resource-type-id",
            slug: "resource-slug",
            name: "resource type",
            fields: []
          ),
          permission: .owner,
          name: "resource name",
          url: nil,
          username: nil,
          description: nil
        )
      )
      .setFailureType(to: TheError.self)
      .eraseToAnyPublisher()
    )
    features.use(database)
    resources.loadResourceSecret = always(
      Just(
        .init(
          values: ["password": "secret"]
        )
      )
      .setFailureType(to: TheError.self)
      .eraseToAnyPublisher()
    )
    features.use(resources)
    features.use(networkClient)
    features.use(userPGPMessages)

    let feature: ResourceEditForm = testInstance()

    var result: Void?
    feature
      .editResource(.init(rawValue: "resource-id"))
      .sink(
        receiveCompletion: { completion in
          guard case .finished = completion
          else { return }
          result = Void()
        },
        receiveValue: { /* NOP */  }
      )
      .store(in: cancellables)

    XCTAssertNotNil(result)
  }

  func test_editResource_updatesResourceType_whenLoadingResourceDataSucceeds() {
    features.use(accountSession)
    database.fetchResourcesTypesOperation.execute = always(
      Just([
        .init(
          id: "password-and-description",
          slug: "password-and-description",
          name: "password-and-description",
          fields: []
        )
      ])
      .setFailureType(to: TheError.self)
      .eraseToAnyPublisher()
    )
    database.fetchEditViewResourceOperation.execute = always(
      Just(
        .init(
          id: "resource-id",
          type: .init(
            id: "resource-type-id",
            slug: "resource-slug",
            name: "resource type",
            fields: []
          ),
          permission: .owner,
          name: "resource name",
          url: nil,
          username: nil,
          description: nil
        )
      )
      .setFailureType(to: TheError.self)
      .eraseToAnyPublisher()
    )
    features.use(database)
    resources.loadResourceSecret = always(
      Just(
        .init(
          values: ["password": "secret"]
        )
      )
      .setFailureType(to: TheError.self)
      .eraseToAnyPublisher()
    )
    features.use(resources)
    features.use(networkClient)
    features.use(userPGPMessages)

    let feature: ResourceEditForm = testInstance()

    feature
      .editResource(.init(rawValue: "resource-id"))
      .sinkDrop()
      .store(in: cancellables)

    var result: ResourceType.ID?
    feature
      .resourceTypePublisher()
      .sink(
        receiveCompletion: { _ in /* NOP */ },
        receiveValue: { resourceType in
          result = resourceType.id
        }
      )
      .store(in: cancellables)

    XCTAssertEqual(result, "resource-type-id")
  }

  func test_editResource_updatesResourceFieldValues_whenLoadingResourceDataSucceeds() {
    features.use(accountSession)
    database.fetchResourcesTypesOperation.execute = always(
      Just([
        .init(
          id: "password-and-description",
          slug: "password-and-description",
          name: "password-and-description",
          fields: []
        )
      ])
      .setFailureType(to: TheError.self)
      .eraseToAnyPublisher()
    )
    database.fetchEditViewResourceOperation.execute = always(
      Just(
        .init(
          id: "resource-id",
          type: .init(
            id: "resource-type-id",
            slug: "resource-slug",
            name: "resource type",
            fields: [
              .init(
                name: "name",
                typeString: "string",
                required: true,
                encrypted: false,
                maxLength: nil
              )!
            ]
          ),
          permission: .owner,
          name: "resource name",
          url: nil,
          username: nil,
          description: nil
        )
      )
      .setFailureType(to: TheError.self)
      .eraseToAnyPublisher()
    )
    features.use(database)
    resources.loadResourceSecret = always(
      Just(
        .init(
          values: ["password": "secret"]
        )
      )
      .setFailureType(to: TheError.self)
      .eraseToAnyPublisher()
    )
    features.use(resources)
    features.use(networkClient)
    features.use(userPGPMessages)

    let feature: ResourceEditForm = testInstance()

    feature
      .editResource(.init(rawValue: "resource-id"))
      .sinkDrop()
      .store(in: cancellables)

    var result: ResourceFieldValue?
    feature
      .fieldValuePublisher(.name)
      .sink(
        receiveValue: { validatedName in
          result = validatedName.value
        }
      )
      .store(in: cancellables)

    XCTAssertEqual(result?.stringValue, "resource name")
  }

  func test_sendForm_updatesResource_whenEditingResource() {
    accountSession.statePublisher = always(
      Just(.authorized(validAccount))
        .eraseToAnyPublisher()
    )
    features.use(accountSession)
    database.fetchResourcesTypesOperation.execute = always(
      Just([
        .init(
          id: "password-and-description",
          slug: "password-and-description",
          name: "password-and-description",
          fields: []
        )
      ]).setFailureType(to: TheError.self).eraseToAnyPublisher()
    )
    database.fetchEditViewResourceOperation.execute = always(
      Just(
        .init(
          id: "resource-id",
          type: .init(
            id: "resource-type-id",
            slug: "resource-slug",
            name: "resource type",
            fields: [
              .init(
                name: "name",
                typeString: "string",
                required: true,
                encrypted: false,
                maxLength: nil
              )!
            ]
          ),
          permission: .owner,
          name: "resource name",
          url: nil,
          username: nil,
          description: nil
        )
      )
      .setFailureType(to: TheError.self)
      .eraseToAnyPublisher()
    )
    features.use(database)
    resources.loadResourceSecret = always(
      Just(
        .init(
          values: ["password": "secret"]
        )
      )
      .setFailureType(to: TheError.self)
      .eraseToAnyPublisher()
    )
    features.use(resources)
    var result: Resource.ID?
    networkClient.updateResourceRequest.execute = { variable in
      result = .init(rawValue: variable.resourceID)
      return Just(
        .init(
          header: .mock(),
          body: .init(
            resourceID: variable.resourceID
          )
        )
      )
      .setFailureType(to: TheError.self)
      .eraseToAnyPublisher()
    }
    features.use(networkClient)
    userPGPMessages.encryptMessageForResourceUsers = always(
      Just([
        ("USER_ID", "encrypted message")
      ])
      .setFailureType(to: TheError.self)
      .eraseToAnyPublisher()
    )
    features.use(userPGPMessages)

    let feature: ResourceEditForm = testInstance()

    feature
      .editResource(.init(rawValue: "resource-id"))
      .sinkDrop()
      .store(in: cancellables)

    feature
      .sendForm()
      .sinkDrop()
      .store(in: cancellables)

    XCTAssertNotNil(result)
  }

  func test_sendForm_fails_whenUpdateResourceRequestFails() {
    accountSession.statePublisher = always(
      Just(.authorized(validAccount))
        .eraseToAnyPublisher()
    )
    features.use(accountSession)
    database.fetchResourcesTypesOperation.execute = always(
      Just([
        .init(
          id: "password-and-description",
          slug: "password-and-description",
          name: "password-and-description",
          fields: []
        )
      ]).setFailureType(to: TheError.self).eraseToAnyPublisher()
    )
    database.fetchEditViewResourceOperation.execute = always(
      Just(
        .init(
          id: "resource-id",
          type: .init(
            id: "resource-type-id",
            slug: "resource-slug",
            name: "resource type",
            fields: [
              .init(
                name: "name",
                typeString: "string",
                required: true,
                encrypted: false,
                maxLength: nil
              )!
            ]
          ),
          permission: .owner,
          name: "resource name",
          url: nil,
          username: nil,
          description: nil
        )
      )
      .setFailureType(to: TheError.self)
      .eraseToAnyPublisher()
    )
    features.use(database)
    resources.loadResourceSecret = always(
      Just(
        .init(
          values: ["password": "secret"]
        )
      )
      .setFailureType(to: TheError.self)
      .eraseToAnyPublisher()
    )
    features.use(resources)
    networkClient.updateResourceRequest.execute = always(
      Fail(error: .testError())
        .eraseToAnyPublisher()
    )
    features.use(networkClient)
    userPGPMessages.encryptMessageForResourceUsers = always(
      Just([
        ("USER_ID", "encrypted message")
      ])
      .setFailureType(to: TheError.self)
      .eraseToAnyPublisher()
    )
    features.use(userPGPMessages)

    let feature: ResourceEditForm = testInstance()

    feature
      .editResource(.init(rawValue: "resource-id"))
      .sinkDrop()
      .store(in: cancellables)

    var result: TheError?
    feature
      .sendForm()
      .sink(
        receiveCompletion: { completion in
          guard case let .failure(error) = completion
          else { return }
          result = error
        },
        receiveValue: { _ in /* NOP */ }
      )
      .store(in: cancellables)

    XCTAssertEqual(result?.identifier, .testError)
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
    .init(name: "name", typeString: "string", required: true, encrypted: false, maxLength: nil)!
  ]
)

private let defaultResourceType: ResourceType = .init(
  id: "password-and-description",
  slug: "password-and-description",
  name: "password-and-description",
  fields: [
    .init(name: "name", typeString: "string", required: true, encrypted: false, maxLength: nil)!,
    .init(name: "uri", typeString: "string", required: false, encrypted: false, maxLength: nil)!,
    .init(name: "username", typeString: "string", required: false, encrypted: false, maxLength: nil)!,
    .init(name: "password", typeString: "string", required: true, encrypted: true, maxLength: nil)!,
    .init(name: "description", typeString: "string", required: false, encrypted: true, maxLength: nil)!,
  ]
)

private let validAccount: Account = .init(
  localID: .init(rawValue: UUID.test.uuidString),
  domain: "https://passbolt.dev",
  userID: "USER_ID",
  fingerprint: "FINGERPRINT"
)
