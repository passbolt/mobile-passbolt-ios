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
import TestExtensions
import Users
import XCTest

@testable import Accounts
@testable import PassboltResources
@testable import Resources

// swift-format-ignore: AlwaysUseLowerCamelCase, NeverUseImplicitlyUnwrappedOptionals
final class ResourcesEditFormTests: LoadableFeatureTestCase<ResourceEditForm> {

  override class var testedImplementationRegister: (FeatureFactory) -> @MainActor () -> Void {
    FeatureFactory.usePassboltResourceEditForm
  }

  var cancellables: Cancellables!

  override func prepare() throws {
    self.cancellables = .init()
    use(Session.placeholder)
    use(Resources.placeholder)
    use(UsersPGPMessages.placeholder)
    use(ResourceTypesFetchDatabaseOperation.placeholder)
    use(ResourceEditDetailsFetchDatabaseOperation.placeholder)
    use(ResourceEditNetworkOperation.placeholder)
    use(ResourceCreateNetworkOperation.placeholder)
		use(ResourceShareNetworkOperation.placeholder)
		use(ResourceFolderPermissionsFetchDatabaseOperation.placeholder)
  }

  override func cleanup() throws {
    self.cancellables = .none
  }

  func test_resourceTypePublisher_fails_whenNoResourceTypesAvailable() async throws {
    patch(
      \ResourceTypesFetchDatabaseOperation.execute,
      with: always([])
    )

    let feature: ResourceEditForm = try await testedInstance()

    // temporary wait for detached tasks
    try await Task.sleep(nanoseconds: 300 * NSEC_PER_MSEC)

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
    patch(
      \ResourceTypesFetchDatabaseOperation.execute,
      with: always([emptyResourceType])
    )

    let feature: ResourceEditForm = try await testedInstance()

    // temporary wait for detached tasks
    try await Task.sleep(nanoseconds: 300 * NSEC_PER_MSEC)

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
    patch(
      \ResourceTypesFetchDatabaseOperation.execute,
      with: always([defaultResourceType])
    )

    let feature: ResourceEditForm = try await testedInstance()

    // temporary wait for detached tasks
    try await Task.sleep(nanoseconds: 300 * NSEC_PER_MSEC)

    let result: ResourceTypeDSV? =
      try? await feature
      .resourceTypePublisher()
      .asAsyncValue()

    XCTAssert(result?.isDefault ?? false)
  }

  func test_fieldValuePublisher_returnsNotPublishingPublisher_whenResourceFieldNotAvailable() async throws {
    patch(
      \ResourceTypesFetchDatabaseOperation.execute,
      with: always([defaultResourceType])
    )

    let feature: ResourceEditForm = try await testedInstance()

    // temporary wait for detached tasks
    try await Task.sleep(nanoseconds: 300 * NSEC_PER_MSEC)

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
    patch(
      \ResourceTypesFetchDatabaseOperation.execute,
      with: always([defaultResourceType])
    )

    let feature: ResourceEditForm = try await testedInstance()

    // temporary wait for detached tasks
    try await Task.sleep(nanoseconds: 300 * NSEC_PER_MSEC)

    let result: Validated<ResourceFieldValue>? =
      try? await feature
      .fieldValuePublisher(.name)
      .asAsyncValue()

    XCTAssertEqual(result?.value, .string(""))
  }

  func test_fieldValuePublisher_returnsPublisherPublishingChages_whenResourceFieldValueChanges() async throws {
    patch(
      \ResourceTypesFetchDatabaseOperation.execute,
      with: always([defaultResourceType])
    )

    let feature: ResourceEditForm = try await testedInstance()

    // temporary wait for detached tasks
    try await Task.sleep(nanoseconds: 300 * NSEC_PER_MSEC)

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
    patch(
      \ResourceTypesFetchDatabaseOperation.execute,
      with: always([defaultResourceType])
    )

    let feature: ResourceEditForm = try await testedInstance()

    // temporary wait for detached tasks
    try await Task.sleep(nanoseconds: 300 * NSEC_PER_MSEC)

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
    patch(
      \ResourceTypesFetchDatabaseOperation.execute,
      with: always([defaultResourceType])
    )

    let feature: ResourceEditForm = try await testedInstance()

    // temporary wait for detached tasks
    try await Task.sleep(nanoseconds: 300 * NSEC_PER_MSEC)

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
    patch(
      \ResourceTypesFetchDatabaseOperation.execute,
      with: always([defaultResourceType])
    )

    let feature: ResourceEditForm = try await testedInstance()

    // temporary wait for detached tasks
    try await Task.sleep(nanoseconds: 300 * NSEC_PER_MSEC)

    let result: Void? =
      try? await feature
      .setFieldValue(.string("updated"), .name)
      .asAsyncValue()

    XCTAssertNotNil(result)
  }

