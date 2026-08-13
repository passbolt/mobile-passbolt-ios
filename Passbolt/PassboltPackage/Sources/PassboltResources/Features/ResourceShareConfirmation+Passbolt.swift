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

    /// Re-captures the recipients the operator added by hand into a freshly-built snapshot, so the drift check
    /// covers their keys too. A fresh capture only describes who already holds a permission on the folder, which
    /// would leave an added recipient's key unverified at the exact moment the secret is encrypted for them.
    @Sendable nonisolated func recapturingAddedRecipients(
      of confirmed: PermissionSnapshot,
      into current: PermissionSnapshot
    ) async throws -> PermissionSnapshot {
      let missing: (users: Array<User.ID>, groups: Array<UserGroup.ID>) = confirmed.recipientsMissing(from: current)
      guard missing.users.isEmpty == false || missing.groups.isEmpty == false
      else { return current }
      return try await permissionSnapshotService.expanding(current, missing.users, missing.groups)
    }

    /// The operator's own permission on the created resource, as the confirmed list requires it to end up. They
    /// were made owner when the resource was created privately, so anything else has to be applied explicitly -
    /// the same alignment the non-confirmed create performs with the folder's permissions.
    ///
    /// Their permission is only dropped when someone else in the confirmed list owns the resource (a user or a
    /// group): a resource without an owner is rejected by the server, and keeping the creator is the safer end.
    @Sendable nonisolated func ownPermissionChange(
      resourceID: Resource.ID,
      ownPermissionID: Permission.ID,
      confirmed: OrderedSet<ResourcePermission>
    ) -> (updated: Array<GenericPermissionDTO>, deleted: Array<GenericPermissionDTO>) {
      let ownDTO: (Permission) -> GenericPermissionDTO = { (level: Permission) in
        .userToResource(
          id: ownPermissionID,
          userID: currentAccount.userID,
          resourceID: resourceID,
          permission: level
        )
      }

      if let confirmedOwn: ResourcePermission = confirmed.first(where: { $0.userID == currentAccount.userID }) {
        guard confirmedOwn.permission != .owner
        else { return (updated: .init(), deleted: .init()) }
        return (updated: [ownDTO(confirmedOwn.permission)], deleted: .init())
      }
      else {
        let confirmedHasOtherOwner: Bool = confirmed.contains { (permission: ResourcePermission) -> Bool in
          permission.permission == .owner && permission.userID != currentAccount.userID
        }
        guard confirmedHasOtherOwner
        else { return (updated: .init(), deleted: .init()) }
        return (updated: .init(), deleted: [ownDTO(.owner)])
      }
    }

    @Sendable nonisolated func applyToCreatedResource(
      resourceID: Resource.ID,
      ownPermissionID: Permission.ID,
      folderID: ResourceFolder.ID,
      confirmed: OrderedSet<ResourcePermission>,
      snapshot: PermissionSnapshot
    ) async throws {
      // The resource is created with the operator as sole owner; the confirmed set grants access to everyone
      // else. Folder permission ids are irrelevant here - these are new permissions on the new resource.
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
      let ownChange: (updated: Array<GenericPermissionDTO>, deleted: Array<GenericPermissionDTO>) =
        ownPermissionChange(
          resourceID: resourceID,
          ownPermissionID: ownPermissionID,
          confirmed: confirmed
        )

      // The operator confirmed the resource exactly as it was created - private and owned by them. Nothing is
      // shared, so the metadata key is left personal and no empty share request is sent to the server.
      guard
        grants.isEmpty == false
          || ownChange.updated.isEmpty == false
          || ownChange.deleted.isEmpty == false
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

      // Apply the confirmed permissions in a single atomic share call, the operator's own permission included.
      try await resourceShareNetworkOperation(
        .init(
          resourceID: resourceID,
          body: .init(
            newPermissions: grants.compactMap { $0.asNewDTO(resourceID: resourceID) },
            updatedPermissions: ownChange.updated,
            deletedPermissions: ownChange.deleted,
            newSecrets: newSecrets
          )
        )
      )

      // Rebuild the local database consistently (Option 1: no targeted local inserts during the operation).
      try await sessionData.refreshIfNeeded()
    }

    return Self(
      applyToCreatedResource: applyToCreatedResource(
        resourceID:
        ownPermissionID:
        folderID:
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
