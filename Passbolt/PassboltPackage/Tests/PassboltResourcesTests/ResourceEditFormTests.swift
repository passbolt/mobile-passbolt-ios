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

import TestExtensions

@testable import PassboltResources

final class ResourceEditFormTests: FeaturesTestCase {

  var editedResource: Resource = .mock_1
  lazy var editedResourceType: ResourceType = self.editedResource.type

  override func commonPrepare() {
    super.commonPrepare()
    register(
      { $0.usePassboltResourceEditForm() },
      for: ResourceEditForm.self
    )
    set(
      SessionScope.self,
      context: .init(
        account: .mock_ada,
        configuration: .mock_default
      )
    )
    set(
      ResourceEditScope.self,
      context: .init(
        editedResource: editedResource,
        availableTypes: [editedResourceType, Resource.mock_2.type]
      )
    )
  }

  func test_state_isEqualEditedResource_initially() async throws {
    let tested: ResourceEditForm = try self.testedInstance()
    await verifyIf(
      try await tested.state.value,
      isEqual: editedResource
    )
  }

  func test_state_updates_whenFormIsUpdated() async throws {
    let tested: ResourceEditForm = try self.testedInstance()
    var expectedResult: Resource = editedResource
    expectedResult.meta.name = "updated"
    expectedResult.secret.password = "modified"
    tested.update(\.meta.name, to: "updated")
    tested.update(\.secret.password, to: "modified")
    await verifyIf(
      try await tested.state.value,
      isEqual: expectedResult
    )
  }

  func test_update_ignoresMutations_whenFieldIsNotInSpecification() async throws {
    let tested: ResourceEditForm = try self.testedInstance()
    tested.update(\.meta.unknown, to: "updated")
    tested.update(\.secret.undefined, to: "modified")
    await verifyIf(
      try await tested.state.value,
      isEqual: editedResource
    )
  }

  func test_update_returnsValidatedJSON() async throws {
    let tested: ResourceEditForm = try self.testedInstance()
    let validated: Validated<JSON> = tested.update(\.meta.name, to: "updated")
    await verifyIf(
      validated,
      isEqual: .valid("updated")
    )
  }

  func test_update_returnsValidatedValue() async throws {
    let tested: ResourceEditForm = try self.testedInstance()
    let validated: Validated<String> = tested.update(\.meta.name, to: "updated")
    await verifyIf(
      validated,
      isEqual: .valid("updated")
    )
  }

  func test_update_returnsValidatedValue_withErrorIfNotValid() async throws {
    let tested: ResourceEditForm = try self.testedInstance()
    let validated: Validated<String> = tested.update(\.meta.name, to: "")

    await verifyIf(
      validated,
      isEqual: .invalid(
        "",
        error:
          InvalidResourceField
          .error(
            "required",
            specification: Resource.mock_1.type.fieldSpecification(for: \.meta.name)!,
            path: \.meta.name,
            value: "",
            displayable: .localized(
              key: "error.resource.field.empty",
              arguments: [
                Resource.mock_1.type.fieldSpecification(for: \.meta.name)!.name.displayable.string()
              ]
            )
          )
      )
    )
  }

  func test_validateForm_throws_withInvalidForm() async throws {
    let tested: ResourceEditForm = try self.testedInstance()
    tested.update(\.meta.name, to: "")

    await verifyIf(
      try await tested.validateForm(),
      throws: InvalidForm.self
    )
  }

  func test_validateForm_notThrows_withValidForm() async throws {
    let tested: ResourceEditForm = try self.testedInstance()
    await verifyIfNotThrows(
      try await tested.validateForm()
    )
  }

