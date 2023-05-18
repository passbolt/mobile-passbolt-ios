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

    let formUpdates: UpdatesSequenceSource = .init()
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
        case .create(let slug, let parentFolderID, let url):
          let resourceTypes: Array<ResourceType> = try await resourceTypesFetchDatabaseOperation()
          guard let resourceType: ResourceType = resourceTypes.first(where: { $0.slug == slug })
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
          try? resource.set(
            url.map { .string($0.rawValue) },
            forField: "uri"
          )
          for field in resource.encryptedFields {
            let initialValue: ResourceFieldValue
            switch field.content {
            case .string:
              initialValue = .string("")
              
            case .totp:
              initialValue = .otp(
                .totp(
                  sharedSecret: "",
                  algorithm: .sha1,
                  digits: 6,
                  period: 30
                )
              )
              
            case .unknown:
              initialValue = .unknown(.null)
            }
            // put default values into the secret
            try resource
              .set(
                initialValue,
                for: field
              )
          }
          formState.set(\.self, resource)
          formUpdates.sendUpdate()

        case .edit(let resourceID):
          let resourceDetails: ResourceDetails = try await features.instance(context: resourceID)
          var editedResource = try await resourceDetails.details()
          let resourceSecret: ResourceSecret = try await resourceDetails.secret()
          for field in editedResource.encryptedFields {
            // put all values from secret into the resource
            try editedResource
              .set(
                resourceSecret
                  .value(for: field),
                for: field
              )
          }
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
      .updatesSequence
      .compactMap {
        await initialLoading.waitForCompletion()
        return formState.get(\.self)
      }
      .asPublisher()

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

    @Sendable nonisolated func fieldsPublisher() -> AnyPublisher<OrderedSet<ResourceField>, Never> {
      formStatePublisher
        .map(\.fields)
        .removeDuplicates()
        .eraseToAnyPublisher()
    }

    @Sendable nonisolated func setFieldValue(
      _ value: ResourceFieldValue,
      for field: ResourceField
    ) async throws {
      await initialLoading.waitForCompletion()
      try formState.access { (state: inout Resource?) in
        try state?.set(value, for: field)
      }
      formUpdates.sendUpdate()
    }

    @Sendable nonisolated func validatedFieldValuePublisher(
      for field: ResourceField
    ) -> AnyPublisher<Validated<ResourceFieldValue?>, Never> {
      let validator: Validator<ResourceFieldValue?> = field.validator
      return
        formStatePublisher
        .map { (resource: Resource) -> ResourceFieldValue? in
          resource.value(for: field)
        }
        .removeDuplicates()
        .map { (fieldValue: ResourceFieldValue?) -> Validated<ResourceFieldValue?> in
          validator.validate(fieldValue)
        }
        .replaceError(
          with: .invalid(
            .none,
            error: InvalidValue.alwaysInvalid(
              value: ResourceFieldValue?.none,
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

      for field in resource.type.fields {
        let validator: Validator<ResourceFieldValue?> = field.validator
        let validated: Validated<ResourceFieldValue?> = validator.validate(resource.value(for: field))
        if let _: Error = validated.error {
          throw
            InvalidForm
            .error(displayable: "resource.form.error.invalid")
        }
        else {
          continue
        }
      }

      guard case .string(let resourceName) = resource.value(forField: "name")
      else {
        throw
          InvalidInputData
          .error(message: "Missing resource name")
      }

      let secretFields = resource.encryptedFields
      let descriptionEncrypted: Bool = secretFields.contains(where: { $0.name == "description" })
      let encodedSecret: String
      do {
        if secretFields.count == 1,
          case let .string(password) = resource.value(forField: "password")
        {
          encodedSecret = password
        }
        else {
          var secretFieldsValues: Dictionary<String, ResourceFieldValue> = .init()

          for field: ResourceField in secretFields {
            secretFieldsValues[field.name] = resource.value(for: field)
          }

          guard let secretString: String = try? String(data: JSONEncoder().encode(secretFieldsValues), encoding: .utf8)
          else {
            throw
              InvalidInputData
              .error(message: "Failed to encode resource secret")
          }

          encodedSecret = secretString
        }
      }
      catch {
        throw
          InvalidResourceData
          .error(underlyingError: error)
      }

      if let resourceID: Resource.ID = resource.id {
        let encryptedSecrets: OrderedSet<EncryptedMessage> =
          try await usersPGPMessages
          .encryptMessageForResourceUsers(resourceID, encodedSecret)

        let updatedResourceID: Resource.ID = try await resourceEditNetworkOperation(
          .init(
            resourceID: resourceID,
            resourceTypeID: resource.type.id,
            parentFolderID: resource.parentFolderID,
            name: resourceName,
            username: resource.value(forField: "username")?.stringValue,
            url: (resource.value(forField: "uri")?.stringValue).flatMap(URLString.init(rawValue:)),
            description: descriptionEncrypted ? .none : resource.value(forField: "description")?.stringValue,
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
              encodedSecret
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
            username: resource.value(forField: "username")?.stringValue,
            url: (resource.value(forField: "uri")?.stringValue).flatMap(URLString.init(rawValue:)),
            description: descriptionEncrypted ? .none : resource.value(forField: "description")?.stringValue,
            secrets: [ownEncryptedMessage]
          )
        )

        if let folderID: ResourceFolder.ID = resource.parentFolderID {
          let encryptedSecrets: OrderedSet<EncryptedMessage> =
            try await usersPGPMessages
            .encryptMessageForResourceFolderUsers(folderID, encodedSecret)
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
      updates: formUpdates.updatesSequence,
      resource: resource,
      fieldsPublisher: fieldsPublisher,
      setFieldValue: setFieldValue(_:for:),
      validatedFieldValuePublisher: validatedFieldValuePublisher(for:),
      sendForm: sendForm
    )
  }
}

extension FeaturesRegistry {

  internal mutating func usePassboltResourceEditForm() {
    self.use(
      .lazyLoaded(
        LegacyResourceEditForm.self,
        load: LegacyResourceEditForm.load(features:cancellables:)
      ),
      in: ResourceEditScope.self
    )
  }
}
