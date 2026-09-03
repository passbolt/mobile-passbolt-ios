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

import Commons
import Display
import FeatureScopes
import Metadata
import Resources

/// Drives the permission confirmation interposed before a resource secret is encrypted for others, shared by the
/// resource form and both TOTP scanning flows. The presenting screen retains this object while the confirmation
/// may be up: it owns any resource an abandoned attempt created.
@MainActor public final class ResourceEditPermissionConfirmation {

  /// Invoked once the confirmed operation reached the server and the confirmation screen was left, with the
  /// saved resource. The presenting screen performs its own navigation and messaging from here.
  public typealias OnApplied = @MainActor @Sendable (Resource) async -> Void
  /// Invoked when the metadata key could not be validated, so the screen can offer trusting the new key and
  /// retry its own submission afterwards.
  public typealias OnInvalidMetadataKey = @MainActor @Sendable (MetadataPinnedKeyValidationError.Reason) async ->
    Void
  /// Backed out with nothing applied - lets a screen release this flow at once, and with it the editing scope
  /// holding the decrypted secret.
  public typealias OnCancelled = @MainActor @Sendable () -> Void

  private let features: Features
  private let resourceEditForm: ResourceEditForm
  /// Captured from the editing context, not the form, which stops looking local once the create flow ran.
  private let editsExisting: Bool

  /// Retained across drift retries so the resource is created once and later attempts re-share the same one.
  private var confirmationCreatedResource: Resource?

  /// Navigation alone cannot tell "already displayed" from "nothing to push onto", which need opposite answers.
  private var confirmationPresented: Bool = false

  public init(
    features: Features
  ) throws {
    try features.ensureScope(ResourceEditScope.self)
    // Owned rather than referenced: a caller may hand over a container that only it keeps alive, and this flow
    // outlives the submission that built it - it is retained for as long as its confirmation may be on screen.
    self.features = features.takeOwned()
    self.resourceEditForm = try features.instance()
    let editingContext: ResourceEditingContext = try features.context(of: ResourceEditScope.self)
    self.editsExisting = !editingContext.editedResource.isLocal
  }

  /// When creating a resource inside a shared folder, presents the permission confirmation screen and returns
  /// `true` (the confirmation flow takes over create + share). Returns `false` for edits, resources without a
  /// parent folder, or folders that imply no sharing - the caller then performs the normal submission.
  public func presentCreateConfirmationIfNeeded(
    onApplied: @escaping OnApplied,
    onInvalidMetadataKey: @escaping OnInvalidMetadataKey
  ) async throws -> Bool {
    guard
      self.editsExisting == false,
      let folderID: ResourceFolder.ID = try await self.resourceEditForm.state.value.parentFolderID
    else { return false }

    let awaitingShare: Bool = self.confirmationCreatedResource != nil

    let navigationToConfirmPermissions: NavigationToConfirmPermissions = try self.features.instance()
    let permissionSnapshotService: PermissionSnapshotService = try self.features.instance()
    let resourceShareConfirmation: ResourceShareConfirmation = try self.features.instance()

    let currentAccount: Account = try self.features.sessionAccount()
    let snapshot: PermissionSnapshot = try await permissionSnapshotService.forFolder(folderID)
    // Creating in a private folder implies no sharing - keep the resource private.
    guard awaitingShare || Self.isShared(snapshot, operatorID: currentAccount.userID)
    else { return self.skippingConfirmation("create - parent folder is not shared") }

    let context: ConfirmPermissionsContext = .init(
      mode: .create(editable: Self.operatorOwns(snapshot, operatorID: currentAccount.userID)),
      snapshot: snapshot,
      operatorID: currentAccount.userID,
      onConfirm: { [weak self] (confirmed: OrderedSet<ResourcePermission>, currentSnapshot: PermissionSnapshot) in
        await self?
          .applyConfirmedCreate(
            permissionSnapshotService: permissionSnapshotService,
            resourceShareConfirmation: resourceShareConfirmation,
            navigationToConfirmPermissions: navigationToConfirmPermissions,
            folderID: folderID,
            snapshot: currentSnapshot,
            confirmed: confirmed,
            onApplied: onApplied,
            onInvalidMetadataKey: onInvalidMetadataKey
          ) ?? .failed
      },
      onCancel: { @MainActor [weak self] in
        self?.confirmationDismissed()
        self?.notifyResourceAwaitingShare()
      }
    )
    return try await self.present(navigationToConfirmPermissions, context: context)
  }

