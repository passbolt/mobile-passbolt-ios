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
import NetworkOperations
import Resources
import Users

import class Foundation.JSONEncoder

// MARK: - Implementation

extension ResourceEditForm {

  @MainActor fileprivate static func load(
    features: Features,
    context: Context,
    cancellables: Cancellables
  ) throws -> Self {
    try features.ensureScope(SessionScope.self)
    try features.ensureScope(ResourceEditScope.self)
    let currentAccount: Account = try features.sessionAccount()

    let diagnostics: OSDiagnostics = features.instance()
    let asyncExecutor: AsyncExecutor = try features.instance()

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
    let formStatePublisher: AnyPublisher<Resource, Never> = formUpdates
      .updatesSequence
      .compactMap { formState.get(\.self) }
      .asPublisher()

    let initialLoading: AsyncExecutor.Execution = asyncExecutor.schedule {
      do {
        switch context {
        case .create(let parentFolderID, let url):
          let resourceTypes: Array<ResourceType> = try await resourceTypesFetchDatabaseOperation()
          guard
            let resourceType: ResourceType = resourceTypes.first(where: \.isDefault) ?? resourceTypes.first
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
          resource.uri = url.map { .string($0.rawValue) }
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

    @Sendable nonisolated func resource() async throws -> Resource {
      await initialLoading.waitForCompletion()
      if let resource: Resource = formState.get(\.self) {
        return resource
      }
      else {
        throw
          InvalidForm
          .error(displayable: "resource.form.error.invalid")
      }
    }

    @Sendable nonisolated func fieldsPublisher() -> AnyPublisher<OrderedSet<ResourceField>, Never> {
      formStatePublisher
        .map { (resource: Resource) -> OrderedSet<ResourceField> in
          resource.fields
        }
        .removeDuplicates()
        .eraseToAnyPublisher()
    }

    @Sendable nonisolated func fieldValidator(
      for property: ResourceField
    ) -> Validator<ResourceFieldValue?> {
      switch property.content {
      case let .totp(required):
        return .init { (value: ResourceFieldValue?) in
          guard let value: ResourceFieldValue
          else {
            if required {
              return .invalid(
                value,
                error: InvalidValue.null(
                  value: value,
                  displayable: "resource.form.field.error.empty"
                )
              )
            }
            else {
              return .valid(value)
            }
          }

          guard case let .otp(.totp(secret, _, digits, period)) = value
          else {
            return .invalid(
              value,
              error: InvalidValue.wrongType(
                value: value,
                displayable: "resource.from.field.error.invalid.value"
              )
            )
          }

          guard
            period > 0,
            digits >= 6,
            digits <= 8,
            !secret.isEmpty
          else {
            return .invalid(
              value,
              error: InvalidValue.invalid(
                value: value,
                displayable: "resource.form.field.error.invalid"
              )
            )
          }

          return .valid(value)
        }

      case let .string(_, required, minLength, maxLength):
        return .init { (value: ResourceFieldValue?) in
          guard let value: ResourceFieldValue
          else {
            if required {
              return .invalid(
                value,
                error: InvalidValue.null(
                  value: value,
                  displayable: "resource.form.field.error.empty"
                )
              )
            }
            else {
              return .valid(value)
            }
          }

          guard case let .string(string) = value
          else {
            return .invalid(
              value,
              error: InvalidValue.wrongType(
                value: value,
                displayable: "resource.from.field.error.invalid.value"
              )
            )
          }

          guard !string.isEmpty || !required,
            string.count >= (minLength ?? 0),
            // even if there is no requirement for max length we are limiting it with
            // some high value to prevent too big values
            string.count <= (maxLength ?? 100000)
          else {
            return .invalid(
              value,
              error: InvalidValue.invalid(
                value: value,
                displayable: "resource.form.field.error.invalid"
              )
            )
          }

          return .valid(value)
        }
      }
    }

    @Sendable nonisolated func setFieldValue(
      _ value: ResourceFieldValue,
      for field: ResourceField
    ) async throws {
      await initialLoading.waitForCompletion()
      try formState.access { (state: inout Resource?) in
        guard var resource: Resource = state
        else {
          return assertionFailure(
            "Trying to set form value before initializing"
          )
        }
        try resource.set(value, for: field)
        state = resource
        formUpdates.sendUpdate()
      }
    }

    @Sendable nonisolated func validatedFieldValuePublisher(
      for field: ResourceField
    ) -> AnyPublisher<Validated<ResourceFieldValue?>, Never> {
      let validator = fieldValidator(for: field)
      return
        formStatePublisher
        .map { (resource: Resource) -> Validated<ResourceFieldValue?> in
          validator.validate(resource.value(for: field))
        }
        .removeDuplicates { lhs, rhs in
          lhs.value == rhs.value && lhs.isValid == rhs.isValid
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
        let validator: Validator<ResourceFieldValue?> = fieldValidator(for: field)
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

      guard case .string(let resourceName) = resource.name
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
          case let .string(password) = resource.password
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
            username: resource.username?.stringValue,
            url: (resource.uri?.stringValue).flatMap(URLString.init(rawValue:)),
            description: descriptionEncrypted ? .none : resource.description?.stringValue,
            secrets: encryptedSecrets.map { (userID: $0.recipient, data: $0.message) }
          )
        )
        .resourceID

        return updatedResourceID
      }
      else {
        guard
          let ownEncryptedMessage: EncryptedMessage = try await usersPGPMessages.encryptMessageForUsers(
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
            username: resource.username?.stringValue,
            url: (resource.uri?.stringValue).flatMap(URLString.init(rawValue:)),
            description: descriptionEncrypted ? .none : resource.description?.stringValue,
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
        ResourceEditForm.self,
        load: ResourceEditForm.load(features:context:cancellables:)
      ),
      in: ResourceEditScope.self
    )
  }
}
