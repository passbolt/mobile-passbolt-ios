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
import Metadata
import NetworkOperations
import Resources
import Session
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
    let sessionCryptography: SessionCryptography = try features.instance()
    let resourceUpdatePreparation: ResourceUpdatePreparation = try features.instance()
    let resourceShareNetworkOperation: ResourceShareNetworkOperation = try features.instance()
    let resourceSharePreparation: ResourceSharePreparation = try features.instance()
    let resourceFolderPermissionsFetchDatabaseOperation: ResourceFolderPermissionsFetchDatabaseOperation =
      try features.instance()
    let resourceUsersIDFetchDatabaseOperation: ResourceUsersIDFetchDatabaseOperation = try features.instance()
    let formState: Variable<Resource> = .init(initial: context.editedResource)
    // Baseline for detecting secret changes. `ResourceEditingContext` guarantees the decrypted secret is present,
    // so the comparison is meaningful from the first frame.
    let initialSecret: JSON = context.editedResource.secret
    let initialTypeID: ResourceType.ID = context.editedResource.type.id
    let sessionConfigurationLoader: SessionConfigurationLoader = try features.instance()
    let passwordExpirySettingsLoader: PasswordExpirySettingsLoader = try features.instance()
    let osTime: OSTime = features.instance()
    let metadataKeysService: MetadataKeysService = try features.instance()

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
    /// - Throws: An error if the update fails
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

    /// Whether any secret field differs from the resource as loaded into the form. Compared against the form state
    /// rather than tracked per edit, since the sub-editors (password, note, OTP...) mutate this form directly
    /// without reporting the edited paths back to the screen that submits it.
    @Sendable nonisolated func isSecretEdited() -> Bool {
      let current: Resource = formState.value
      // A new resource always needs its secret sent; a type change reshapes the secret.
      return current.isLocal
        || current.type.id != initialTypeID
        || current.secret != initialSecret
    }

    /// Updates the expiry timestamp of the resource if needed based on edited fields and session configuration.
    /// - Parameter editedFields: Set of field paths that were edited
    /// - Throws: An error if session configuration loading fails or password expiry settings cannot be fetched.
    @Sendable nonisolated func updateExpiryTimestampIfNeeded(editedFields: Set<Resource.FieldPath>) async throws {
      let sessionConfiguration: SessionConfiguration = try await sessionConfigurationLoader.sessionConfiguration()
      guard sessionConfiguration.passwordExpiry.enabled
      else {
        return
      }
      let resource: Resource = formState.value
      let settings: PasswordExpirySettings = try await passwordExpirySettingsLoader.settings()
      if resource.isLocal {
        // new resource
        if settings.automaticExpiry {
          formState.mutate {
            $0.expired = settings.calculateExpiryTimestamp(from: osTime.timestamp())
          }
        }
        return
      }

      guard isSecretEdited() || editedFields.contains(where: { resource.isSecret($0) }),
        settings.automaticUpdate
      else {
        // do not update expiry date if secret is not updated or automatic update is disabled
        return
      }
      formState.mutate {
        $0.expired = settings.calculateExpiryTimestamp(from: osTime.timestamp())
      }
    }

    /// Encrypts `secret` for each user using the snapshot's public keys (which may include recipients not yet in
    /// the local database). A recipient absent from the confirmed snapshot is a hard error: silently skipping one
    /// would rotate the secret away from a valid holder, leaving them a permission they can no longer decrypt.
    @Sendable func encryptForSnapshot(
      _ secret: String,
      users: OrderedSet<User.ID>,
      snapshot: PermissionSnapshot
    ) async throws -> OrderedSet<EncryptedMessage> {
      var secrets: OrderedSet<EncryptedMessage> = .init()
      for userID: User.ID in users {
        guard let recipient: PermissionSnapshotUser = snapshot.user(userID)
        else { throw PermissionDriftDetected.error() }
        let message: ArmoredPGPMessage = try await sessionCryptography.encryptAndSignMessage(
          secret,
          recipient.publicKey
        )
        secrets.append(.init(recipient: userID, message: message))
      }
      return secrets
    }

    /// Applies the operator-confirmed permissions when editing a shared resource, in the doc's safe order:
    /// (1) remove access from recipients losing it, (2) update the resource re-encrypting the new secret for the
    /// recipients that keep access, (3) grant access to the newly-added recipients with the new secret. The
    /// operator cannot remove their own ownership here (guarded by the confirmation screen).
    @Sendable nonisolated func applyConfirmedPermissions(
      _ confirmed: OrderedSet<ResourcePermission>,
      _ snapshot: PermissionSnapshot
    ) async throws -> Resource {
      var resource: Resource = formState.value
      do {
        try resource.validate()
      }
      catch {
        throw InvalidForm.error(displayable: "resource.form.error.invalid")
      }
      resource.createMetadata()
      resource.createSecretMetadata()
      guard let resourceSecret: String = resource.secret.resourceSecretString
      else {
        throw InvalidInputData.error(message: "Invalid or missing resource secret")
      }
      let result: MetadataKeysService.KeyValidationResult = try await metadataKeysService.validatePinnedKey()
      if case .invalid(let reason) = result {
        throw
          MetadataPinnedKeyValidationError.error(
            reason: reason,
            context: .context(.message("Invalid key", details: [:]))
          )
      }
      guard let resourceID: Resource.ID = resource.id
      else {
        throw InvalidInputData.error(message: "Editing requires an existing resource")
      }

      let diff: ConfirmedPermissionsDiff = .init(
        confirmed: confirmed,
        original: snapshot.permissions
      )

      let keptUserIDs: OrderedSet<User.ID> = snapshot.recipients(of: diff.kept)
      var addedUserIDs: OrderedSet<User.ID> = snapshot.recipients(of: diff.created)
      addedUserIDs.subtract(keptUserIDs)

      // 1. Remove access from recipients losing it, before the secret changes.
      // Tracks whether anything already reached the server, so a later failure is reported as a partial
      // application rather than as a clean no-op: both the revocation and the secret rotation leave the resource
      // no longer matching the reviewed snapshot.
      var permissionsAlreadyApplied: Bool = false
      if diff.deleted.isEmpty == false {
        try await resourceShareNetworkOperation(
          .init(
            resourceID: resourceID,
            body: .init(
              newPermissions: .init(),
              updatedPermissions: .init(),
              deletedPermissions: diff.deleted.compactMap { $0.asExistingDTO(resourceID: resourceID) },
              newSecrets: .init()
            )
          )
        )
        permissionsAlreadyApplied = true
      }

      do {
        // 2. Update the resource, re-encrypting the new secret for the recipients that keep access.
        let keptSecrets: OrderedSet<EncryptedMessage> = try await encryptForSnapshot(
          resourceSecret,
          users: keptUserIDs,
          snapshot: snapshot
        )
        _ = try await resourceNetworkOperationDispatch.editResource(resource, resourceID, keptSecrets)
        // The secret is rotated from here on: whatever fails next, the resource has already moved away from the
        // snapshot the operator reviewed, so a failure must not be reported as if nothing had happened.
        permissionsAlreadyApplied = true

        // 3. Grant access to newly-added recipients (and apply level changes) with the new secret.
        if diff.created.isEmpty == false || diff.updated.isEmpty == false {
          // Granting access to someone new requires the metadata to be readable by them - the resource is already
          // shared here, but a migration may still be pending, so ensure it the same way the create flow does.
          if diff.created.isEmpty == false {
            try await resourceSharePreparation.prepareResourceForSharing(resourceID)
          }
          let addedSecrets: OrderedSet<EncryptedMessage> = try await encryptForSnapshot(
            resourceSecret,
            users: addedUserIDs,
            snapshot: snapshot
          )
          try await resourceShareNetworkOperation(
            .init(
              resourceID: resourceID,
              body: .init(
                newPermissions: diff.created.compactMap { $0.asNewDTO(resourceID: resourceID) },
                updatedPermissions: diff.updated.compactMap { $0.asExistingDTO(resourceID: resourceID) },
                deletedPermissions: .init(),
                newSecrets: addedSecrets
              )
            )
          )
        }
      }
      catch {
        // Part of the change already landed (a revocation, a rotated secret, or both), so the resource no longer
        // matches the reviewed snapshot - by our own doing, not through server-side drift. Say so, otherwise the
        // next attempt's drift check reports our own change as someone else's and hides the failure that actually
        // stopped us.
        guard permissionsAlreadyApplied
        else { throw error }
        // Bring the local database back in line with what did land before handing the error over.
        try? await sessionData.refreshIfNeeded()
        throw PermissionsPartiallyApplied.error(underlyingError: error)
      }

      try await sessionData.refreshIfNeeded()
      return resource
    }

    /// Creates the resource with the operator as its sole owner, without applying any folder permissions.
    /// The create-in-shared-folder confirmation flow calls this first, then applies the confirmed permissions
    /// via `ResourceShareConfirmation`. Metadata is created with a personal key; migration to a shared key
    /// happens later, during the share step.
    @Sendable nonisolated func createResourcePrivate() async throws -> Resource {
      var resource: Resource = formState.value

      do {
        try resource.validate()
      }
      catch {
        throw
          InvalidForm
          .error(displayable: "resource.form.error.invalid")
      }

      resource.createMetadata()
      resource.createSecretMetadata()

      guard let resourceSecret: String = resource.secret.resourceSecretString
      else {
        throw
          InvalidInputData
          .error(message: "Invalid or missing resource secret")
      }

      let result: MetadataKeysService.KeyValidationResult = try await metadataKeysService.validatePinnedKey()
      if case .invalid(let reason) = result {
        throw
          MetadataPinnedKeyValidationError.error(
            reason: reason,
            context: .context(.message("Invalid key", details: [:]))
          )
      }

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

      let createdResourceResult: ResourceCreateNetworkOperationResult =
        try await resourceNetworkOperationDispatch.createResource(
          resource,
          [ownEncryptedMessage],
          false  // never inherit folder permissions here - they are applied after confirmation
        )
      resource.id = createdResourceResult.resourceID
      // The creator is the sole owner at this point. Carrying that permission - with its identifier - on the
      // returned resource lets the confirmation step align it with the confirmed list afterwards.
      resource.permission = createdResourceResult.resource.permission
      resource.permissions = [
        .user(
          id: currentAccount.userID,
          permission: createdResourceResult.resource.permission,
          permissionID: createdResourceResult.ownerPermissionID
        )
      ]

      var createdResourceDTO: ResourceDTO = createdResourceResult.resource
      if createdResourceDTO.permissions.isEmpty {
        createdResourceDTO.permissions = [
          .userToResource(
            id: createdResourceResult.ownerPermissionID,
            userID: currentAccount.userID,
            resourceID: createdResourceResult.resourceID,
            permission: createdResourceResult.resource.permission
          )
        ]
      }
      do {
        try await sessionData.updateResource(createdResourceDTO)
      }
      catch {
        error.logged()
        do {
          try await sessionData.refreshIfNeeded()
        }
        catch {
          error.logged()
        }
      }

      // The form now stands for a resource that exists on the server. Without this the form would still look
      // local, and a further submission - the confirmation flow reopens the form after an abandoned attempt -
      // would create a second resource instead of updating this one.
      formState.mutate { (state: inout Resource) in
        state = resource
      }

      return resource
    }

    @Sendable nonisolated func sendForm() async throws -> Resource {
      var resource: Resource = formState.value
      let secretEdited: Bool = isSecretEdited()

      do {
        try resource.validate()
      }
      catch {
        throw
          InvalidForm
          .error(displayable: "resource.form.error.invalid")
      }

      resource.createMetadata()
      resource.createSecretMetadata()

      let resourceSecret: String? = resource.secret.resourceSecretString

      let result: MetadataKeysService.KeyValidationResult = try await metadataKeysService.validatePinnedKey()
      if case .invalid(let reason) = result {
        throw
          MetadataPinnedKeyValidationError.error(
            reason: reason,
            context: .context(.message("Invalid key", details: [:]))
          )
      }

      let updatedResourceDTO: ResourceDTO?

      if let resourceID: Resource.ID = resource.id {
        let encryptedSecrets: OrderedSet<EncryptedMessage>?
        if secretEdited {
          guard let resourceSecret: String = resourceSecret
          else {
            throw
              InvalidInputData
              .error(message: "Invalid or missing resource secret")
          }
          var userIDs: Array<User.ID> = try await resourceUsersIDFetchDatabaseOperation.execute(resourceID)
          userIDs.append(currentAccount.userID)
          encryptedSecrets = try await resourceUpdatePreparation.prepareSecret(userIDs.asOrderedSet(), resourceSecret)
        }
        else {
          // Metadata-only edit: the stored secret is still valid, so it is neither re-encrypted nor sent.
          encryptedSecrets = .none
        }
        let editResult: ResourceEditNetworkOperationResult =
          try await resourceNetworkOperationDispatch
          .editResource(
            resource,
            resourceID,
            encryptedSecrets
          )
        updatedResourceDTO = editResult.resource
      }
      else {
        guard let resourceSecret: String = resourceSecret
        else {
          throw
            InvalidInputData
            .error(message: "Invalid or missing resource secret")
        }

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
          // Permissions on the create response are stale after share; full refresh covers this branch.
          updatedResourceDTO = .none
        }
        else {
          // Create response omits `permissions`; synthesize the creator's own entry.
          var createdResourceDTO: ResourceDTO = createdResourceResult.resource
          if createdResourceDTO.permissions.isEmpty {
            createdResourceDTO.permissions = [
              .userToResource(
                id: createdResourceResult.ownerPermissionID,
                userID: currentAccount.userID,
                resourceID: createdResourceResult.resourceID,
                permission: createdResourceResult.resource.permission
              )
            ]
          }
          updatedResourceDTO = createdResourceDTO
        }

        resource.id = createdResourceResult.resourceID
      }

      // we don't want to fail sending form when syncing local data fails
      func refreshIgnoringError() async {
        do {
          try await sessionData.refreshIfNeeded()
        }
        catch {
          error.logged()
        }
      }

      if let dto: ResourceDTO = updatedResourceDTO {
        do {
          try await sessionData.updateResource(dto)
        }
        catch {
          // Targeted update failed; fall back to full refresh so UI is not left stale.
          error.logged()
          await refreshIgnoringError()
        }
      }
      else {
        await refreshIgnoringError()
      }
      return resource
    }

    return .init(
      state: formState.asAnyUpdatable(),
      updateField: update(_:to:),
      updateType: updateType(to:),
      validateForm: validateForm,
      validateField: validate(fieldPath:),
      sendForm: sendForm,
      createResourcePrivate: createResourcePrivate,
      applyConfirmedPermissions: applyConfirmedPermissions(_:_:),
      updateExpiryDateIfNeeded: updateExpiryTimestampIfNeeded(editedFields:),
      isSecretEdited: isSecretEdited
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

extension PasswordExpirySettings {

  fileprivate func calculateExpiryTimestamp(from now: Timestamp) -> Timestamp? {
    guard let expiryPeriodValue: Int = self.defaultExpiryPeriod else { return .none }

    let expiryPeriod: Days = .init(rawValue: Int64(expiryPeriodValue))
    return now + expiryPeriod
  }
}
