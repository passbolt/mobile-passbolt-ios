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
import SessionData
import TestExtensions
import Users
import XCTest

@testable import Accounts
@testable import PassboltResources
@testable import Resources

// swift-format-ignore: AlwaysUseLowerCamelCase, NeverUseImplicitlyUnwrappedOptionals
final class ResourcesEditFormTests: LoadableFeatureTestCase<LegacyResourceEditForm> {

  override class var testedImplementationScope: any FeaturesScope.Type { ResourceEditScope.self }

  override class func testedImplementationRegister(
    _ registry: inout FeaturesRegistry
  ) {
    registry.usePassboltResourceEditForm()
  }

  override func prepare() throws {
    self.set(
      SessionScope.self,
      context: .init(
        account: .mock_ada,
        configuration: .mock_1
      )
    )
    self.usePlaceholder(for: SessionData.self)
  }

  func test_resource_fails_whenNoResourceTypesAvailable() async throws {
    patch(
      \ResourceTypesFetchDatabaseOperation.execute,
      with: always([])
    )
    set(
      ResourceEditScope.self,
      context: .create(
        folderID: .none,
        uri: .none
      )
    )
    let feature: LegacyResourceEditForm = try testedInstance()

    // execute resource loading
    await self.mockExecutionControl.executeAll()

    var result: Error?
    do {
      _ = try await feature.resource()
    }
    catch {
      result = error
    }

    XCTAssertError(
      result,
      matches: InvalidForm.self
    )
  }

  func test_resource_retutnsDefaultResourceType_whenValidResourceTypeAvailable() async throws {
    patch(
      \ResourceTypesFetchDatabaseOperation.execute,
      with: always([defaultResourceType])
    )

    set(
      ResourceEditScope.self,
      context: .create(
        folderID: .none,
        uri: .none
      )
    )
    let feature: LegacyResourceEditForm = try testedInstance()

    // execute resource loading
    await self.mockExecutionControl.executeAll()

    let result: Resource = try await feature.resource()

    XCTAssert(result.type.isDefault)
  }

  func test_validatedFieldValuePublisher_returnsPublisher_whenResourceFieldNotAvailable() async throws {
    patch(
      \ResourceTypesFetchDatabaseOperation.execute,
      with: always([defaultResourceType])
    )

    set(
      ResourceEditScope.self,
      context: .create(
        folderID: .none,
        uri: .none
      )
    )
    let feature: LegacyResourceEditForm = try testedInstance()

    // execute resource loading
    await self.mockExecutionControl.executeAll()

    var result: Validated<ResourceFieldValue?>?
    feature
      .validatedFieldValuePublisher(
        .init(
          name: "unavailable",
          content: .totp(required: false)
        )
      )
      .sink(
        receiveCompletion: { _ in },
        receiveValue: { value in
          result = value
        }
      )
      .store(in: cancellables)

    // temporary wait for detached tasks
    try await Task.sleep(nanoseconds: 100 * NSEC_PER_MSEC)

    XCTAssertNotNil(result)
  }

  func test_validatedFieldValuePublisher_returnsInitiallyPublishingPublisher_whenResourceFieldAvailable() async throws {
    patch(
      \ResourceTypesFetchDatabaseOperation.execute,
      with: always([defaultResourceType])
    )

    set(
      ResourceEditScope.self,
      context: .create(
        folderID: .none,
        uri: .none
      )
    )
    let feature: LegacyResourceEditForm = try testedInstance()

    // execute resource loading
    await self.mockExecutionControl.executeAll()

    // temporary wait for detached tasks
    try await Task.sleep(nanoseconds: 100 * NSEC_PER_MSEC)

    let result: Validated<ResourceFieldValue?>? =
      try? await feature
      .validatedFieldValuePublisher(.name)
      .asAsyncValue()

    XCTAssertEqual(result?.value, .string(""))
  }

  func test_validatedFieldValuePublisher_returnsPublisherPublishingChages_whenResourceFieldValueChanges() async throws {
    patch(
      \ResourceTypesFetchDatabaseOperation.execute,
      with: always([defaultResourceType])
    )

    set(
      ResourceEditScope.self,
      context: .create(
        folderID: .none,
        uri: .none
      )
    )
    let feature: LegacyResourceEditForm = try testedInstance()

    // execute resource loading
    await self.mockExecutionControl.executeAll()

    var result: Validated<ResourceFieldValue?>?
    feature
      .validatedFieldValuePublisher(.name)
      .sink(
        receiveCompletion: { _ in },
        receiveValue: { value in
          result = value
        }
      )
      .store(in: cancellables)

    try await feature
      .setFieldValue(.string("updated"), .name)

    // temporary wait for detached tasks
    try await Task.sleep(nanoseconds: 100 * NSEC_PER_MSEC)

    XCTAssertEqual(result?.value, .string("updated"))
  }

