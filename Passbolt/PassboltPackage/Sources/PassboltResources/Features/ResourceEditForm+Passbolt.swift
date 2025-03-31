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
import DatabaseOperations
import FeatureScopes
import Features
import Foundation
import NetworkOperations
import Resources
import SessionData
import Users

// MARK: - Implementation

extension ResourceEditForm {

  @MainActor fileprivate static func load(
    features: Features
  ) throws -> Self {
    try features.ensureScope(SessionScope.self)
    try features.ensureScope(ResourceEditScope.self)
    let currentAccount: Account = try features.sessionAccount()
    let context: ResourceEditScope.Context = try features.context(
      of: ResourceEditScope.self
    )

    let sessionData: SessionData = try features.instance()
    let usersPGPMessages: UsersPGPMessages = try features.instance()
    let resourceNetworkOperationDispatch: ResourceNetworkOperationDispatch = try features.instance()
    let resourceUpdatePreparation: ResourceUpdatePreparation = try features.instance()
    let resourceShareNetworkOperation: ResourceShareNetworkOperation = try features.instance()
    let resourceFolderPermissionsFetchDatabaseOperation: ResourceFolderPermissionsFetchDatabaseOperation =
      try features.instance()
    let formState: Variable<Resource> = .init(initial: context.editedResource)

    /// Updates a specific field in the resource with a new JSON value.
    /// - Parameters:
    ///   - field: The field path to update
    ///   - value: New JSON value to set
    /// - Returns: A validation result of the update operation
    @Sendable nonisolated func update(
      _ field: Resource.FieldPath,
      to value: JSON
    ) -> Validated<JSON> {
      formState.mutate { (resource: inout Resource) -> Validated<JSON> in
        resource.update(field, to: value)
      }
    }

    /// Updates the resource type.
    /// - Parameter resourceType: The new resource type to set
    @Sendable nonisolated func updateType(
      to resourceType: ResourceType
    ) throws {
      try formState.mutate { (resource: inout Resource) throws in
        try resource.updateType(to: resourceType)
      }
    }

    /// Validates the entire resource form.
    /// - Throws: InvalidForm error if validation fails
    @Sendable nonisolated func validateForm() async throws {
      do {
        try formState.value.validate()
      }
      catch {
        throw
          InvalidForm
          .error(displayable: "resource.form.error.invalid")
      }
    }

    /// Validates a specific field in the resource.
    /// - Parameter fieldPath: The path to the field to validate
    /// - Throws: Validation error if the field value is invalid
    @Sendable nonisolated func validate(fieldPath: Resource.FieldPath) async throws {
      let resource: Resource = formState.value
      let validator: Validator<JSON> = resource.validator(for: fieldPath)
      let result: Validated<JSON> = validator.validate(resource[keyPath: fieldPath])
      if let error = result.error {
        throw error
      }
    }

    @Sendable nonisolated func sendForm() async throws -> Resource {
      var resource: Resource = formState.value

      do {
        try resource.validate()
      }
      catch {
        throw
          InvalidForm
          .error(displayable: "resource.form.error.invalid")
      }

      guard let resourceSecret: String = resource.secret.resourceSecretString
      else {
        throw
          InvalidInputData
          .error(message: "Invalid or missing resource secret")
      }

      if let resourceID: Resource.ID = resource.id {
        let encryptedSecrets = try await resourceUpdatePreparation.prepareSecret(resourceID, resourceSecret)
        _ =
          try await resourceNetworkOperationDispatch
          .editResource(
            resource,
            resourceID,
            encryptedSecrets
          )
      }
      else {
        guard
          let ownEncryptedMessage: EncryptedMessage =
            try await usersPGPMessages.encryptMessageForUsers(
              [currentAccount.userID],
              resourceSecret
            )
            .first
        else {
          throw
            UserSecretMissing
            .error()
        }

        let folderPermissions: Array<ResourceFolderPermission>
        if let folderID: ResourceFolder.ID = resource.parentFolderID {
          folderPermissions = try await resourceFolderPermissionsFetchDatabaseOperation(folderID)
        }
        else {
          folderPermissions = []
        }

        let createdResourceResult =
          try await resourceNetworkOperationDispatch
          .createResource(
            resource,
            [ownEncryptedMessage],
            folderPermissions.count > 1
          )

        // share if folder has more than a single person
        if folderPermissions.count > 1,
          let folderID: ResourceFolder.ID = resource.parentFolderID
        {

          let encryptedSecrets: OrderedSet<EncryptedMessage> =
            try await usersPGPMessages
            .encryptMessageForResourceFolderUsers(folderID, resourceSecret)
            .filter { encryptedMessage in
              encryptedMessage.recipient != currentAccount.userID
            }
            .asOrderedSet()

          let newPermissions: Array<NewGenericPermissionDTO> =
            folderPermissions
            .compactMap { (permission: ResourceFolderPermission) -> NewGenericPermissionDTO? in
              switch permission {
              case .user(let id, let permission, _):
                guard id != currentAccount.userID
                else { return .none }
                return .userToResource(
                  userID: id,
                  resourceID: createdResourceResult.resourceID,
                  permission: permission
                )
              case .userGroup(let id, let permission, _):
                return .userGroupToResource(
                  userGroupID: id,
                  resourceID: createdResourceResult.resourceID,
                  permission: permission
                )
              }
            }

          let updatedPermissions: Array<GenericPermissionDTO> =
            folderPermissions
            .compactMap { (permission: ResourceFolderPermission) -> GenericPermissionDTO? in
              if case .user(currentAccount.userID, let permission, _) = permission, permission != .owner {
                return .userToResource(
                  id: createdResourceResult.ownerPermissionID,
                  userID: currentAccount.userID,
                  resourceID: createdResourceResult.resourceID,
                  permission: permission
                )
              }
              else {
                return .none
              }
            }

          let deletedPermissions: Array<GenericPermissionDTO>
          if !folderPermissions.contains(where: { (permission: ResourceFolderPermission) -> Bool in
            if case .user(currentAccount.userID, _, _) = permission {
              return true
            }
            else {
              return false
            }
          }) {
            deletedPermissions = [
              .userToResource(
                id: createdResourceResult.ownerPermissionID,
                userID: currentAccount.userID,
                resourceID: createdResourceResult.resourceID,
                permission: .owner
              )
            ]
          }
          else {
            deletedPermissions = .init()
          }

          try await resourceShareNetworkOperation(
            .init(
              resourceID: createdResourceResult.resourceID,
              body: .init(
                newPermissions: newPermissions,
                updatedPermissions: updatedPermissions,
                deletedPermissions: deletedPermissions,
                newSecrets: encryptedSecrets
              )
            )
          )
        }

        resource.id = createdResourceResult.resourceID
      }

      do {
        try await sessionData.refreshIfNeeded()
        return resource
      }
      catch {
        // we don't want to fail sending form when refreshing data fails
        // but if we can't access updated data then it seemes to be an issue
        error.logged()
        return resource
      }
    }

    return .init(
      state: formState.asAnyUpdatable(),
      updateField: update(_:to:),
      updateType: updateType(to:),
      validateForm: validateForm,
      validateField: validate(fieldPath:),
      sendForm: sendForm
    )
  }
}

extension FeaturesRegistry {

  internal mutating func usePassboltResourceEditForm() {
    self.use(
      .lazyLoaded(
        ResourceEditForm.self,
        load: ResourceEditForm.load(features:)
      ),
      in: ResourceEditScope.self
    )
  }
}
