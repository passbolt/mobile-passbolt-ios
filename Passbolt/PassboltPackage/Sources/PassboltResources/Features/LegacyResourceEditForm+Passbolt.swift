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
import Features
import Foundation
import NetworkOperations
import Resources
import SessionData
import Users

import class Foundation.JSONEncoder

// MARK: - Implementation

extension LegacyResourceEditForm {

  @MainActor fileprivate static func load(
    features: Features,
    cancellables: Cancellables
  ) throws -> Self {
    try features.ensureScope(SessionScope.self)
    try features.ensureScope(ResourceEditScope.self)
    let currentAccount: Account = try features.sessionAccount()
    let context: ResourceEditScope.Context = try features.context(
      of: ResourceEditScope.self
    )

    let diagnostics: OSDiagnostics = features.instance()
    let asyncExecutor: AsyncExecutor = try features.instance()

    let sessionData: SessionData = try features.instance()
    let usersPGPMessages: UsersPGPMessages = try features.instance()
    let resourceTypesFetchDatabaseOperation: ResourceTypesFetchDatabaseOperation = try features.instance()
    let resourceEditNetworkOperation: ResourceEditNetworkOperation = try features.instance()
    let resourceCreateNetworkOperation: ResourceCreateNetworkOperation = try features.instance()
    let resourceShareNetworkOperation: ResourceShareNetworkOperation = try features.instance()
    let resourceFolderPermissionsFetchDatabaseOperation: ResourceFolderPermissionsFetchDatabaseOperation =
      try features.instance()
    let resourceFolderPathFetchDatabaseOperation: ResourceFolderPathFetchDatabaseOperation = try features.instance()

    let formUpdates: UpdatesSource = .init()
    let formState: CriticalState<Resource?> = .init(
      .none,
      cleanup: { _ in
        // make sure that executor is captured
        // and won't deallocate immediately
        asyncExecutor.cancelTasks()
      }
    )

    let initialLoading: AsyncExecutor.Execution = asyncExecutor.schedule {
      do {
        switch context {
        case .create(let slug, let parentFolderID, let uri):
          let resourceTypes: Array<ResourceType> = try await resourceTypesFetchDatabaseOperation()
          guard let resourceType: ResourceType = resourceTypes.first(where: { $0.specification.slug == slug })
          else { throw InvalidResourceType.error() }
          let folderPath: OrderedSet<ResourceFolderPathItem>
          if let parentFolderID {
            folderPath = try await resourceFolderPathFetchDatabaseOperation.execute(parentFolderID)
          }
          else {
            folderPath = .init()
          }
          var resource: Resource = .init(
            path: folderPath,
            type: resourceType
          )
          if let value: JSON = uri.map({ .string($0.rawValue) }) {
            resource.meta.uri = value
          }  // else skip
          formState.set(\.self, resource)
          formUpdates.sendUpdate()

        case .edit(let resourceID):
          let features =
            await features.branchIfNeeded(
              scope: ResourceDetailsScope.self,
              context: resourceID
            ) ?? features
          let resourceController: ResourceController = try await features.instance()
          try await resourceController.fetchSecretIfNeeded(force: true)
          let editedResource = try await resourceController.state.value
          formState.set(\.self, editedResource)
          formUpdates.sendUpdate()
        }
      }
      catch {
        diagnostics.log(error: error)
        formUpdates.sendUpdate()
      }
    }

    let formStatePublisher: AnyPublisher<Resource, Never> = formUpdates
      .updates
      .compactMap {
        await initialLoading.waitForCompletion()
        return formState.get(\.self)
      }
      .asThrowingPublisher()
      .catch { _ in
        Empty(completeImmediately: true)
          .eraseToAnyPublisher()
      }
      .eraseToAnyPublisher()

    @Sendable nonisolated func resource() async throws -> Resource {
      await initialLoading.waitForCompletion()
      if let state: Resource = formState.get(\.self) {
        return state
      }
      else {
        throw
          InvalidForm
          .error(displayable: "resource.form.error.invalid")
      }
    }

    @Sendable nonisolated func fieldsPublisher() -> AnyPublisher<OrderedSet<ResourceFieldSpecification>, Never> {
      formStatePublisher
        .map(\.allFields)
        .removeDuplicates()
        .eraseToAnyPublisher()
    }

    @Sendable nonisolated func setFieldValue(
      _ value: JSON,
      for field: Resource.FieldPath
    ) async throws {
      await initialLoading.waitForCompletion()
      formState.access { (state: inout Resource?) in
        state?[keyPath: field] = value
      }
      formUpdates.sendUpdate()
    }

    @Sendable nonisolated func validatedFieldValuePublisher(
      for field: Resource.FieldPath
    ) -> AnyPublisher<Validated<JSON>, Never> {
      return
        formStatePublisher
        .map { (resource: Resource) -> Validated<JSON> in
          resource.validator(for: field).validate(resource[keyPath: field])
        }
        .removeDuplicates()
        .replaceError(
          with: .invalid(
            .null,
            error: InvalidValue.alwaysInvalid(
              value: JSON.null,
              displayable: "error.generic"
            )
          )
        )
        .eraseToAnyPublisher()
    }

    @Sendable nonisolated func sendForm() async throws -> Resource.ID {
      await initialLoading.waitForCompletion()
      guard let resource: Resource = formState.get(\.self)
      else {
        throw
          InvalidForm
          .error(displayable: "resource.form.error.invalid")
      }

      do {
        try resource.validate()
      }
      catch {
        diagnostics.log(error: error)
        throw
          InvalidForm
          .error(displayable: "resource.form.error.invalid")
      }

      guard let resourceName: String = resource.meta.name.stringValue
      else {
        throw
          InvalidInputData
          .error(message: "Missing resource name")
      }

      guard let resourceSecret: String = resource.secret.resourceSecretString
      else {
        throw
          InvalidInputData
          .error(message: "Invalid or missing resource secret")
      }

      if let resourceID: Resource.ID = resource.id {
        let encryptedSecrets: OrderedSet<EncryptedMessage> =
          try await usersPGPMessages
          .encryptMessageForResourceUsers(resourceID, resourceSecret)

        let updatedResourceID: Resource.ID = try await resourceEditNetworkOperation(
          .init(
            resourceID: resourceID,
            resourceTypeID: resource.type.id,
            parentFolderID: resource.parentFolderID,
            name: resourceName,
            username: resource.meta.username.stringValue,
            url: (resource.meta.uri.stringValue).flatMap(URLString.init(rawValue:)),
            description: resource.meta.description.stringValue,
            secrets: encryptedSecrets.map { (userID: $0.recipient, data: $0.message) }
          )
        )
        .resourceID

        do {
          try await sessionData.refreshIfNeeded()
        }
        catch {
          // we don't want to fail sending form when refreshing data fails
          // but we would like to update data after such a change
          diagnostics.log(error: error)
        }

        return updatedResourceID
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

        let createdResourceResult = try await resourceCreateNetworkOperation(
          .init(
            resourceTypeID: resource.type.id,
            parentFolderID: resource.parentFolderID,
            name: resourceName,
            username: resource.meta.username.stringValue,
            url: (resource.meta.uri.stringValue).flatMap(URLString.init(rawValue:)),
            description: resource.meta.description.stringValue,
            secrets: [ownEncryptedMessage]
          )
        )

        if let folderID: ResourceFolder.ID = resource.parentFolderID {
          let encryptedSecrets: OrderedSet<EncryptedMessage> =
            try await usersPGPMessages
            .encryptMessageForResourceFolderUsers(folderID, resourceSecret)
            .filter { encryptedMessage in
              encryptedMessage.recipient != currentAccount.userID
            }
            .asOrderedSet()

          let folderPermissions: Array<ResourceFolderPermission> =
            try await resourceFolderPermissionsFetchDatabaseOperation(folderID)

          let newPermissions: Array<NewGenericPermissionDTO> =
            folderPermissions
            .compactMap { (permission: ResourceFolderPermission) -> NewGenericPermissionDTO? in
              switch permission {
              case let .user(id, permission, _):
                guard id != currentAccount.userID
                else { return .none }
                return .userToResource(
                  userID: id,
                  resourceID: createdResourceResult.resourceID,
                  permission: permission
                )
              case let .userGroup(id, permission, _):
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
        }  // else continue without sharing

        do {
          try await sessionData.refreshIfNeeded()
        }
        catch {
          // we don't want to fail sending form when refreshing data fails
          // but we would like to update data after such a change
          diagnostics.log(error: error)
        }

        return createdResourceResult.resourceID
      }
    }

    return Self(
      updates: formUpdates.updates,
      resource: resource,
      fieldsPublisher: fieldsPublisher,
      setFieldValue: setFieldValue(_:for:),
      validatedFieldValuePublisher: validatedFieldValuePublisher(for:),
      sendForm: sendForm
    )
  }
}

extension FeaturesRegistry {

  internal mutating func usePassboltLegacyResourceEditForm() {
    self.use(
      .lazyLoaded(
        LegacyResourceEditForm.self,
        load: LegacyResourceEditForm.load(features:cancellables:)
      ),
      in: ResourceEditScope.self
    )
  }
}