  /// When editing a resource that is shared, presents the confirmation screen and returns `true` - the
  /// confirmation flow runs the edit on confirm. Returns `false` for new resources, private resources or
  /// metadata-only edits, where the caller performs the normal submission.
  ///
  /// `onCancelled` lets a short-lived screen release this flow, and the editing scope holding the decrypted
  /// secret, as soon as the operator backs out.
  public func presentEditConfirmationIfNeeded(
    onApplied: @escaping OnApplied,
    onInvalidMetadataKey: @escaping OnInvalidMetadataKey,
    onCancelled: OnCancelled? = .none
  ) async throws -> Bool {
    guard self.editsExisting
    else { return false }
    let resource: Resource = try await self.resourceEditForm.state.value
    guard let resourceID: Resource.ID = resource.id
    else { return false }

    // A metadata-only edit never re-encrypts the secret for the recipients, so there is nothing to confirm - and
    // nothing to ask the server about. Checked before the capture below so those edits cost no round trip.
    guard self.resourceEditForm.isSecretEdited()
    else { return self.skippingConfirmation("edit - secret unchanged, metadata-only edit") }

    let navigationToConfirmPermissions: NavigationToConfirmPermissions = try self.features.instance()
    let permissionSnapshotService: PermissionSnapshotService = try self.features.instance()
    let currentAccount: Account = try self.features.sessionAccount()

    // Captured first; everything below is decided from it, never from the local database. That copy is rebuilt
    // only on sign-in and full refresh, so a recently shared resource still reads as private there - letting it
    // gate this screen would skip the check in exactly the case it exists for. A failure stops the submission.
    let snapshot: PermissionSnapshot = try await permissionSnapshotService.forResource(resourceID)

    guard Self.isShared(snapshot, operatorID: currentAccount.userID)
    else {
      return try await self.applyPrivateEdit(
        snapshot: snapshot,
        onApplied: onApplied,
        onInvalidMetadataKey: onInvalidMetadataKey
      )
    }

    let context: ConfirmPermissionsContext = .init(
      // Editable when the operator owns the resource; read-only when they only hold the update permission.
      mode: .edit(editable: Self.operatorOwns(snapshot, operatorID: currentAccount.userID)),
      snapshot: snapshot,
      operatorID: currentAccount.userID,
      onConfirm: { [weak self] (confirmed: OrderedSet<ResourcePermission>, currentSnapshot: PermissionSnapshot) in
        await self?
          .applyConfirmedEdit(
            permissionSnapshotService: permissionSnapshotService,
            navigationToConfirmPermissions: navigationToConfirmPermissions,
            resourceID: resourceID,
            confirmed: confirmed,
            snapshot: currentSnapshot,
            onApplied: onApplied,
            onInvalidMetadataKey: onInvalidMetadataKey
          ) ?? .failed
      },
      // The confirmation screen reverts itself and the form is left untouched.
      onCancel: { @MainActor [weak self] in
        self?.confirmationDismissed()
        onCancelled?()
      }
    )
    return try await self.present(navigationToConfirmPermissions, context: context)
  }

  /// Saves a private edit without a screen, but not through the plain submission - that draws recipients from
  /// the local database, which may still list people the resource was unshared from.
  private func applyPrivateEdit(
    snapshot: PermissionSnapshot,
    onApplied: @escaping OnApplied,
    onInvalidMetadataKey: @escaping OnInvalidMetadataKey
  ) async throws -> Bool {
    Diagnostics.logger
      .info("Permission confirmation skipped: edit - resource is not shared")
    do {
      let resource: Resource = try await self.resourceEditForm.applyConfirmedPermissions(
        snapshot.permissions,
        snapshot
      )
      await onApplied(resource)
    }
    catch let error as MetadataPinnedKeyValidationError {
      await onInvalidMetadataKey(error.reason)
    }
    // Nothing was presented, so there is nothing to leave - the caller must not submit again either way.
    return true
  }