  func test_validatedFieldValuePublisher_returnsPublisherPublishingValidatedValue_withResourceFieldValueValidation()
    async throws
  {
    patch(
      \ResourceTypesFetchDatabaseOperation.execute,
      with: always([defaultResourceType])
    )

    set(
      ResourceEditScope.self,
      context: .create(
        folderID: .none,
        uri: .none
      )
    )
    let feature: LegacyResourceEditForm = try testedInstance()

    // execute resource loading
    await self.mockExecutionControl.executeAll()

    var result: Validated<ResourceFieldValue?>?
    feature
      .validatedFieldValuePublisher(.name)
      .sink(
        receiveCompletion: { _ in },
        receiveValue: { value in
          result = value
        }
      )
      .store(in: cancellables)

    // temporary wait for detached tasks
    try await Task.sleep(nanoseconds: 100 * NSEC_PER_MSEC)

    XCTAssert(!(result?.isValid ?? false))

    try await feature
      .setFieldValue(.string("updated"), .name)

    // temporary wait for detached tasks
    try await Task.sleep(nanoseconds: 100 * NSEC_PER_MSEC)

    XCTAssert(result?.isValid ?? false)
  }

  func test_setFieldValue_fails_whenResourceFieldNotAvailable() async throws {
    patch(
      \ResourceTypesFetchDatabaseOperation.execute,
      with: always([defaultResourceType])
    )

    set(
      ResourceEditScope.self,
      context: .create(
        folderID: .none,
        uri: .none
      )
    )
    let feature: LegacyResourceEditForm = try testedInstance()

    // execute resource loading
    await self.mockExecutionControl.executeAll()

    var result: Error?
    do {
      try await feature
        .setFieldValue(.string("updated"), .init(name: "unavailable", content: .totp(required: false)))
    }
    catch {
      result = error
    }

    XCTAssertError(
      result,
      matches: InvalidResourceData.self
    )
  }

  func test_setFieldValue_succeeds_whenResourceFieldAvailable() async throws {
    patch(
      \ResourceTypesFetchDatabaseOperation.execute,
      with: always([defaultResourceType])
    )

    set(
      ResourceEditScope.self,
      context: .create(
        folderID: .none,
        uri: .none
      )
    )
    let feature: LegacyResourceEditForm = try testedInstance()

    // execute resource loading
    await self.mockExecutionControl.executeAll()

    do {
      try await feature
        .setFieldValue(.string("updated"), .name)
    }
    catch {
      XCTFail()
    }
  }

  func test_setFieldValue_fails_whenSettingInvalidValueType() async throws {
    patch(
      \ResourceTypesFetchDatabaseOperation.execute,
      with: always([defaultResourceType])
    )

    set(
      ResourceEditScope.self,
      context: .create(
        folderID: .none,
        uri: .none
      )
    )
    let feature: LegacyResourceEditForm = try testedInstance()

    // execute resource loading
    await self.mockExecutionControl.executeAll()

    var result: Error?
    do {
      try await feature
        .setFieldValue(.otp(.totp(sharedSecret: "secret", algorithm: .sha1, digits: 6, period: 30)), .name)
    }
    catch {
      result = error
    }

    XCTAssertError(result, matches: InvalidResourceData.self)
  }

  func test_sendForm_fails_whenFetchResourcesTypesOperationFails() async throws {
    patch(
      \ResourceTypesFetchDatabaseOperation.execute,
      with: alwaysThrow(MockIssue.error())
    )

    set(
      ResourceEditScope.self,
      context: .create(
        folderID: .none,
        uri: .none
      )
    )
    let feature: LegacyResourceEditForm = try testedInstance()

    // execute resource loading
    await self.mockExecutionControl.executeAll()

    var result: Error?
    do {
      _ = try await feature.sendForm()
    }
    catch {
      result = error
    }

    XCTAssertError(result, matches: InvalidForm.self)
  }