  func test_sendForm_fails_whenFetchResourcesTypesOperationFails() async throws {
    patch(
      \ResourceTypesFetchDatabaseOperation.execute,
      with: alwaysThrow(MockIssue.error())
    )

    let feature: ResourceEditForm = try await testedInstance()

    // temporary wait for detached tasks
    try await Task.sleep(nanoseconds: 300 * NSEC_PER_MSEC)

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
    patch(
      \ResourceTypesFetchDatabaseOperation.execute,
      with: always([defaultResourceType])
    )

    let feature: ResourceEditForm = try await testedInstance()

    // temporary wait for detached tasks
    try await Task.sleep(nanoseconds: 300 * NSEC_PER_MSEC)

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
    patch(
      \Session.currentAccount,
      with: alwaysThrow(SessionMissing.error())
    )
    patch(
      \ResourceTypesFetchDatabaseOperation.execute,
      with: always([defaultShrinkedResourceType])
    )

    let feature: ResourceEditForm = try await testedInstance()

    // temporary wait for detached tasks
    try await Task.sleep(nanoseconds: 300 * NSEC_PER_MSEC)

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
    patch(
      \Session.currentAccount,
      with: always(.valid)
    )
    patch(
      \ResourceTypesFetchDatabaseOperation.execute,
      with: always([defaultShrinkedResourceType])
    )
    patch(
      \UsersPGPMessages.encryptMessageForUsers,
      with: alwaysThrow(MockIssue.error())
    )

    let feature: ResourceEditForm = try await testedInstance()

    // temporary wait for detached tasks
    try await Task.sleep(nanoseconds: 300 * NSEC_PER_MSEC)

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
    patch(
      \Session.currentAccount,
      with: always(.valid)
    )
    patch(
      \ResourceTypesFetchDatabaseOperation.execute,
      with: always([defaultShrinkedResourceType])
    )
    patch(
      \UsersPGPMessages.encryptMessageForUsers,
      with: always(
        [
          .init(
            recipient: "USER_ID",
            message: "encrypted-message"
          )
        ]
      )
    )
    patch(
      \ResourceCreateNetworkOperation.execute,
      with: alwaysThrow(MockIssue.error())
    )

    let feature: ResourceEditForm = try await testedInstance()

    // temporary wait for detached tasks
    try await Task.sleep(nanoseconds: 300 * NSEC_PER_MSEC)

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
    patch(
      \Session.currentAccount,
      with: always(.valid)
    )
    patch(
      \ResourceTypesFetchDatabaseOperation.execute,
      with: always([defaultShrinkedResourceType])
    )
    patch(
      \UsersPGPMessages.encryptMessageForUsers,
      with: always(
        [
          .init(
            recipient: "USER_ID",
            message: "encrypted-message"
          )
        ]
      )
    )
    patch(
      \ResourceCreateNetworkOperation.execute,
      with: always(.init(resourceID: "resource-id"))
    )

    let feature: ResourceEditForm = try await testedInstance()

    // temporary wait for detached tasks
    try await Task.sleep(nanoseconds: 300 * NSEC_PER_MSEC)

    try await feature
      .setFieldValue(.string("name"), .name)
      .asAsyncValue()

    let result: Resource.ID? =
      try await feature
      .sendForm()
      .asAsyncValue()

    XCTAssertEqual(result, "resource-id")
  }

  func test_resourceEdit_fails_whenFetchingEditViewResourceFromDatabaseFails() async throws {
    patch(
      \ResourceTypesFetchDatabaseOperation.execute,
      with: always([defaultResourceType])
    )
    patch(
      \ResourceEditDetailsFetchDatabaseOperation.execute,
      with: alwaysThrow(MockIssue.error())
    )

    let feature: ResourceEditForm = try await testedInstance()

    // temporary wait for detached tasks
    try await Task.sleep(nanoseconds: 300 * NSEC_PER_MSEC)

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
    patch(
      \Resources.loadResourceSecret,
      with: always(
        Fail(error: MockIssue.error())
          .eraseToAnyPublisher()
      )
    )
    patch(
      \ResourceTypesFetchDatabaseOperation.execute,
      with: always([defaultResourceType])
    )
    patch(
      \ResourceEditDetailsFetchDatabaseOperation.execute,
      with: always(.random())
    )

    let feature: ResourceEditForm = try await testedInstance()

    // temporary wait for detached tasks
    try await Task.sleep(nanoseconds: 300 * NSEC_PER_MSEC)

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
    patch(
      \ResourceTypesFetchDatabaseOperation.execute,
      with: always([defaultResourceType])
    )
    patch(
      \ResourceEditDetailsFetchDatabaseOperation.execute,
      with: always(.random())
    )
    patch(
      \Resources.loadResourceSecret,
      with: always(
        Just(
          .init(
            rawValue: "{\"password\":\"secret\"}",
            values: ["password": "secret"]
          )
        )
        .eraseErrorType()
        .eraseToAnyPublisher()
      )
    )

    let feature: ResourceEditForm = try await testedInstance()

    // temporary wait for detached tasks
    try await Task.sleep(nanoseconds: 300 * NSEC_PER_MSEC)

    let result: Void? =
      try? await feature
      .editResource(.init(rawValue: "resource-id"))
      .asAsyncValue()

    XCTAssertNotNil(result)
  }

