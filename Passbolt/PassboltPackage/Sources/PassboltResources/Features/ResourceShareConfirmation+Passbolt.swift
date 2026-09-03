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
import FeatureScopes
import Metadata
import NetworkOperations
import Resources
import Session
import SessionData

// MARK: - Implementation

extension ResourceShareConfirmation {

  @MainActor fileprivate static func load(
    features: Features
  ) throws -> Self {
    let currentAccount: Account = try features.sessionAccount()

    let sessionData: SessionData = try features.instance()
    let sessionCryptography: SessionCryptography = try features.instance()
    let resourceSharePreparation: ResourceSharePreparation = try features.instance()
    let metadataKeysService: MetadataKeysService = try features.instance()
    let permissionSnapshotService: PermissionSnapshotService = try features.instance()
    let resourceShareNetworkOperation: ResourceShareNetworkOperation = try features.instance()
    let resourceSimulateShareNetworkOperation: ResourceSimulateShareNetworkOperation = try features.instance()
    let resourceSecretFetchNetworkOperation: ResourceSecretFetchNetworkOperation = try features.instance()

    /// Re-encrypts the resource secret for the newly-added recipients using the snapshot's public keys (which may
    /// include recipients not yet present in the local database). Returns encrypted messages for the atomic share.
    @Sendable func encryptSecret(
      _ resourceID: Resource.ID,
      forAdded addedRecipients: Array<User.ID>,
      using snapshot: PermissionSnapshot
    ) async throws -> OrderedSet<EncryptedMessage> {
      guard addedRecipients.isEmpty == false
      else { return .init() }

      let encryptedSecret: ResourceSecretFetchNetworkOperationResult =
        try await resourceSecretFetchNetworkOperation(.init(resourceID: resourceID))
      let secret: String = try await sessionCryptography.decryptMessage(
        .init(rawValue: encryptedSecret.data),
        .none
      )

      var newSecrets: OrderedSet<EncryptedMessage> = .init()
      for userID: User.ID in addedRecipients {
        guard let recipient: PermissionSnapshotUser = snapshot.user(userID)
        else {
          // A recipient the confirmed snapshot never described - treat as drift defensively.
          throw PermissionDriftDetected.error()
        }
        let message: ArmoredPGPMessage = try await sessionCryptography.encryptAndSignMessage(
          secret,
          recipient.publicKey
        )
        newSecrets.append(.init(recipient: userID, message: message))
      }
      return newSecrets
    }

    /// Re-captures hand-added recipients into a fresh snapshot so the drift check covers their keys - a fresh
    /// capture only describes who already holds a permission, leaving those keys unverified otherwise.
    @Sendable nonisolated func recapturingAddedRecipients(
      of confirmed: PermissionSnapshot,
      into current: PermissionSnapshot
    ) async throws -> PermissionSnapshot {
      let missing: (users: Array<User.ID>, groups: Array<UserGroup.ID>) = confirmed.recipientsMissing(from: current)
      guard missing.users.isEmpty == false || missing.groups.isEmpty == false
      else { return current }
      return try await permissionSnapshotService.expanding(current, missing.users, missing.groups)
    }

    /// Lowers or drops the owner permission the operator was created with, so they hold exactly what the folder
    /// grants them.
    @Sendable nonisolated func applyOperatorsOwnPermission(
      resourceID: Resource.ID,
      inherits: Permission?
    ) async throws {
      let created: PermissionSnapshot = try await permissionSnapshotService.forResource(resourceID)
      guard
        let bootstrap: ResourcePermission = created.permissions
          .first(where: { (permission: ResourcePermission) -> Bool in
            permission.userID == currentAccount.userID
          })
      else { return }

      let updated: Array<GenericPermissionDTO>
      let deleted: Array<GenericPermissionDTO>
      if let level: Permission = inherits {
        guard
          let dto: GenericPermissionDTO =
            ResourcePermission
            .user(id: currentAccount.userID, permission: level, permissionID: bootstrap.permissionID)
            .asExistingDTO(resourceID: resourceID)
        else { return }
        updated = [dto]
        deleted = .init()
      }
      else {
        guard let dto: GenericPermissionDTO = bootstrap.asExistingDTO(resourceID: resourceID)
        else { return }
        updated = .init()
        deleted = [dto]
      }

      try await resourceShareNetworkOperation(
        .init(
          resourceID: resourceID,
          body: .init(
            newPermissions: .init(),
            updatedPermissions: updated,
            deletedPermissions: deleted,
            newSecrets: .init()
          )
        )
      )
    }

    @Sendable nonisolated func applyToCreatedResource(
      resourceID: Resource.ID,
      folderID: ResourceFolder.ID,
      confirmed: OrderedSet<ResourcePermission>,
      snapshot: PermissionSnapshot
    ) async throws {
      // The operator was made sole owner purely to have something to share from; the confirmed set decides what
      // they keep, settled at the end once the grants have put another owner in place.
      let grants: OrderedSet<ResourcePermission> = .init(
        confirmed.compactMap { (permission: ResourcePermission) -> ResourcePermission? in
          switch permission {
          case .user(let id, let level, _):
            guard id != currentAccount.userID
            else { return .none }
            return .user(id: id, permission: level, permissionID: .none)

          case .userGroup(let id, let level, _):
            return .userGroup(id: id, permission: level, permissionID: .none)
          }
        }
      )
      // What the operator inherits, if anything - a folder granting access only through a group leaves no row,
      // and the bootstrap permission then has to go rather than linger.
      let operatorInherits: Permission? =
        confirmed
        .first { (permission: ResourcePermission) -> Bool in permission.userID == currentAccount.userID }?
        .permission
      // Owner is what the bootstrap already is, so only anything else is a change worth sending.
      let operatorChanges: Bool = operatorInherits != .owner

      // The operator confirmed the resource exactly as it was created - private and owned by them. Nothing is
      // shared, so the metadata key is left personal and no empty share request is sent to the server.
      guard grants.isEmpty == false || operatorChanges
      else { return }

      // Migrate the freshly-created (personal-key) resource to a shared metadata key if required.
      try await resourceSharePreparation.prepareResourceForSharing(resourceID)

      // Dry-run: ask the server which recipients newly need the secret.
      let simulation: ResourceSimulateShareNetworkOperation.Output =
        try await resourceSimulateShareNetworkOperation(
          .init(
            foreignModelId: resourceID.rawValue,
            editedPermissions: grants,
            removedPermissions: .init()
          )
        )
      let addedRecipients: Array<User.ID> = simulation.changes[.added] ?? .init()

      // Drift: the folder must still match the confirmed snapshot, and every recipient the dry-run reports must
      // have been part of that snapshot. Otherwise abort - the resource stays private, owned by the operator.
      let currentFolderSnapshot: PermissionSnapshot = try await permissionSnapshotService.forFolder(folderID)
      let currentSnapshot: PermissionSnapshot = try await recapturingAddedRecipients(
        of: snapshot,
        into: currentFolderSnapshot
      )
      let folderDrift: PermissionDrift = permissionSnapshotService.drift(snapshot, currentSnapshot)
      guard folderDrift.hasDrift == false,
        permissionSnapshotService.unexpectedRecipients(snapshot, addedRecipients).isEmpty
      else {
        throw PermissionDriftDetected.error(drift: folderDrift)
      }

      // Encrypt the (existing) secret for each newly-added recipient using the snapshot's public keys.
      let newSecrets: OrderedSet<EncryptedMessage> =
        try await encryptSecret(resourceID, forAdded: addedRecipients, using: snapshot)

      // One atomic share call. The operator's own permission follows separately: the server evaluates a request
      // against the principal making it, and a self-downgrade would invalidate the rest of it.
      var appliedForOthers: Bool = false
      if grants.isEmpty == false {
        appliedForOthers = true
        try await resourceShareNetworkOperation(
          .init(
            resourceID: resourceID,
            body: .init(
              newPermissions: grants.compactMap { $0.asNewDTO(resourceID: resourceID) },
              updatedPermissions: .init(),
              deletedPermissions: .init(),
              newSecrets: newSecrets
            )
          )
        )
      }

      // Settle the bootstrap permission against what the folder actually grants the operator. Another owner is
      // in place by now, so dropping or lowering it cannot leave the resource ownerless.
      if operatorChanges {
        do {
          try await applyOperatorsOwnPermission(
            resourceID: resourceID,
            inherits: operatorInherits
          )
        }
        catch {
          guard appliedForOthers
          else { throw error }
          try? await sessionData.refreshIfNeeded()
          throw PermissionsPartiallyApplied.error(underlyingError: error)
        }
      }

      try await sessionData.refreshIfNeeded()
    }

    /// Applies the confirmed set to an existing resource - the explicit share flow.
    @Sendable nonisolated func applyToSharedResource(
      resourceID: Resource.ID,
      confirmed: OrderedSet<ResourcePermission>,
      snapshot: PermissionSnapshot
    ) async throws {
      let diff: ConfirmedPermissionsDiff = .init(
        confirmed: confirmed,
        original: snapshot.permissions
      )
      // The operator confirmed the resource exactly as it stands - nothing to send.
      guard
        diff.created.isEmpty == false
          || diff.updated.isEmpty == false
          || diff.deleted.isEmpty == false
      else { return }

      // The server rejects an ownerless resource; nothing behind the screen re-checks it.
      guard confirmed.contains(where: \.permission.isOwner)
      else { throw MissingResourceOwner.error() }

      if case .invalid(let reason) = try await metadataKeysService.validatePinnedKey() {
        throw
          MetadataPinnedKeyValidationError
          .error(
            reason: reason,
            context: .context(.message("Invalid pinned key"))
          )
      }

      // Drift before anything is written - unlike the create flow, nothing has to be sent first.
      let currentResourceSnapshot: PermissionSnapshot = try await permissionSnapshotService.forResource(resourceID)
      let currentSnapshot: PermissionSnapshot = try await recapturingAddedRecipients(
        of: snapshot,
        into: currentResourceSnapshot
      )
      let drift: PermissionDrift = permissionSnapshotService.drift(snapshot, currentSnapshot)
      guard drift.hasDrift == false
      else { throw PermissionDriftDetected.error(drift: drift) }

      // Granting access to someone new requires the metadata to be readable by them.
      if diff.created.isEmpty == false {
        try await resourceSharePreparation.prepareResourceForSharing(resourceID)
      }

      // Dry-run the intended end state: the server reports who newly needs the secret, group membership included.
      let simulation: ResourceSimulateShareNetworkOperation.Output =
        try await resourceSimulateShareNetworkOperation(
          .init(
            foreignModelId: resourceID.rawValue,
            editedPermissions: OrderedSet(Array(diff.created) + Array(diff.updated)),
            removedPermissions: diff.deleted
          )
        )
      let addedRecipients: Array<User.ID> = simulation.changes[.added] ?? .init()
      guard permissionSnapshotService.unexpectedRecipients(snapshot, addedRecipients).isEmpty
      else { throw PermissionDriftDetected.error() }

      let newSecrets: OrderedSet<EncryptedMessage> =
        try await encryptSecret(resourceID, forAdded: addedRecipients, using: snapshot)

      let isOperators: (ResourcePermission) -> Bool = { (permission: ResourcePermission) -> Bool in
        permission.userID == currentAccount.userID
      }

      let granted: Array<NewGenericPermissionDTO> = diff.created.filter { !isOperators($0) }
        .compactMap { $0.asNewDTO(resourceID: resourceID) }
      let changed: Array<GenericPermissionDTO> = diff.updated.filter { !isOperators($0) }
        .compactMap { $0.asExistingDTO(resourceID: resourceID) }
      let revoked: Array<GenericPermissionDTO> = diff.deleted.filter { !isOperators($0) }
        .compactMap { $0.asExistingDTO(resourceID: resourceID) }

      let ownCreated: Array<NewGenericPermissionDTO> = diff.created.filter(isOperators)
        .compactMap { $0.asNewDTO(resourceID: resourceID) }
      let ownUpdated: Array<GenericPermissionDTO> = diff.updated.filter(isOperators)
        .compactMap { $0.asExistingDTO(resourceID: resourceID) }
      let ownDeleted: Array<GenericPermissionDTO> = diff.deleted.filter(isOperators)
        .compactMap { $0.asExistingDTO(resourceID: resourceID) }

      // A permission the operator is *gaining* goes first: the group revoked below may be their only access,
      // and losing it would leave them unable to authorise the rest. No secret needed - they already hold one.
      var appliedForOthers: Bool = false
      if ownCreated.isEmpty == false {
        appliedForOthers = true
        try await resourceShareNetworkOperation(
          .init(
            resourceID: resourceID,
            body: .init(
              newPermissions: ownCreated,
              updatedPermissions: .init(),
              deletedPermissions: .init(),
              newSecrets: .init()
            )
          )
        )
      }

      // Everyone but the operator, atomically. Skipped when only the operator's own permission changed.
      if granted.isEmpty == false || changed.isEmpty == false || revoked.isEmpty == false {
        appliedForOthers = true
        try await resourceShareNetworkOperation(
          .init(
            resourceID: resourceID,
            body: .init(
              newPermissions: granted,
              updatedPermissions: changed,
              deletedPermissions: revoked,
              newSecrets: newSecrets
            )
          )
        )
      }

      // Giving up or lowering their own permission goes last, so everything above was asked for by a principal
      // that still held the right to ask. Whatever keeps them an owner is in place by now.
      if ownUpdated.isEmpty == false || ownDeleted.isEmpty == false {
        do {
          try await resourceShareNetworkOperation(
            .init(
              resourceID: resourceID,
              body: .init(
                newPermissions: .init(),
                updatedPermissions: ownUpdated,
                deletedPermissions: ownDeleted,
                newSecrets: .init()
              )
            )
          )
        }
        catch {
          // Everyone else's access already changed - say so, or the next attempt measures drift against our own
          // change. Nothing landed when this was the only call, so that stays a plain failure.
          guard appliedForOthers
          else { throw error }
          try? await sessionData.refreshIfNeeded()
          throw PermissionsPartiallyApplied.error(underlyingError: error)
        }
      }

      // Rebuild the local database consistently (Option 1: no targeted local inserts during the operation).
      try await sessionData.refreshIfNeeded()
    }

    return Self(
      applyToCreatedResource: applyToCreatedResource(
        resourceID:
        folderID:
        confirmed:
        snapshot:
      ),
      applyToSharedResource: applyToSharedResource(
        resourceID:
        confirmed:
        snapshot:
      )
    )
  }
}

extension FeaturesRegistry {

  internal mutating func usePassboltResourceShareConfirmation() {
    self.use(
      .disposable(
        ResourceShareConfirmation.self,
        load: ResourceShareConfirmation.load(features:)
      ),
      in: SessionScope.self
    )
  }
}