  /// Whether this flow's confirmation screen is still in the navigation stack. A flow may be reused for a repeated
  /// submission only while it is - the screen confirms into the flow it was opened with.
  public func isConfirmationDisplayed() throws -> Bool {
    guard self.confirmationPresented
    else { return false }
    let navigationToConfirmPermissions: NavigationToConfirmPermissions = try self.features.instance()
    return navigationToConfirmPermissions.canPerform() == false
  }

  /// Puts the confirmation up and reports that it took over, unless this flow already has it on screen -
  /// trusting a rotated metadata key re-runs the submission while it is, and the destination is unique.
  private func present(
    _ navigationToConfirmPermissions: NavigationToConfirmPermissions,
    context: ConfirmPermissionsContext
  ) async throws -> Bool {
    if navigationToConfirmPermissions.canPerform() == false, self.confirmationPresented {
      Diagnostics.logger
        .info("Permission confirmation not pushed - it is displayed already and is the one to confirm from")
      return true
    }
    try await navigationToConfirmPermissions.perform(context: context)
    self.confirmationPresented = true
    return true
  }

  /// Records that the confirmation screen left, whichever way the operator took out of it.
  private func confirmationDismissed() {
    self.confirmationPresented = false
  }

  /// Logs why no confirmation was shown, so a skipped checkpoint leaves a trace naming no secret or recipient.
  private func skippingConfirmation(
    _ reason: String
  ) -> Bool {
    Diagnostics.logger.info("Permission confirmation skipped: \(reason, privacy: .public)")
    return false
  }

  /// Tells the operator that backing out left a private resource behind, which resubmitting will share.
  private func notifyResourceAwaitingShare() {
    guard self.confirmationCreatedResource != nil
    else { return }
    SnackBarMessageEvent.send("resource.permission.confirm.create.pending.share")
  }

  /// Creates the resource privately once, then grants the confirmed recipients; drift reopens without
  /// re-creating it.
  private func applyConfirmedCreate(
    permissionSnapshotService: PermissionSnapshotService,
    resourceShareConfirmation: ResourceShareConfirmation,
    navigationToConfirmPermissions: NavigationToConfirmPermissions,
    folderID: ResourceFolder.ID,
    snapshot: PermissionSnapshot,
    confirmed: OrderedSet<ResourcePermission>,
    onApplied: @escaping OnApplied,
    onInvalidMetadataKey: @escaping OnInvalidMetadataKey
  ) async -> ConfirmPermissionsOutcome {
    do {
      let resource: Resource
      if let created: Resource = self.confirmationCreatedResource {
        // Retry after drift, or a reopened confirmation - the resource exists and is never created twice. Edits
        // made to the form since then still have to reach it, otherwise they would be dropped without a trace.
        resource = try await self.flushEditsToCreatedResource(created)
      }
      else {
        resource = try await self.resourceEditForm.createResourcePrivate()
        self.confirmationCreatedResource = resource
      }

      guard let resourceID: Resource.ID = resource.id
      else {
        SnackBarMessageEvent.send(.error("resource.form.error.invalid"))
        return .failed
      }

      do {
        try await resourceShareConfirmation.applyToCreatedResource(
          resourceID,
          folderID,
          confirmed,
          snapshot
        )
      }
      catch let error as PermissionDriftDetected {
        SnackBarMessageEvent.send(.error(error.displayableMessage))
        return await self.reopenWithRefreshed(permissionSnapshotService, confirmed: confirmed) {
          try await permissionSnapshotService.forFolder(folderID)
        }
      }

      self.confirmationCreatedResource = .none
      await self.finishConfirmed(
        navigationToConfirmPermissions: navigationToConfirmPermissions,
        resource: resource,
        onApplied: onApplied
      )
      return .applied
    }
    catch let error as MetadataPinnedKeyValidationError {
      await onInvalidMetadataKey(error.reason)
      return .failed
    }
    catch {
      // Creation failed (nothing created) or the share failed for a non-drift reason: surface it and stay.
      // If a resource was already created it is left private and can be shared later.
      error.logged()
      SnackBarMessageEvent.send(.error(error))
      return .failed
    }
  }