  func test_editResource_updatesResourceType_whenLoadingResourceDataSucceeds() async throws {
    patch(
      \ResourceTypesFetchDatabaseOperation.execute,
      with: always([resourceEditDetails.type, defaultResourceType])
    )
    patch(
      \ResourceEditDetailsFetchDatabaseOperation.execute,
      with: always(resourceEditDetails)
    )
    patch(
      \Resources.loadResourceSecret,
      with: always(
        Just(
          .init(
            rawValue: "{\"password\":\"secret\"}",
            values: ["password": "secret"]
          )
        )
        .eraseErrorType()
        .eraseToAnyPublisher()
      )
    )

    let feature: ResourceEditForm = try await testedInstance()

    // temporary wait for detached tasks
    try await Task.sleep(nanoseconds: 300 * NSEC_PER_MSEC)

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
    patch(
      \ResourceTypesFetchDatabaseOperation.execute,
      with: always([defaultResourceType])
    )
    patch(
      \ResourceEditDetailsFetchDatabaseOperation.execute,
      with: always(resourceEditDetails)
    )
    patch(
      \Resources.loadResourceSecret,
      with: always(
        Just(
          .init(
            rawValue: "{\"password\":\"secret\"}",
            values: ["password": "secret"]
          )
        )
        .eraseErrorType()
        .eraseToAnyPublisher()
      )
    )

    let feature: ResourceEditForm = try await testedInstance()

    // temporary wait for detached tasks
    try await Task.sleep(nanoseconds: 300 * NSEC_PER_MSEC)

    try? await feature
      .editResource(resourceEditDetails.id)
      .asAsyncValue()

    // temporary wait for detached tasks
    try await Task.sleep(nanoseconds: 300 * NSEC_PER_MSEC)

    let result: ResourceFieldValue? =
      try await feature
      .fieldValuePublisher(.name)
      .asAsyncValue()
      .value

    XCTAssertEqual(result?.stringValue, resourceEditDetails.name)
  }

  func test_sendForm_updatesResource_whenEditingResource() async throws {
    patch(
      \Session.currentAccount,
      with: always(.valid)
    )
    patch(
      \ResourceTypesFetchDatabaseOperation.execute,
      with: always([resourceEditDetails.type, defaultResourceType])
    )
    patch(
      \ResourceEditDetailsFetchDatabaseOperation.execute,
      with: always(resourceEditDetails)
    )
    patch(
      \Resources.loadResourceSecret,
      with: always(
        Just(
          .init(
            rawValue: "{\"password\":\"secret\"}",
            values: ["password": "secret"]
          )
        )
        .eraseErrorType()
        .eraseToAnyPublisher()
      )
    )
    patch(
      \UsersPGPMessages.encryptMessageForResourceUsers,
      with: always([
        .init(
          recipient: "USER_ID",
          message: "encrypted-message"
        )
      ])
    )
    var result: Resource.ID?
    let uncheckedSendableResult: UncheckedSendable<Resource.ID?> = .init(
      get: { result },
      set: { result = $0 }
    )
    patch(
      \ResourceEditNetworkOperation.execute,
      with: { (variable) async throws in
        uncheckedSendableResult.variable = variable.resourceID
        return .init(
          resourceID: variable.resourceID
        )
      }
    )

    let feature: ResourceEditForm = try await testedInstance()

    // temporary wait for detached tasks
    try await Task.sleep(nanoseconds: 300 * NSEC_PER_MSEC)

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
    patch(
      \Session.currentAccount,
      with: always(.valid)
    )
    patch(
      \ResourceTypesFetchDatabaseOperation.execute,
      with: always([resourceEditDetails.type])
    )
    patch(
      \ResourceEditDetailsFetchDatabaseOperation.execute,
      with: always(resourceEditDetails)
    )
    patch(
      \Resources.loadResourceSecret,
      with: always(
        Just(
          .init(
            rawValue: "{\"password\":\"secret\"}",
            values: ["password": "secret"]
          )
        )
        .eraseErrorType()
        .eraseToAnyPublisher()
      )
    )
    patch(
      \UsersPGPMessages.encryptMessageForResourceUsers,
      with: always([
        .init(
          recipient: "USER_ID",
          message: "encrypted-message"
        )
      ])
    )
    patch(
      \ResourceEditNetworkOperation.execute,
      with: alwaysThrow(MockIssue.error())
    )

    let feature: ResourceEditForm = try await testedInstance()

    // temporary wait for detached tasks
    try await Task.sleep(nanoseconds: 300 * NSEC_PER_MSEC)

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
