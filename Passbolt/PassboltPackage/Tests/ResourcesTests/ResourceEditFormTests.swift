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

import CommonModels
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
  var usersPGPMessages: UsersPGPMessages!

  override func featuresActorSetUp() async throws {
    try await super.featuresActorSetUp()
    accountSession = .placeholder
    database = .placeholder
    resources = .placeholder
    networkClient = .placeholder
    usersPGPMessages = .placeholder
  }

  override func featuresActorTearDown() async throws {
    accountSession = nil
    database = nil
    resources = nil
    networkClient = nil
    usersPGPMessages = nil
    try await super.featuresActorTearDown()
  }

  func test_resourceTypePublisher_fails_whenNoResourceTypesAvailable() async throws {
    await features.use(accountSession)
    database.fetchResourcesTypesOperation.execute = always(
      []
    )
    await features.use(database)
    await features.use(resources)
    await features.use(networkClient)
    await features.use(usersPGPMessages)

    let feature: ResourceEditForm = try await testInstance()

    // temporary wait for detached tasks
    try await Task.sleep(nanoseconds: 100 * NSEC_PER_MSEC)

    var result: Error?
    do {
      _ =
        try await feature
        .resourceTypePublisher()
        .asAsyncValue()
    }
    catch {
      result = error
    }

    XCTAssertError(
      result,
      matches: TheErrorLegacy.self,
      verification: { $0.identifier == .invalidOrMissingResourceType }
    )
  }

  func test_resourceTypePublisher_fails_whenNoValidResourceTypeAvailable() async throws {
    await features.use(accountSession)
    database.fetchResourcesTypesOperation.execute = always(
      [emptyResourceType]
    )
    await features.use(database)
    await features.use(resources)
    await features.use(networkClient)
    await features.use(usersPGPMessages)

    let feature: ResourceEditForm = try await testInstance()

    // temporary wait for detached tasks
    try await Task.sleep(nanoseconds: 100 * NSEC_PER_MSEC)

    var result: Error?
    do {
      _ =
        try await feature
        .resourceTypePublisher()
        .asAsyncValue()
    }
    catch {
      result = error
    }

    XCTAssertError(
      result,
      matches: TheErrorLegacy.self,
      verification: { $0.identifier == .invalidOrMissingResourceType }
    )
  }

  func test_resourceTypePublisher_publishesDefaultResourceType_whenValidResourceTypeAvailable() async throws {
    await features.use(accountSession)
    database.fetchResourcesTypesOperation.execute = always(
      [defaultResourceType]
    )
    await features.use(database)
    await features.use(resources)
    await features.use(networkClient)
    await features.use(usersPGPMessages)

    let feature: ResourceEditForm = try await testInstance()

    // temporary wait for detached tasks
    try await Task.sleep(nanoseconds: 100 * NSEC_PER_MSEC)

    let result: ResourceTypeDSV? =
      try? await feature
      .resourceTypePublisher()
      .asAsyncValue()

    XCTAssert(result?.isDefault ?? false)
  }

  func test_fieldValuePublisher_returnsNotPublishingPublisher_whenResourceFieldNotAvailable() async throws {
    await features.use(accountSession)
    database.fetchResourcesTypesOperation.execute = always(
      [defaultResourceType]
    )
    await features.use(database)
    await features.use(resources)
    await features.use(networkClient)
    await features.use(usersPGPMessages)

    let feature: ResourceEditForm = try await testInstance()

    // temporary wait for detached tasks
    try await Task.sleep(nanoseconds: 100 * NSEC_PER_MSEC)

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

  func test_fieldValuePublisher_returnsInitiallyPublishingPublisher_whenResourceFieldAvailable() async throws {
    await features.use(accountSession)
    database.fetchResourcesTypesOperation.execute = always(
      [defaultResourceType]
    )
    await features.use(database)
    await features.use(resources)
    await features.use(networkClient)
    await features.use(usersPGPMessages)

    let feature: ResourceEditForm = try await testInstance()

    // temporary wait for detached tasks
    try await Task.sleep(nanoseconds: 100 * NSEC_PER_MSEC)

    let result: Validated<ResourceFieldValue>? =
      try? await feature
      .fieldValuePublisher(.name)
      .asAsyncValue()

    XCTAssertEqual(result?.value, .string(""))
  }

  func test_fieldValuePublisher_returnsPublisherPublishingChages_whenResourceFieldValueChanges() async throws {
    await features.use(accountSession)
    database.fetchResourcesTypesOperation.execute = always(
      [defaultResourceType]
    )
    await features.use(database)
    await features.use(resources)
    await features.use(networkClient)
    await features.use(usersPGPMessages)

    let feature: ResourceEditForm = try await testInstance()

    // temporary wait for detached tasks
    try await Task.sleep(nanoseconds: 100 * NSEC_PER_MSEC)

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

    try? await feature
      .setFieldValue(.string("updated"), .name)
      .asAsyncValue()

    XCTAssertEqual(result?.value, .string("updated"))
  }

  func test_fieldValuePublisher_returnsPublisherPublishingValidatedValue_withResourceFieldValueValidation() async throws
  {
    await features.use(accountSession)
    database.fetchResourcesTypesOperation.execute = always(
      [defaultResourceType]
    )
    await features.use(database)
    await features.use(resources)
    await features.use(networkClient)
    await features.use(usersPGPMessages)

    let feature: ResourceEditForm = try await testInstance()

    // temporary wait for detached tasks
    try await Task.sleep(nanoseconds: 100 * NSEC_PER_MSEC)

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

    try? await feature
      .setFieldValue(.string("updated"), .name)
      .asAsyncValue()

    XCTAssert(result?.isValid ?? false)
  }

  func test_setFieldValue_fails_whenResourceFieldNotAvailable() async throws {
    await features.use(accountSession)
    database.fetchResourcesTypesOperation.execute = always(
      [defaultResourceType]
    )
    await features.use(database)
    await features.use(resources)
    await features.use(networkClient)
    await features.use(usersPGPMessages)

    let feature: ResourceEditForm = try await testInstance()

    // temporary wait for detached tasks
    try await Task.sleep(nanoseconds: 100 * NSEC_PER_MSEC)

    var result: Error?
    do {
      try await feature
        .setFieldValue(.string("updated"), .undefined(name: "unavailable"))
        .asAsyncValue()
    }
    catch {
      result = error
    }

    XCTAssertError(
      result,
      matches: TheErrorLegacy.self,
      verification: { $0.identifier == .invalidOrMissingResourceType }
    )
  }

  func test_setFieldValue_succeeds_whenResourceFieldAvailable() async throws {
    await features.use(accountSession)
    database.fetchResourcesTypesOperation.execute = always(
      [defaultResourceType]
    )
    await features.use(database)
    await features.use(resources)
    await features.use(networkClient)
    await features.use(usersPGPMessages)

    let feature: ResourceEditForm = try await testInstance()

    // temporary wait for detached tasks
    try await Task.sleep(nanoseconds: 100 * NSEC_PER_MSEC)

    let result: Void? =
      try? await feature
      .setFieldValue(.string("updated"), .name)
      .asAsyncValue()

    XCTAssertNotNil(result)
  }

  func test_sendForm_fails_whenFetchResourcesTypesOperationFails() async throws {
    await features.use(accountSession)
    database.fetchResourcesTypesOperation.execute = alwaysThrow(
      MockIssue.error()
    )
    await features.use(database)
    await features.use(resources)
    await features.use(networkClient)
    await features.use(usersPGPMessages)

    let feature: ResourceEditForm = try await testInstance()

    // temporary wait for detached tasks
    try await Task.sleep(nanoseconds: 100 * NSEC_PER_MSEC)

    var result: Error?
    do {
      _ =
        try await feature
        .sendForm()
        .asAsyncValue()
    }
    catch {
      result = error
    }

    XCTAssertError(result, matches: MockIssue.self)
  }

  func test_sendForm_fails_whenFieldsValidationFails() async throws {
    await features.use(accountSession)
    database.fetchResourcesTypesOperation.execute = always(
      [defaultShrinkedResourceType]
    )
    await features.use(database)
    await features.use(resources)
    await features.use(networkClient)
    await features.use(usersPGPMessages)

    let feature: ResourceEditForm = try await testInstance()

    // temporary wait for detached tasks
    try await Task.sleep(nanoseconds: 100 * NSEC_PER_MSEC)

    var result: Error?
    do {
      _ =
        try await feature
        .sendForm()
        .asAsyncValue()
    }
    catch {
      result = error
    }

    XCTAssertError(result, matches: InvalidForm.self)
  }

  func test_sendForm_fails_whenNoActiveUserSession() async throws {
    accountSession.currentState = always(
      .none(lastUsed: nil)
    )
    accountSession.requestAuthorizationPrompt = always(Void())
    await features.use(accountSession)
    database.fetchResourcesTypesOperation.execute = always(
      [defaultShrinkedResourceType]
    )
    await features.use(database)
    await features.use(resources)
    await features.use(networkClient)
    await features.use(usersPGPMessages)

    let feature: ResourceEditForm = try await testInstance()

    // temporary wait for detached tasks
    try await Task.sleep(nanoseconds: 100 * NSEC_PER_MSEC)

    try? await feature
      .setFieldValue(.string(name), .name)
      .asAsyncValue()

    var result: Error?
    do {
      _ =
        try await feature
        .sendForm()
        .asAsyncValue()
    }
    catch {
      result = error
    }

    XCTAssertError(result, matches: SessionMissing.self)
  }

  func test_sendForm_fails_whenEncryptMessageForUserFails() async throws {
    accountSession.currentState = always(
      .authorized(validAccount)
    )
    await features.use(accountSession)
    database.fetchResourcesTypesOperation.execute = always(
      [defaultShrinkedResourceType]
    )
    await features.use(database)
    await features.use(resources)
    await features.use(networkClient)
    usersPGPMessages.encryptMessageForUsers = alwaysThrow(
      MockIssue.error()
    )
    await features.use(usersPGPMessages)

    let feature: ResourceEditForm = try await testInstance()

    // temporary wait for detached tasks
    try await Task.sleep(nanoseconds: 100 * NSEC_PER_MSEC)

    try? await feature
      .setFieldValue(.string(name), .name)
      .asAsyncValue()

    var result: Error?
    do {
      _ =
        try await feature
        .sendForm()
        .asAsyncValue()
    }
    catch {
      result = error
    }

    XCTAssertError(result, matches: MockIssue.self)
  }

  func test_sendForm_fails_whenCreateResourceRequestFails() async throws {
    accountSession.currentState = always(
      .authorized(validAccount)
    )
    await features.use(accountSession)
    database.fetchResourcesTypesOperation.execute = always(
      [defaultShrinkedResourceType]
    )
    await features.use(database)
    await features.use(resources)
    networkClient.createResourceRequest.execute = alwaysThrow(
      MockIssue.error()
    )
    await features.use(networkClient)
    usersPGPMessages.encryptMessageForUsers = always(
      [
        .init(
          recipient: "USER_ID",
          message: "encrypted-message"
        )
      ]
    )
    await features.use(usersPGPMessages)

    let feature: ResourceEditForm = try await testInstance()

    // temporary wait for detached tasks
    try await Task.sleep(nanoseconds: 100 * NSEC_PER_MSEC)

    try? await feature
      .setFieldValue(.string("name"), .name)
      .asAsyncValue()

    var result: Error?
    do {
      _ =
        try await feature
        .sendForm()
        .asAsyncValue()
    }
    catch {
      result = error
    }

    XCTAssertError(result, matches: MockIssue.self)
  }

  func test_sendForm_succeeds_whenAllOperationsSucceed() async throws {
    accountSession.currentState = always(
      .authorized(validAccount)
    )
    await features.use(accountSession)
    database.fetchResourcesTypesOperation.execute = always(
      [defaultShrinkedResourceType]
    )
    await features.use(database)
    await features.use(resources)
    networkClient.createResourceRequest.execute = always(
      .init(
        header: .mock(),
        body: .init(resourceID: "resource-id")
      )
    )
    await features.use(networkClient)
    usersPGPMessages.encryptMessageForUsers = always(
      [
        .init(
          recipient: "USER_ID",
          message: "encrypted-message"
        )
      ]
    )
    await features.use(usersPGPMessages)

    let feature: ResourceEditForm = try await testInstance()

    // temporary wait for detached tasks
    try await Task.sleep(nanoseconds: 100 * NSEC_PER_MSEC)

    try await feature
      .setFieldValue(.string("name"), .name)
      .asAsyncValue()

    let result: Resource.ID? =
      try? await feature
      .sendForm()
      .asAsyncValue()

    XCTAssertEqual(result, "resource-id")
  }

  func test_resourceEdit_fails_whenFetchingEditViewResourceFromDatabaseFails() async throws {
    await features.use(accountSession)
    database.fetchResourcesTypesOperation.execute = always(
      [defaultResourceType]
    )
    database.fetchEditViewResourceOperation.execute = alwaysThrow(
      MockIssue.error()
    )
    await features.use(database)
    await features.use(resources)
    await features.use(networkClient)
    await features.use(usersPGPMessages)

    let feature: ResourceEditForm = try await testInstance()

    // temporary wait for detached tasks
    try await Task.sleep(nanoseconds: 100 * NSEC_PER_MSEC)

    var result: Error?
    do {
      try await feature
        .editResource(.init(rawValue: "resource-id"))
        .asAsyncValue()
    }
    catch {
      result = error
    }

    XCTAssertError(result, matches: MockIssue.self)
  }

  func test_resourceEdit_fails_whenFetchingResourceSecretFails() async throws {
    await features.use(accountSession)
    database.fetchResourcesTypesOperation.execute = always(
      [defaultResourceType]
    )
    database.fetchEditViewResourceOperation.execute = always(
      .random()
    )
    await features.use(database)
    resources.loadResourceSecret = always(
      Fail(error: MockIssue.error())
        .eraseToAnyPublisher()
    )
    await features.use(resources)
    await features.use(networkClient)
    await features.use(usersPGPMessages)

    let feature: ResourceEditForm = try await testInstance()

    // temporary wait for detached tasks
    try await Task.sleep(nanoseconds: 100 * NSEC_PER_MSEC)

    var result: Error?
    do {
      try await feature
        .editResource(.init(rawValue: "resource-id"))
        .asAsyncValue()
    }
    catch {
      result = error
    }

    XCTAssertError(result, matches: MockIssue.self)
  }

  func test_resourceEdit_succeeds_whenLoadingResourceDataSucceeds() async throws {
    await features.use(accountSession)
    database.fetchResourcesTypesOperation.execute = always(
      [defaultResourceType]
    )
    database.fetchEditViewResourceOperation.execute = always(
      .random()
    )
    await features.use(database)
    resources.loadResourceSecret = always(
      Just(
        .init(
          rawValue: "{\"password\":\"secret\"}",
          values: ["password": "secret"]
        )
      )
      .eraseErrorType()
      .eraseToAnyPublisher()
    )
    await features.use(resources)
    await features.use(networkClient)
    await features.use(usersPGPMessages)

    let feature: ResourceEditForm = try await testInstance()

    // temporary wait for detached tasks
    try await Task.sleep(nanoseconds: 100 * NSEC_PER_MSEC)

    let result: Void? =
      try? await feature
      .editResource(.init(rawValue: "resource-id"))
      .asAsyncValue()

    XCTAssertNotNil(result)
  }

  func test_editResource_updatesResourceType_whenLoadingResourceDataSucceeds() async throws {
    await features.use(accountSession)
    database.fetchResourcesTypesOperation.execute = always(
      [resourceEditDetails.type, defaultResourceType]
    )
    database.fetchEditViewResourceOperation.execute = always(
      resourceEditDetails
    )
    await features.use(database)
    resources.loadResourceSecret = always(
      Just(
        .init(
          rawValue: "{\"password\":\"secret\"}",
          values: ["password": "secret"]
        )
      )
      .eraseErrorType()
      .eraseToAnyPublisher()
    )
    await features.use(resources)
    await features.use(networkClient)
    await features.use(usersPGPMessages)

    let feature: ResourceEditForm = try await testInstance()

    // temporary wait for detached tasks
    try await Task.sleep(nanoseconds: 100 * NSEC_PER_MSEC)

    try? await feature
      .editResource(resourceEditDetails.id)
      .asAsyncValue()

    let result: ResourceType.ID? =
      try? await feature
      .resourceTypePublisher()
      .asAsyncValue()
      .id

    XCTAssertEqual(result, resourceEditDetails.type.id)
  }

  func test_editResource_updatesResourceFieldValues_whenLoadingResourceDataSucceeds() async throws {
    await features.use(accountSession)
    database.fetchResourcesTypesOperation.execute = always(
      [defaultResourceType]
    )
    database.fetchEditViewResourceOperation.execute = always(
      resourceEditDetails
    )
    await features.use(database)
    resources.loadResourceSecret = always(
      Just(
        .init(
          rawValue: "{\"password\":\"secret\"}",
          values: ["password": "secret"]
        )
      )
      .eraseErrorType()
      .eraseToAnyPublisher()
    )
    await features.use(resources)
    await features.use(networkClient)
    await features.use(usersPGPMessages)

    let feature: ResourceEditForm = try await testInstance()

    // temporary wait for detached tasks
    try await Task.sleep(nanoseconds: 100 * NSEC_PER_MSEC)

    try? await feature
      .editResource(resourceEditDetails.id)
      .asAsyncValue()

    // temporary wait for detached tasks
    try await Task.sleep(nanoseconds: 100 * NSEC_PER_MSEC)

    let result: ResourceFieldValue? =
      try await feature
      .fieldValuePublisher(.name)
      .asAsyncValue()
      .value

    XCTAssertEqual(result?.stringValue, resourceEditDetails.name)
  }

  func test_sendForm_updatesResource_whenEditingResource() async throws {
    accountSession.currentState = always(
      .authorized(validAccount)
    )
    await features.use(accountSession)
    database.fetchResourcesTypesOperation.execute = always(
      [resourceEditDetails.type, defaultResourceType]
    )
    database.fetchEditViewResourceOperation.execute = always(
      resourceEditDetails
    )
    await features.use(database)
    resources.loadResourceSecret = always(
      Just(
        .init(
          rawValue: "{\"password\":\"secret\"}",
          values: ["password": "secret"]
        )
      )
      .eraseErrorType()
      .eraseToAnyPublisher()
    )
    await features.use(resources)
    var result: Resource.ID?
    networkClient.updateResourceRequest.execute = { variable in
      result = variable.resourceID
      return .init(
        header: .mock(),
        body: .init(
          resourceID: variable.resourceID
        )
      )
    }
    await features.use(networkClient)
    usersPGPMessages.encryptMessageForResourceUsers = always(
      [
        .init(
          recipient: "USER_ID",
          message: "encrypted-message"
        )
      ]
    )
    await features.use(usersPGPMessages)

    let feature: ResourceEditForm = try await testInstance()

    // temporary wait for detached tasks
    try await Task.sleep(nanoseconds: 100 * NSEC_PER_MSEC)

    try? await feature
      .editResource(resourceEditDetails.id)
      .asAsyncValue()

    do {
      _ =
        try await feature
        .sendForm()
        .asAsyncValue()
    }
    catch {
      XCTFail("\(error)")
    }

    XCTAssertNotNil(result)
  }

  func test_sendForm_fails_whenUpdateResourceRequestFails() async throws {
    accountSession.currentState = always(
      .authorized(validAccount)
    )
    await features.use(accountSession)
    database.fetchResourcesTypesOperation.execute = always(
      [defaultResourceType, resourceEditDetails.type]
    )

    database.fetchEditViewResourceOperation.execute = always(
      resourceEditDetails
    )
    await features.use(database)
    resources.loadResourceSecret = always(
      Just(
        .init(
          rawValue: "{\"password\":\"secret\"}",
          values: ["password": "secret"]
        )
      )
      .eraseErrorType()
      .eraseToAnyPublisher()
    )
    await features.use(resources)
    networkClient.updateResourceRequest.execute = alwaysThrow(
      MockIssue.error()
    )
    await features.use(networkClient)
    usersPGPMessages.encryptMessageForResourceUsers = always(
      [
        .init(
          recipient: "USER_ID",
          message: "encrypted-message"
        )
      ]
    )
    await features.use(usersPGPMessages)

    let feature: ResourceEditForm = try await testInstance()

    // temporary wait for detached tasks
    try await Task.sleep(nanoseconds: 100 * NSEC_PER_MSEC)

    try? await feature
      .editResource(resourceEditDetails.id)
      .asAsyncValue()

    var result: Error?
    do {
      _ =
        try await feature
        .sendForm()
        .asAsyncValue()
    }
    catch {
      result = error
    }

    XCTAssertError(result, matches: MockIssue.self)
  }
}