  /// Re-checks drift, then applies the edit in the safe order.
  private func applyConfirmedEdit(
    permissionSnapshotService: PermissionSnapshotService,
    navigationToConfirmPermissions: NavigationToConfirmPermissions,
    resourceID: Resource.ID,
    confirmed: OrderedSet<ResourcePermission>,
    snapshot: PermissionSnapshot,
    onApplied: @escaping OnApplied,
    onInvalidMetadataKey: @escaping OnInvalidMetadataKey
  ) async -> ConfirmPermissionsOutcome {
    do {
      let currentResourceSnapshot: PermissionSnapshot = try await permissionSnapshotService.forResource(resourceID)
      // Recipients the operator added by hand hold no permission on the resource yet, so a fresh capture does not
      // describe them and the drift check would never re-verify their keys. Re-capture them into it first.
      let missingRecipients: (users: Array<User.ID>, groups: Array<UserGroup.ID>) =
        snapshot.recipientsMissing(from: currentResourceSnapshot)
      let currentSnapshot: PermissionSnapshot
      if missingRecipients.users.isEmpty, missingRecipients.groups.isEmpty {
        currentSnapshot = currentResourceSnapshot
      }
      else {
        currentSnapshot = try await permissionSnapshotService.expanding(
          currentResourceSnapshot,
          missingRecipients.users,
          missingRecipients.groups
        )
      }

      let drift: PermissionDrift = permissionSnapshotService.drift(snapshot, currentSnapshot)
      guard drift.hasDrift == false
      else {
        SnackBarMessageEvent.send(.error(drift.displayableMessage))
        // `currentSnapshot` already describes the added recipients - it was widened for the drift check - so the
        // reopen only needs the grants themselves back; its permissions are still the server's own.
        return .retryWithRefreshed(
          currentSnapshot,
          restoring: .init(
            confirmed.filter { (permission: ResourcePermission) -> Bool in permission.permissionID == .none }
          )
        )
      }

      let resource: Resource = try await self.resourceEditForm.applyConfirmedPermissions(confirmed, snapshot)

      // Applied - as in the create flow, nothing below may report failure and invite a second apply.
      await self.finishConfirmed(
        navigationToConfirmPermissions: navigationToConfirmPermissions,
        resource: resource,
        onApplied: onApplied
      )
      return .applied
    }
    catch let error as MetadataPinnedKeyValidationError {
      await onInvalidMetadataKey(error.reason)
      return .failed
    }
    catch let error as PermissionsPartiallyApplied {
      // Part of it landed, so the reviewed list is stale by our own doing - reopen on the real state, or the
      // next attempt trips the drift check on our own change.
      error.logged()
      SnackBarMessageEvent.send(.error(error.displayableMessage))
      return await self.reopenWithRefreshed(permissionSnapshotService, confirmed: confirmed) {
        try await permissionSnapshotService.forResource(resourceID)
      }
    }
    catch let error as PermissionDriftDetected {
      // Drift found while applying rather than by the pre-check: reopen with fresh data, as the create flow does.
      error.logged()
      SnackBarMessageEvent.send(.error(error.displayableMessage))
      return await self.reopenWithRefreshed(permissionSnapshotService, confirmed: confirmed) {
        try await permissionSnapshotService.forResource(resourceID)
      }
    }
    catch {
      error.logged()
      SnackBarMessageEvent.send(.error(error))
      return .failed
    }
  }

