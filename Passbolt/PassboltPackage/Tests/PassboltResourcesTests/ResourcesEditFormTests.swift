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
final class ResourcesEditFormTests: FeaturesTestCase {

  override func commonPrepare() {
    super.commonPrepare()
    register(
      { $0.usePassboltResourceEditForm() },
      for: ResourceEditForm.self
    )
    self.set(
      SessionScope.self,
      context: .init(
        account: .mock_ada,
        configuration: .mock_1
      )
    )
  }

  func test_initialState_fails_whenNoResourceTypesAvailable() async throws {
    set(
      ResourceEditScope.self,
      context: .create(
        folderID: .none,
        uri: .none
      )
    )

    patch(
      \ResourceTypesFetchDatabaseOperation.execute,
      with: always([])
    )

    let feature: ResourceEditForm = try testedInstance()

    await XCTAssertError(matches: InvalidResourceType.self) {
      try await feature.state.value
    }
  }

  func test_initialState_returnsDefaultResourceType_whenAvailable() async throws {
    set(
      ResourceEditScope.self,
      context: .create(
        folderID: .none,
        uri: .none
      )
    )

    patch(
      \ResourceTypesFetchDatabaseOperation.execute,
      with: always([defaultResourceType])
    )

    let feature: ResourceEditForm = try testedInstance()

    await XCTAssertValue(equal: defaultResourceType) {
      try await feature.state.value.type
    }
  }

  func test_validatedFieldValue_returnsInvalid_whenResourceFieldUnavailable() async throws {
    set(
      ResourceEditScope.self,
      context: .create(
        folderID: .none,
        uri: .none
      )
    )

    patch(
      \ResourceTypesFetchDatabaseOperation.execute,
      with: always([defaultResourceType])
    )

    let feature: ResourceEditForm = try testedInstance()

    await XCTAssertError(matches: InvalidValue.self) {
      try await feature.state.value
        .validatedValue(forField: "unavailable")
        .validValue  // access to trigger validation error throw
    }
  }

  func test_validatedFieldValue_returnsUnknownValue_whenResourceFieldNotSet() async throws {
    set(
      ResourceEditScope.self,
      context: .create(
        folderID: .none,
        uri: .none
      )
    )

    patch(
      \ResourceTypesFetchDatabaseOperation.execute,
      with: always([defaultResourceType])
    )

    let feature: ResourceEditForm = try testedInstance()

    await XCTAssertValue(equal: .string("")) {
      try await feature.state.value
        .value(forField: "name")
    }
  }

  func test_validatedFieldValue_returnsEncryptedValue_whenResourceEncrtpedFieldNotSet() async throws {
    set(
      ResourceEditScope.self,
      context: .create(
        folderID: .none,
        uri: .none
      )
    )

    patch(
      \ResourceTypesFetchDatabaseOperation.execute,
      with: always([defaultResourceType])
    )

    let feature: ResourceEditForm = try testedInstance()

    await XCTAssertValue(equal: .string("")) {
      try await feature.state.value
        .value(forField: "password")
    }
  }

  func test_validatedFieldValue_returnsInitialValue_whenResourceFieldAvailable() async throws {
    set(
      ResourceEditScope.self,
      context: .edit(.mock_1)
    )

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

    let feature: ResourceEditForm = try testedInstance()

    await XCTAssertValue(equal: .string("Mock_1")) {
      try await feature.state.value
        .value(forField: "name")
    }
  }

  func test_resourceEdit_succeeds_whenLoadingResourceDataSucceeds() async throws {
    set(
      ResourceEditScope.self,
      context: .edit(.mock_1)
    )

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

    let feature: ResourceEditForm = try testedInstance()

    await XCTAssertNoError {
      try await feature.state.value
    }
  }

  func test_resourceEdit_fails_whenLoadingResourceDataFails() async throws {
    set(
      ResourceEditScope.self,
      context: .edit(.mock_1)
    )

    patch(
      \ResourceTypesFetchDatabaseOperation.execute,
      with: always([defaultResourceType])
    )
    patch(
      \ResourceDetails.details,
      context: .mock_1,
      with: alwaysThrow(MockIssue.error())
    )

    let feature: ResourceEditForm = try testedInstance()

    await XCTAssertError(matches: MockIssue.self) {
      try await feature.state.value
    }
  }

  func test_resourceEdit_fails_whenLoadingResourceSecretFails() async throws {
    set(
      ResourceEditScope.self,
      context: .edit(.mock_1)
    )

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
      with: alwaysThrow(MockIssue.error())
    )