  func test_updateType_updatesEditedResourceTypeAndFields() async throws {
    let editedResourceType: ResourceType = .init(
      id: .mock_1,
      specification: .init(
        slug: "edited",
        metaFields: [
          .init(
            path: \.meta.name,
            name: "name",
            content: .string(),
            required: true,
            encrypted: false
          )
        ],
        secretFields: [
          .init(
            path: \.secret.message,
            name: "message",
            content: .string(),
            required: true,
            encrypted: true
          ),
          .init(
            path: \.secret.temporary,
            name: "temporary",
            content: .string(),
            required: true,
            encrypted: true
          ),
        ]
      )
    )
    let editedResource: Resource = .init(
      id: .mock_1,
      type: editedResourceType,
      permission: .owner,
      meta: [
        "name": "edited"
      ],
      secret: [
        "message": "encrypted",
        "temporary": "whatever",
      ]
    )
    let selectedResourceType: ResourceType = .init(
      id: .mock_1,
      specification: .init(
        slug: "selected",
        metaFields: [
          .init(
            path: \.meta.name,
            name: "name",
            content: .string(),
            required: true,
            encrypted: false
          ),
          .init(
            path: \.meta.uri,
            name: "uri",
            content: .string(),
            required: true,
            encrypted: false
          ),
        ],
        secretFields: [
          .init(
            path: \.secret.message,
            name: "message",
            content: .string(),
            required: true,
            encrypted: true
          ),
          .init(
            path: \.secret.extra,
            name: "extra",
            content: .string(),
            required: true,
            encrypted: true
          ),
        ]
      )
    )
    let updatedResource: Resource = .init(
      id: .mock_1,
      type: selectedResourceType,
      permission: .owner,
      meta: [
        "name": "edited",
        "uri": "new",
      ],
      secret: [
        "message": "encrypted",
        "extra": "new",
      ]
    )
    set(
      ResourceEditScope.self,
      context: .init(
        editedResource: editedResource,
        availableTypes: [editedResourceType, selectedResourceType]
      )
    )
    let tested: ResourceEditForm = try self.testedInstance()
    await verifyIfNotThrows(
      try tested.updateType(selectedResourceType)
    )
    tested.update(\.meta.uri, to: "new")
    tested.update(\.secret.extra, to: "new")
    await verifyIf(
      try await tested.state.value,
      isEqual: updatedResource
    )
  }

  func test_sendForm_throws_withInvalidForm() async throws {
    let tested: ResourceEditForm = try self.testedInstance()
    tested.update(\.meta.name, to: "")

    await verifyIf(
      try await tested.sendForm(),
      throws: InvalidForm.self
    )
  }

  func test_sendForm_throws_whenEncryptingEditedMessageFails() async throws {
    patch(
      \UsersPGPMessages.encryptMessageForResourceUsers,
      with: alwaysThrow(MockIssue.error())
    )
    let tested: ResourceEditForm = try self.testedInstance()
    await verifyIf(
      try await tested.sendForm(),
      throws: MockIssue.self
    )
  }

  func test_sendForm_throws_whenEncryptingEditedMessageProducesInvalidResult() async throws {
    patch(
      \UsersPGPMessages.encryptMessageForResourceUsers,
      with: always([])
    )
    patch(
      \ResourceUsersIDFetchDatabaseOperation.execute,
       with: always([.mock_1])
    )
    let tested: ResourceEditForm = try self.testedInstance()
    await verifyIf(
      try await tested.sendForm(),
      throws: InvalidResourceSecret.self
    )
  }

  func test_sendForm_throws_whenEditNetworkRequestFails() async throws {
    patch(
      \UsersPGPMessages.encryptMessageForResourceUsers,
      with: always([.mock_1])
    )
    patch(
      \ResourceUsersIDFetchDatabaseOperation.execute,
       with: always([.mock_1])
    )
    patch(
      \ResourceEditNetworkOperation.execute,
      with: alwaysThrow(MockIssue.error())
    )
    let tested: ResourceEditForm = try self.testedInstance()
    await verifyIf(
      try await tested.sendForm(),
      throws: MockIssue.self
    )
  }

  func test_sendForm_notThrows_whenEditingSucceeds() async throws {
    set(
      ResourceEditScope.self,
      context: .init(
        editedResource: editedResource,
        availableTypes: [editedResourceType]
      )
    )
    patch(
      \UsersPGPMessages.encryptMessageForResourceUsers,
      with: always([.mock_1])
    )
    patch(
      \ResourceUsersIDFetchDatabaseOperation.execute,
       with: always([.mock_1])
    )
    patch(
      \ResourceEditNetworkOperation.execute,
      with: always(.init(resourceID: .mock_1))
    )

    patch(  // not throws regardless of error in refresh
      \SessionData.refreshIfNeeded,
      with: alwaysThrow(MockIssue.error())
    )
    let tested: ResourceEditForm = try self.testedInstance()
    await verifyIfNotThrows(
      try await tested.sendForm()
    )
  }