private let emptyResourceType: ResourceTypeDTO = .init(
  id: "empty",
  slug: "empty",
  name: "empty",
  fields: []
)

private let defaultShrinkedResourceType: ResourceTypeDTO = .init(
  id: "password-and-description-shrinked",
  slug: "password-and-description",
  name: "password-and-description-shrinked",
  fields: [
    .init(name: .name, valueType: .string, required: true, encrypted: false, maxLength: nil)
  ]
)

private let defaultResourceType: ResourceTypeDTO = .init(
  id: "password-and-description",
  slug: "password-and-description",
  name: "password-and-description",
  fields: [
    .init(name: .name, valueType: .string, required: true, encrypted: false, maxLength: nil),
    .init(name: .uri, valueType: .string, required: false, encrypted: false, maxLength: nil),
    .init(name: .username, valueType: .string, required: false, encrypted: false, maxLength: nil),
    .init(name: .password, valueType: .string, required: true, encrypted: true, maxLength: nil),
    .init(name: .description, valueType: .string, required: false, encrypted: true, maxLength: nil),
  ]
)

private let validAccount: Account = .init(
  localID: .init(rawValue: UUID.test.uuidString),
  domain: "https://passbolt.dev",
  userID: "USER_ID",
  fingerprint: "FINGERPRINT"
)

private let resourceEditDetails: ResourceEditDetailsDSV = .init(
  id: "resource-id",
  type: .init(
    id: "resource-type-id",
    slug: .defaultSlug,
    name: "default",
    fields: [
      .init(
        name: .name,
        valueType: .string,
        required: true,
        encrypted: false,
        maxLength: .none
      )
    ]
  ),
  parentFolderID: .none,
  name: "resource",
  url: .none,
  username: .none,
  description: .none
)