  func test_sendForm_fails_whenFieldsValidationFails() async throws {
    patch(
      \ResourceTypesFetchDatabaseOperation.execute,
      with: always([defaultResourceType])
    )

    set(
      ResourceEditScope.self,
      context: .create(
        folderID: .none,
        uri: .none
      )
    )
    let feature: LegacyResourceEditForm = try testedInstance()

    // execute resource loading
    await self.mockExecutionControl.executeAll()

    var result: Error?
    do {
      _ = try await feature.sendForm()
    }
    catch {
      result = error
    }

    XCTAssertError(result, matches: InvalidForm.self)
  }

  func test_sendForm_fails_whenEncryptMessageForUserFails() async throws {
    patch(
      \ResourceTypesFetchDatabaseOperation.execute,
      with: always([defaultShrinkedResourceType])
    )
    patch(
      \UsersPGPMessages.encryptMessageForUsers,
      with: alwaysThrow(MockIssue.error())
    )

    set(
      ResourceEditScope.self,
      context: .create(
        folderID: .none,
        uri: .none
      )
    )
    let feature: LegacyResourceEditForm = try testedInstance()

    // execute resource loading
    await self.mockExecutionControl.executeAll()

    try await feature.setFieldValue(.string("name"), .name)

    var result: Error?
    do {
      _ = try await feature.sendForm()
    }
    catch {
      result = error
    }

    XCTAssertError(result, matches: MockIssue.self)
  }

  func test_sendForm_fails_whenCreateResourceRequestFails() async throws {
    patch(
      \Session.currentAccount,
      with: always(.mock_ada)
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

    set(
      ResourceEditScope.self,
      context: .create(
        folderID: .none,
        uri: .none
      )
    )
    let feature: LegacyResourceEditForm = try testedInstance()

    // execute resource loading
    await self.mockExecutionControl.executeAll()

    try await feature.setFieldValue(.string("name"), .name)

    var result: Error?
    do {
      _ = try await feature.sendForm()
    }
    catch {
      result = error
    }

    XCTAssertError(result, matches: MockIssue.self)
  }

  func test_sendForm_succeeds_whenAllOperationsSucceed() async throws {
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
      with: always(.init(resourceID: "resource-id", ownerPermissionID: "permission-id"))
    )
    patch(
      \SessionData.refreshIfNeeded,
      with: always(Void())
    )
    set(
      ResourceEditScope.self,
      context: .create(
        folderID: .none,
        uri: .none
      )
    )
    let feature: LegacyResourceEditForm = try testedInstance()

    // execute resource loading
    await self.mockExecutionControl.executeAll()

    try await feature
      .setFieldValue(.string("name"), .name)

    let result: Resource.ID? = try await feature.sendForm()

    XCTAssertEqual(result, "resource-id")
  }

  func test_resourceEdit_fails_whenFetchingResourceFromDatabaseFails() async throws {
    patch(
      \ResourceTypesFetchDatabaseOperation.execute,
      with: always([defaultResourceType])
    )
    patch(
      \ResourceDetails.details,
      context: .mock_1,
      with: alwaysThrow(MockIssue.error())
    )

    set(
      ResourceEditScope.self,
      context: .edit(.mock_1)
    )
    let feature: LegacyResourceEditForm = try testedInstance()

    // execute resource loading
    await self.mockExecutionControl.executeAll()

    var result: Error?
    do {
      _ = try await feature.resource()
    }
    catch {
      result = error
    }

    XCTAssertError(result, matches: InvalidForm.self)
  }

  func test_resourceEdit_fails_whenFetchingResourceSecretFails() async throws {
    patch(
      \ResourceTypesFetchDatabaseOperation.execute,
      with: always([defaultResourceType])
    )
    patch(
      \ResourceDetails.details,
      context: .mock_1,
      with: alwaysThrow(MockIssue.error())
    )
    patch(
      \Resources.loadResourceSecret,
      with: always(
        Fail(error: MockIssue.error())
          .eraseToAnyPublisher()
      )
    )

    set(
      ResourceEditScope.self,
      context: .edit(.mock_1)
    )
    let feature: LegacyResourceEditForm = try testedInstance()

    // execute resource loading
    await self.mockExecutionControl.executeAll()

    var result: Error?
    do {
      _ = try await feature.resource()
    }
    catch {
      result = error
    }

    XCTAssertError(result, matches: InvalidForm.self)
  }