  /// Sends any edit made since an earlier attempt created the resource; nothing when the form still matches.
  private func flushEditsToCreatedResource(
    _ created: Resource
  ) async throws -> Resource {
    let current: Resource = try await self.resourceEditForm.state.value
    guard current != created
    else { return created }
    let updated: Resource = try await self.resourceEditForm.sendForm()
    // Track the form as it now stands rather than what `sendForm` returned - it fills in metadata on its own copy,
    // which would not compare equal to the form and would make every later retry resend the same edit.
    self.confirmationCreatedResource = try await self.resourceEditForm.state.value
    return updated
  }

  /// Hands over to the presenting screen, which returns to below the confirmation - one navigation change
  /// removes both, where popping first would make it two and the second is dropped mid-transition. Failures are
  /// logged rather than thrown, since the change already landed.
  private func finishConfirmed(
    navigationToConfirmPermissions: NavigationToConfirmPermissions,
    resource: Resource,
    onApplied: OnApplied
  ) async {
    await onApplied(resource)
    self.confirmationDismissed()
    // `canPerform` is false while the confirmation is still in the navigation stack - only then does it need
    // reverting on its own, for a flow that stayed where it was rather than navigating back.
    guard navigationToConfirmPermissions.canPerform() == false
    else { return }
    do {
      try await navigationToConfirmPermissions.revert()
    }
    catch {
      error.logged()
    }
  }

  /// Refreshed permissions to reopen with, still describing the operator's added grants so they survive it.
  private func reopenWithRefreshed(
    _ permissionSnapshotService: PermissionSnapshotService,
    confirmed: OrderedSet<ResourcePermission>,
    _ refresh: () async throws -> PermissionSnapshot
  ) async -> ConfirmPermissionsOutcome {
    do {
      let refreshed: PermissionSnapshot = try await refresh()
      let additions: OrderedSet<ResourcePermission> = .init(
        confirmed.filter { (permission: ResourcePermission) -> Bool in permission.permissionID == .none }
      )
      guard additions.isEmpty == false
      else { return .retryWithRefreshed(refreshed, restoring: .init()) }

      // A recipient the widening cannot cover is one nobody can encrypt for; the reopen drops them on its own
      // rather than losing the refreshed list too.
      let described: PermissionSnapshot
      do {
        described = try await permissionSnapshotService.expanding(
          refreshed,
          additions.compactMap(\.userID),
          additions.compactMap(\.userGroupID)
        )
      }
      catch {
        error.logged()
        described = refreshed
      }
      return .retryWithRefreshed(described, restoring: additions)
    }
    catch {
      error.logged()
      return .failed
    }
  }

  /// Whether the capture holds anyone but the operator as sole owner - measured against the snapshot, never the
  /// local database, since it decides whether a secret reaches someone else.
  private static func isShared(
    _ snapshot: PermissionSnapshot,
    operatorID: User.ID
  ) -> Bool {
    guard snapshot.permissions.count == 1,
      let only: ResourcePermission = snapshot.permissions.first
    else { return snapshot.permissions.isEmpty == false }

    switch only {
    case .userGroup:
      return true

    case .user(let id, let level, _):
      return id != operatorID || level != .owner
    }
  }

  /// Whether the operator owns the captured ACO - an owner by group membership may edit the permissions too.
  private static func operatorOwns(
    _ snapshot: PermissionSnapshot,
    operatorID: User.ID
  ) -> Bool {
    snapshot.grantsOwnership(to: operatorID, in: snapshot.permissions)
  }
}

/// Offers trusting the metadata key that failed validation and retries the submission afterwards. Shared by
/// every screen that submits a resource form, whether or not the permission confirmation was involved.
@MainActor public func presentMetadataPinnedKeyValidation(
  features: Features,
  reason: MetadataPinnedKeyValidationError.Reason,
  onTrustedKey: @escaping @Sendable () async throws -> Void
) async {
  await consumingErrors {
    let navigationToInvalidMetadataKey: NavigationToMetadataPinnedKeyValidationDialog =
      try await features.instance()
    await navigationToInvalidMetadataKey.performCatching(
      context: .init(
        reason: reason,
        onTrustedKey: onTrustedKey
      )
    )
  }
}