  func test_sendForm_throws_whenCreateNetworkRequestFails() async throws {
    var editedResource: Resource = self.editedResource
    editedResource.id = .none
    set(
      ResourceEditScope.self,
      context: .init(
        editedResource: editedResource,
        availableTypes: [editedResourceType]
      )
    )
    patch(
      \UsersPGPMessages.encryptMessageForUsers,
      with: always([.mock_1])
    )
    patch(
      \ResourceUsersIDFetchDatabaseOperation.execute,
       with: always([.mock_1])
    )
    patch(
      \ResourceCreateNetworkOperation.execute,
      with: alwaysThrow(MockIssue.error())
    )
    let tested: ResourceEditForm = try self.testedInstance()
    await verifyIf(
      try await tested.sendForm(),
      throws: MockIssue.self
    )
  }

  func test_sendForm_throws_whenAccessingFolderPermissionsFails() async throws {
    var editedResource: Resource = self.editedResource
    editedResource.id = .none
    editedResource.path = [.mock_1]
    set(
      ResourceEditScope.self,
      context: .init(
        editedResource: editedResource,
        availableTypes: [editedResourceType]
      )
    )
    patch(
      \UsersPGPMessages.encryptMessageForUsers,
      with: always([.mock_1])
    )
    patch(
      \ResourceUsersIDFetchDatabaseOperation.execute,
       with: always([.mock_1])
    )
    patch(
      \ResourceCreateNetworkOperation.execute,
      with: always(.init(resourceID: .mock_1, ownerPermissionID: .mock_1))
    )
    patch(
      \ResourceFolderPermissionsFetchDatabaseOperation.execute,
      with: alwaysThrow(MockIssue.error())
    )
    let tested: ResourceEditForm = try self.testedInstance()
    await verifyIf(
      try await tested.sendForm(),
      throws: MockIssue.self
    )
  }

  func test_sendForm_throws_whenEncryptingSharedMessageFails() async throws {
    var editedResource: Resource = self.editedResource
    editedResource.id = .none
    editedResource.path = [.mock_1]
    set(
      ResourceEditScope.self,
      context: .init(
        editedResource: editedResource,
        availableTypes: [editedResourceType]
      )
    )
    patch(
      \UsersPGPMessages.encryptMessageForUsers,
      with: always([.mock_1])
    )
    patch(
      \ResourceCreateNetworkOperation.execute,
      with: always(.init(resourceID: .mock_1, ownerPermissionID: .mock_1))
    )
    patch(
      \ResourceFolderPermissionsFetchDatabaseOperation.execute,
      with: always([.mock_user_1_owner, .mock_user_2_owner])
    )
    patch(
      \UsersPGPMessages.encryptMessageForResourceFolderUsers,
      with: alwaysThrow(MockIssue.error())
    )
    let tested: ResourceEditForm = try self.testedInstance()
    await verifyIf(
      try await tested.sendForm(),
      throws: MockIssue.self
    )
  }

  func test_sendForm_skipsSharing_whenCreatingInFolderWithSingleUser() async throws {
    var editedResource: Resource = self.editedResource
    editedResource.id = .none
    editedResource.path = [.mock_1]
    set(
      ResourceEditScope.self,
      context: .init(
        editedResource: editedResource,
        availableTypes: [editedResourceType]
      )
    )
    patch(
      \UsersPGPMessages.encryptMessageForUsers,
      with: always([.mock_1])
    )
    patch(
      \ResourceCreateNetworkOperation.execute,
      with: always(.init(resourceID: .mock_1, ownerPermissionID: .mock_1))
    )
    patch(
      \ResourceFolderPermissionsFetchDatabaseOperation.execute,
      with: always([.mock_user_1_owner])
    )
    patch(
      \UsersPGPMessages.encryptMessageForResourceFolderUsers,
      with: { _, _ in
        self.verificationFailure("Should not be executed")
        throw MockIssue.error()
      }
    )
    patch(  // not throws regardless of error in refresh
      \SessionData.refreshIfNeeded,
      with: alwaysThrow(MockIssue.error())
    )
    let tested: ResourceEditForm = try self.testedInstance()
    await verifyIfNotThrows(
      try await tested.sendForm()
    )
  }