  func test_resourceEdit_succeeds_whenLoadingResourceDataSucceeds() async throws {
    patch(
      \ResourceTypesFetchDatabaseOperation.execute,
      with: always([defaultResourceType])
    )
    patch(
      \ResourceDetails.details,
      context: .mock_1,
      with: always(.mock_1)
    )
    patch(
      \Resources.loadResourceSecret,
      with: always(
        Just(resourceSecret)
          .eraseErrorType()
          .eraseToAnyPublisher()
      )
    )

    set(
      ResourceEditScope.self,
      context: .create(
        folderID: .none,
        uri: .none
      )
    )
    let feature: LegacyResourceEditForm = try testedInstance()

    // execute resource loading
    await self.mockExecutionControl.executeAll()

    var result: Error?
    do {
      _ = try await feature.resource()
    }
    catch {
      result = error
    }

    XCTAssertNil(result)
  }

  func test_editResource_updatesResourceFieldValues_whenLoadingResourceDataSucceeds() async throws {
    patch(
      \ResourceTypesFetchDatabaseOperation.execute,
      with: always([defaultResourceType])
    )
    patch(
      \ResourceDetails.details,
      context: .mock_1,
      with: always(.mock_1)
    )
    patch(
      \ResourceDetails.secret,
      context: .mock_1,
      with: always(resourceSecret)
    )

    set(
      ResourceEditScope.self,
      context: .edit(.mock_1)
    )
    let feature: LegacyResourceEditForm = try testedInstance()

    // execute resource loading
    await self.mockExecutionControl.executeAll()

    let result: Validated<ResourceFieldValue?> =
      try await feature
      .validatedFieldValuePublisher(.name)
      .first()
      .asAsyncValue()

    XCTAssertEqual(result, .valid(.string("Mock_1")))
  }

  func test_createResource_fails_whenLoadingLocationFromDatabaseFails() async throws {
    patch(
      \ResourceTypesFetchDatabaseOperation.execute,
      with: always([defaultResourceType])
    )
    patch(
      \ResourceFolderPathFetchDatabaseOperation.execute,
      with: alwaysThrow(MockIssue.error())
    )
    patch(
      \ResourceDetails.details,
      context: .mock_1,
      with: always(.mock_1)
    )
    patch(
      \ResourceDetails.secret,
      context: .mock_1,
      with: always(resourceSecret)
    )

    set(
      ResourceEditScope.self,
      context: .create(
        folderID: .mock_2,
        uri: .none
      )
    )
    let feature: LegacyResourceEditForm = try testedInstance()

    // execute resource loading
    await self.mockExecutionControl.executeAll()

    var result: Error?
    do {
      _ = try await feature.resource()
    }
    catch {
      result = error
    }

    XCTAssertError(result, matches: InvalidForm.self)
  }

  func test_createResource_loadsLocationFromDatabase() async throws {
    patch(
      \ResourceTypesFetchDatabaseOperation.execute,
      with: always([defaultResourceType])
    )
    patch(
      \ResourceFolderPathFetchDatabaseOperation.execute,
      with: always([.mock_1, .mock_2])
    )
    patch(
      \ResourceDetails.details,
      context: .mock_1,
      with: always(.mock_1)
    )
    patch(
      \ResourceDetails.secret,
      context: .mock_1,
      with: always(resourceSecret)
    )

    set(
      ResourceEditScope.self,
      context: .create(
        folderID: .mock_2,
        uri: .none
      )
    )
    let feature: LegacyResourceEditForm = try testedInstance()

    // execute resource loading
    await self.mockExecutionControl.executeAll()

    let result: OrderedSet<ResourceFolderPathItem>? =
      try await feature.resource().path

    XCTAssertEqual(result, [.mock_1, .mock_2])
  }

  func test_createResource_usesPredefinedURL() async throws {
    patch(
      \ResourceTypesFetchDatabaseOperation.execute,
      with: always([defaultResourceType])
    )
    patch(
      \ResourceDetails.details,
      context: .mock_1,
      with: always(.mock_1)
    )
    patch(
      \ResourceDetails.secret,
      context: .mock_1,
      with: always(resourceSecret)
    )

    set(
      ResourceEditScope.self,
      context: .create(
        folderID: .none,
        uri: "https://passbolt.com/predefined"
      )
    )
    let feature: LegacyResourceEditForm = try testedInstance()

    // execute resource loading
    await self.mockExecutionControl.executeAll()

    let result: String? =
      try await feature.resource().value(forField: "uri")?.stringValue

    XCTAssertEqual(result, "https://passbolt.com/predefined")
  }