    let feature: ResourceEditForm = try testedInstance()

    await XCTAssertError(matches: MockIssue.self) {
      try await feature.state.value
    }
  }

  func test_update_updatesFieldValue_whenFieldAvailable() async throws {
    set(
      ResourceEditScope.self,
      context: .edit(.mock_1)
    )

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

    let feature: ResourceEditForm = try testedInstance()
    try await feature.update(
      defaultResourceType.field(named: "name")!,
      to: .string("Updated!")
    )

    await XCTAssertValue(equal: .string("Updated!")) {
      try await feature.state.value
        .value(forField: "name")
    }
  }

  func test_update_returnsValidatedValue_whenFieldAvailable() async throws {
    set(
      ResourceEditScope.self,
      context: .edit(.mock_1)
    )

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

    let feature: ResourceEditForm = try testedInstance()

    await XCTAssertValue(equal: .string("Updated!")) {
      try await feature.update(
        defaultResourceType.field(named: "name")!,
        to: .string("Updated!")
      )
      .validValue
    }
  }

  func test_update_throws_whenFieldUnavailable() async throws {
    set(
      ResourceEditScope.self,
      context: .edit(.mock_1)
    )

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

    let feature: ResourceEditForm = try testedInstance()

    await XCTAssertError(matches: InvalidResourceData.self) {
      try await feature.update(
        .init(
          name: "Unavailable",
          content: .unknown(
            encrypted: false,
            required: true
          )
        ),
        to: .string("Updated!")
      )
    }
  }

  func test_update_throws_whenValueTypeInvalid() async throws {
    set(
      ResourceEditScope.self,
      context: .edit(.mock_1)
    )

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

    let feature: ResourceEditForm = try testedInstance()

    await XCTAssertError(matches: InvalidResourceData.self) {
      try await feature.update(
        defaultResourceType.field(named: "name")!,
        to: .encrypted
      )
    }
  }

  func test_sendForm_fails_whenLoadingOperationFails() async throws {
    set(
      ResourceEditScope.self,
      context: .create(
        folderID: .none,
        uri: .none
      )
    )

    patch(
      \ResourceTypesFetchDatabaseOperation.execute,
      with: alwaysThrow(MockIssue.error())
    )

    let feature: ResourceEditForm = try testedInstance()

    await XCTAssertError(matches: MockIssue.self) {
      try await feature.sendForm()
    }
  }

  func test_sendForm_fails_whenFieldsValidationFails() async throws {
    set(
      ResourceEditScope.self,
      context: .create(
        folderID: .none,
        uri: .none
      )
    )

    patch(
      \ResourceTypesFetchDatabaseOperation.execute,
      with: always([defaultResourceType])
    )

    let feature: ResourceEditForm = try testedInstance()

    await XCTAssertError(matches: InvalidForm.self) {
      try await feature.sendForm()
    }
  }

  func test_sendForm_fails_whenEncryptMessageForUserFails() async throws {
    set(
      ResourceEditScope.self,
      context: .create(
        folderID: .none,
        uri: .none
      )
    )

    patch(
      \ResourceTypesFetchDatabaseOperation.execute,
      with: always([defaultShrinkedResourceType])
    )
    patch(
      \UsersPGPMessages.encryptMessageForUsers,
      with: alwaysThrow(MockIssue.error())
    )

    let feature: ResourceEditForm = try testedInstance()

    try await feature.update(
      defaultShrinkedResourceType.field(named: "name")!,
      to: .string("name")
    )

    await XCTAssertError(matches: MockIssue.self) {
      try await feature.sendForm()
    }
  }

  func test_sendForm_fails_whenCreateResourceRequestFails() async throws {
    set(
      ResourceEditScope.self,
      context: .create(
        folderID: .none,
        uri: .none
      )
    )

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
            recipient: .mock_1,
            message: "encrypted-message"
          )
        ]
      )
    )
    patch(
      \ResourceCreateNetworkOperation.execute,
      with: alwaysThrow(MockIssue.error())
    )

    let feature: ResourceEditForm = try testedInstance()

    try await feature.update(
      defaultShrinkedResourceType.field(named: "name")!,
      to: .string("name")
    )

    await XCTAssertError(matches: MockIssue.self) {
      try await feature.sendForm()
    }
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
            recipient: .mock_1,
            message: "encrypted-message"
          )
        ]
      )
    )
    patch(
      \ResourceCreateNetworkOperation.execute,
      with: always(.init(resourceID: .mock_1, ownerPermissionID: .mock_1))
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
    let feature: ResourceEditForm = try testedInstance()

    try await feature.update(
      defaultShrinkedResourceType.field(named: "name")!,
      to: .string("name")
    )

    await XCTAssertValue(equal: .mock_1) {
      try await feature.sendForm()
    }
  }

  func test_resourceEdit_fails_whenFetchingResourceFromDatabaseFails() async throws {
    set(
      ResourceEditScope.self,
      context: .edit(.mock_1)
    )

    patch(
      \ResourceTypesFetchDatabaseOperation.execute,
      with: always([defaultResourceType])
    )
    patch(
      \ResourceDetails.details,
      context: .mock_1,
      with: alwaysThrow(MockIssue.error())
    )

    let feature: ResourceEditForm = try testedInstance()

    await XCTAssertError(matches: MockIssue.self) {
      try await feature.state.value
    }
  }

  func test_resourceEdit_fails_whenFetchingResourceSecretFails() async throws {
    set(
      ResourceEditScope.self,
      context: .edit(.mock_1)
    )

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

    let feature: ResourceEditForm = try testedInstance()

    await XCTAssertError(matches: MockIssue.self) {
      try await feature.state.value
    }
  }

  func test_createResource_fails_whenLoadingLocationFromDatabaseFails() async throws {
    set(
      ResourceEditScope.self,
      context: .create(
        folderID: .mock_2,
        uri: .none
      )
    )

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

    let feature: ResourceEditForm = try testedInstance()

    await XCTAssertError(matches: MockIssue.self) {
      try await feature.state.value
    }
  }

  func test_createResource_loadsLocationFromDatabase() async throws {
    set(
      ResourceEditScope.self,
      context: .create(
        folderID: .mock_2,
        uri: .none
      )
    )

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

    let feature: ResourceEditForm = try testedInstance()

    await XCTAssertValue(equal: [.mock_1, .mock_2]) {
      try await feature.state.value.path
    }
  }

  func test_createResource_usesPredefinedURL() async throws {
    set(
      ResourceEditScope.self,
      context: .create(
        folderID: .none,
        uri: "https://passbolt.com/predefined"
      )
    )

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

    let feature: ResourceEditForm = try testedInstance()

    await XCTAssertValue(equal: "https://passbolt.com/predefined") {
      try await feature.state.value.value(forField: "uri").stringValue
    }
  }

  func test_createResource_usesDefaultResourceTypeIfAble() async throws {
    set(
      ResourceEditScope.self,
      context: .create(
        folderID: .none,
        uri: "https://passbolt.com/predefined"
      )
    )

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

    let feature: ResourceEditForm = try testedInstance()

    await XCTAssertValue(equal: ResourceType.Slug.default) {
      try await feature.state.value.type.slug
    }
  }

  func test_sendForm_updatesResource_whenEditingResource() async throws {
    set(
      ResourceEditScope.self,
      context: .edit(.mock_1)
    )

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
          recipient: .mock_1,
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

    let feature: ResourceEditForm = try testedInstance()

    await XCTAssertNoError {
      try await feature.sendForm()
    }
    XCTAssertNotNil(result)
  }

  func test_sendForm_fails_whenUpdateResourceRequestFails() async throws {
    set(
      ResourceEditScope.self,
      context: .edit(.mock_1)
    )

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
          recipient: .mock_1,
          message: "encrypted-message"
        )
      ])
    )
    patch(
      \ResourceEditNetworkOperation.execute,
      with: alwaysThrow(MockIssue.error())
    )

    let feature: ResourceEditForm = try testedInstance()

    await XCTAssertError(matches: MockIssue.self) {
      try await feature.sendForm()
    }
  }

  func test_sendForm_triggersRefreshIfNeeded_whenSendingFormSucceeds() async throws {
    set(
      ResourceEditScope.self,
      context: .edit(.mock_1)
    )

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
          recipient: .mock_1,
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

    let result: UncheckedSendable<Void?> = .init(.none)
    patch(
      \SessionData.refreshIfNeeded,
      with: { () async throws in
        result.variable = Void()
      }
    )
    let feature: ResourceEditForm = try testedInstance()

    await XCTAssertNoError {
      try await feature.sendForm()
    }

    XCTAssertNotNil(result.variable)
  }
}

private let defaultShrinkedResourceType: ResourceTypeDTO = .init(
  id: .mock_1,
  slug: "password-and-description",
  name: "password-and-description-shrinked",
  fields: [
    .name
  ]
)

private let defaultResourceType: ResourceTypeDTO = .init(
  id: .mock_2,
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