  func test_sendForm_throws_whenSharingFails() async throws {
    var editedResource: Resource = self.editedResource
    editedResource.id = .none
    editedResource.path = [.mock_1]
    set(
      ResourceEditScope.self,
      context: .init(
        editedResource: editedResource,
        availableTypes: [editedResourceType]
      )
    )
    patch(
      \UsersPGPMessages.encryptMessageForUsers,
      with: always([.mock_1])
    )
    patch(
      \ResourceCreateNetworkOperation.execute,
      with: always(.init(resourceID: .mock_1, ownerPermissionID: .mock_1))
    )
    patch(
      \ResourceFolderPermissionsFetchDatabaseOperation.execute,
      with: always([.mock_user_1_owner, .mock_user_2_owner])
    )
    patch(
      \UsersPGPMessages.encryptMessageForResourceFolderUsers,
      with: always([.mock_1])
    )
    patch(
      \ResourceShareNetworkOperation.execute,
      with: alwaysThrow(MockIssue.error())
    )
    patch(  // not throws regardless of error in refresh
      \SessionData.refreshIfNeeded,
      with: alwaysThrow(MockIssue.error())
    )
    let tested: ResourceEditForm = try self.testedInstance()
    await verifyIf(
      try await tested.sendForm(),
      throws: MockIssue.self
    )
  }

  func test_sendForm_changesOwnPermission_accordingToFolderPermissions() async throws {
    var editedResource: Resource = self.editedResource
    editedResource.id = .none
    editedResource.path = [.mock_1]
    set(
      ResourceEditScope.self,
      context: .init(
        editedResource: editedResource,
        availableTypes: [editedResourceType]
      )
    )
    patch(
      \UsersPGPMessages.encryptMessageForUsers,
      with: always([.mock_1])
    )
    patch(
      \ResourceCreateNetworkOperation.execute,
      with: always(.init(resourceID: .mock_1, ownerPermissionID: .mock_1))
    )
    patch(
      \ResourceFolderPermissionsFetchDatabaseOperation.execute,
      with: always([.mock_user_1_reader, .mock_user_2_owner])
    )
    patch(
      \UsersPGPMessages.encryptMessageForResourceFolderUsers,
      with: always([.mock_1])
    )
    patch(
      \ResourceShareNetworkOperation.execute,
      with: { request in
        self.verify(request.body.deletedPermissions.contains { $0.id == .mock_1 })
        self.verify(request.body.newPermissions.count == 2)
        self.verify(request.body.newSecrets.count == 1)
        throw MockIssue.error()
      }
    )
    let tested: ResourceEditForm = try self.testedInstance()
    _ = try? await tested.sendForm()
  }

  func test_sendForm_notThrows_whenCreatingSucceeds() async throws {
    var editedResource: Resource = self.editedResource
    editedResource.id = .none
    set(
      ResourceEditScope.self,
      context: .init(
        editedResource: editedResource,
        availableTypes: [editedResourceType]
      )
    )
    patch(
      \UsersPGPMessages.encryptMessageForUsers,
      with: always([.mock_1])
    )
    patch(
      \ResourceCreateNetworkOperation.execute,
      with: always(.init(resourceID: .mock_1, ownerPermissionID: .mock_1))
    )
    patch(  // not throws regardless of error in refresh
      \SessionData.refreshIfNeeded,
      with: alwaysThrow(MockIssue.error())
    )
    let tested: ResourceEditForm = try self.testedInstance()
    await verifyIfNotThrows(
      try await tested.sendForm()
    )
  }

  func test_sendForm_notThrows_whenCreatingAndSharingSucceeds() async throws {
    var editedResource: Resource = self.editedResource
    editedResource.id = .none
    editedResource.path = [.mock_1]
    set(
      ResourceEditScope.self,
      context: .init(
        editedResource: editedResource,
        availableTypes: [editedResourceType]
      )
    )
    patch(
      \UsersPGPMessages.encryptMessageForUsers,
      with: always([.mock_1])
    )
    patch(
      \ResourceCreateNetworkOperation.execute,
      with: always(.init(resourceID: .mock_1, ownerPermissionID: .mock_1))
    )
    patch(
      \ResourceFolderPermissionsFetchDatabaseOperation.execute,
      with: always([.mock_user_1_owner, .mock_user_2_owner])
    )
    patch(
      \UsersPGPMessages.encryptMessageForResourceFolderUsers,
      with: always([.mock_1])
    )
    patch(
      \ResourceShareNetworkOperation.execute,
      with: always(Void())
    )
    patch(  // not throws regardless of error in refresh
      \SessionData.refreshIfNeeded,
      with: alwaysThrow(MockIssue.error())
    )
    let tested: ResourceEditForm = try self.testedInstance()
    await verifyIfNotThrows(
      try await tested.sendForm()
    )
  }
}