  func test_createResource_usesDefaultResourceTypeIfAble() async throws {
    patch(
      \ResourceTypesFetchDatabaseOperation.execute,
      with: always([.mock_1, defaultResourceType, .mock_2])
    )
    patch(
      \ResourceDetails.details,
      context: .mock_1,
      with: always(.mock_1)
    )
    patch(
      \ResourceDetails.secret,
      context: .mock_1,
      with: always(resourceSecret)
    )

    set(
      ResourceEditScope.self,
      context: .create(
        folderID: .none,
        uri: "https://passbolt.com/predefined"
      )
    )
    let feature: LegacyResourceEditForm = try testedInstance()

    // execute resource loading
    await self.mockExecutionControl.executeAll()

    let result: ResourceType.Slug? =
      try await feature.resource().type.slug

    XCTAssertEqual(result, ResourceType.Slug.default)
  }

  func test_sendForm_updatesResource_whenEditingResource() async throws {
    patch(
      \ResourceTypesFetchDatabaseOperation.execute,
      with: always([defaultResourceType])
    )
    patch(
      \ResourceDetails.details,
      context: .mock_1,
      with: always(.mock_1)
    )
    patch(
      \ResourceDetails.secret,
      context: .mock_1,
      with: always(resourceSecret)
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
      \SessionData.refreshIfNeeded,
      with: always(Void())
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

    set(
      ResourceEditScope.self,
      context: .edit(.mock_1)
    )
    let feature: LegacyResourceEditForm = try testedInstance()

    // execute resource loading
    await self.mockExecutionControl.executeAll()

    do {
      _ = try await feature.sendForm()
    }
    catch {
      XCTFail("\(error)")
    }

    XCTAssertNotNil(result)
  }

  func test_sendForm_fails_whenUpdateResourceRequestFails() async throws {
    patch(
      \ResourceTypesFetchDatabaseOperation.execute,
      with: always([defaultResourceType])
    )
    patch(
      \ResourceDetails.details,
      context: .mock_1,
      with: always(.mock_1)
    )
    patch(
      \ResourceDetails.secret,
      context: .mock_1,
      with: always(resourceSecret)
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

    set(
      ResourceEditScope.self,
      context: .edit(.mock_1)
    )
    let feature: LegacyResourceEditForm = try testedInstance()

    // execute resource loading
    await self.mockExecutionControl.executeAll()

    var result: Error?
    do {
      _ = try await feature.sendForm()
    }
    catch {
      result = error
    }

    XCTAssertError(result, matches: MockIssue.self)
  }

  func test_sendForm_triggersRefreshIfNeeded_whenSendingFormSucceeds() async throws {
    patch(
      \ResourceTypesFetchDatabaseOperation.execute,
      with: always([defaultResourceType])
    )
    patch(
      \ResourceDetails.details,
      context: .mock_1,
      with: always(.mock_1)
    )
    patch(
      \ResourceDetails.secret,
      context: .mock_1,
      with: always(resourceSecret)
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
      with: { (variable) async throws in
        return .init(
          resourceID: variable.resourceID
        )
      }
    )

    set(
      ResourceEditScope.self,
      context: .edit(.mock_1)
    )
    var result: Void?
    let uncheckedSendableResult: UncheckedSendable<Void?> = .init(
      get: { result },
      set: { result = $0 }
    )
    patch(
      \SessionData.refreshIfNeeded,
      with: { () async throws in
        uncheckedSendableResult.variable = Void()
      }
    )
    let feature: LegacyResourceEditForm = try testedInstance()

    // execute resource loading
    await self.mockExecutionControl.executeAll()

    do {
      _ = try await feature.sendForm()
    }
    catch {
      XCTFail("\(error)")
    }

    XCTAssertNotNil(result)
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
    .name
  ]
)

private let defaultResourceType: ResourceTypeDTO = .init(
  id: "password-and-description",
  slug: "password-and-description",
  name: "password-and-description",
  fields: [
    .name,
    .uri,
    .username,
    .password,
    .descriptionEncrypted,
  ]
)

private let resourceSecret: ResourceSecret = try! .from(
  decrypted: #"{"password": "passbolt", "description": "encrypted"}"#,
  using: .init()
)
