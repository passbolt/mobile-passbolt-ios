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

/// Drives the permission confirmation interposed before a resource secret is encrypted for others.
///
/// Every way of creating or editing a resource follows the same rules - the resource form, and the TOTP QR code
/// scanning flows (creating a standalone TOTP, or linking a scanned code to an existing resource) - so they live
/// here rather than in any single screen. The presenting screen supplies only what to do once the confirmed
/// operation succeeded, and keeps a reference to this object for as long as the confirmation may be on screen:
/// it owns the resource created by an abandoned attempt, and the `Features` branch the form belongs to.
@MainActor public final class ResourceEditPermissionConfirmation {

  /// Invoked once the confirmed operation reached the server and the confirmation screen was left, with the
  /// saved resource. The presenting screen performs its own navigation and messaging from here.
  public typealias OnApplied = @MainActor @Sendable (Resource) async -> Void
  /// Invoked when the metadata key could not be validated, so the screen can offer trusting the new key and
  /// retry its own submission afterwards.
  public typealias OnInvalidMetadataKey = @MainActor @Sendable (MetadataPinnedKeyValidationError.Reason) async ->
    Void
  /// Invoked when the operator backed out of the confirmation with nothing applied. Lets a screen that retains this
  /// flow only while its confirmation may be displayed release it right away - and with it the editing scope
  /// branched for that submission, which holds the decrypted secret.
  public typealias OnCancelled = @MainActor @Sendable () -> Void

  private let features: Features
  private let resourceEditForm: ResourceEditForm
  /// Whether the form edits a resource that already exists on the server. Captured from the editing context
  /// rather than read from the form, which stops looking local once the create flow created the resource.
  private let editsExisting: Bool

  /// Resource created during the current create-in-shared-folder confirmation. Retained across drift retries so
  /// the resource is created only once - subsequent attempts re-apply the permissions to the same resource.
  private var confirmationCreatedResource: Resource?

  /// Whether this flow put the confirmation screen up and has not seen it leave yet. Navigation alone cannot tell
  /// "the confirmation is displayed" apart from "there is nothing to push onto", and the two call for opposite
  /// answers - the first means this flow is already driving the submission, the second that it never started.
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

    // Registered in both the app and the autofill extension, so the confirmation applies wherever a resource can
    // be created in a shared folder.
    //
    // A resource created by a confirmation that was abandoned afterwards still has to be shared, never created
    // again - so it always reopens the confirmation, whatever the folder's current state says.
    let awaitingShare: Bool = self.confirmationCreatedResource != nil

    let navigationToConfirmPermissions: NavigationToConfirmPermissions = try self.features.instance()
    let permissionSnapshotService: PermissionSnapshotService = try self.features.instance()
    let resourceShareConfirmation: ResourceShareConfirmation = try self.features.instance()

    let currentAccount: Account = try self.features.sessionAccount()
    let snapshot: PermissionSnapshot = try await permissionSnapshotService.forFolder(folderID)
    // Creating in a private folder implies no sharing - keep the resource private.
    guard awaitingShare || Self.folderIsShared(snapshot, operatorID: currentAccount.userID)
    else { return self.skippingConfirmation("create - parent folder is not shared") }

    // `confirmationCreatedResource` is deliberately NOT cleared here: if a previous confirmation created the
    // resource and was then abandoned (drift, a failed share, or the operator backing out), reopening the
    // confirmation must share that same resource rather than create a second one.
    let context: ConfirmPermissionsContext = .init(
      // Editable when the operator owns the parent folder; otherwise they may only review the inherited list.
      mode: .create(editable: Self.operatorOwnsFolder(snapshot, operatorID: currentAccount.userID)),
      snapshot: snapshot,
      operatorID: currentAccount.userID,
      onConfirm: { [weak self] (confirmed: OrderedSet<ResourcePermission>, currentSnapshot: PermissionSnapshot) in
        await self?
          .applyConfirmedCreate(
            permissionSnapshotService: permissionSnapshotService,
            resourceShareConfirmation: resourceShareConfirmation,
            navigationToConfirmPermissions: navigationToConfirmPermissions,
            folderID: folderID,
            operatorID: currentAccount.userID,
            snapshot: currentSnapshot,
            confirmed: confirmed,
            onApplied: onApplied,
            onInvalidMetadataKey: onInvalidMetadataKey
          ) ?? .failed
      },
      // The confirmation screen reverts itself and the form is left untouched - but a resource created by an
      // earlier attempt exists by now, so the operator is told rather than left with a silent orphan.
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
  /// `onCancelled` is for a screen that retains this flow only while its confirmation may be displayed: backing out
  /// leaves nothing to resume, so the flow - and the editing scope it owns, holding the decrypted secret - can be
  /// released at once rather than at the next submission. Screens that keep one flow for their whole lifetime,
  /// where the retention ends with the screen anyway, pass nothing.
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
    guard resource.isShared
    else { return self.skippingConfirmation("edit - resource is not shared") }

    // A metadata-only edit never re-encrypts the secret for the recipients, so there is nothing to confirm.
    guard self.resourceEditForm.isSecretEdited()
    else { return self.skippingConfirmation("edit - secret unchanged, metadata-only edit") }

    let navigationToConfirmPermissions: NavigationToConfirmPermissions = try self.features.instance()
    let permissionSnapshotService: PermissionSnapshotService = try self.features.instance()
    let currentAccount: Account = try self.features.sessionAccount()
    let snapshot: PermissionSnapshot = try await permissionSnapshotService.forResource(resourceID)

    let context: ConfirmPermissionsContext = .init(
      // Editable when the operator owns the resource; read-only when they only hold the update permission.
      mode: .edit(editable: resource.permission == .owner),
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

  /// Whether the confirmation screen this flow presented is currently in the navigation stack.
  ///
  /// A flow may be reused for a repeated submission only while it is: that screen confirms into the flow it was
  /// opened with, so replacing the flow behind it would leave its confirm button reporting a failure. Once the
  /// operator left the screen there is nothing to confirm into, and a repeated submission has to run on a flow
  /// built for the form it is submitting - by then the presenting screen may be submitting a different resource.
  public func isConfirmationDisplayed() throws -> Bool {
    guard self.confirmationPresented
    else { return false }
    let navigationToConfirmPermissions: NavigationToConfirmPermissions = try self.features.instance()
    return navigationToConfirmPermissions.canPerform() == false
  }

  /// Puts the confirmation screen up and reports that it took over, unless this flow already has it on screen.
  ///
  /// A submission can re-enter this while the confirmation is still displayed: trusting a rotated metadata key
  /// runs the presenting screen's submission again from the start, and the confirmation screen it was rejected
  /// from is still in the navigation stack. The destination is unique, so pushing it a second time throws (and
  /// trips an assertion in debug builds), which would report a failed submission for a screen that is displayed
  /// and ready to be confirmed. The screen already up is the one to confirm from, so navigation is left alone and
  /// the operator confirms the recipients again.
  ///
  /// `canPerform` reports the same `false` when there is no navigation state to push onto at all - a submission
  /// this flow never presented anything for. Reporting "took over" for it would drop the submission with nothing
  /// on screen and nothing said, so the push is attempted and its failure surfaced like any other.
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

  /// Records why no confirmation was shown, and reports "not needed" to the caller. Every reason is a legitimate
  /// one, so nothing is surfaced to the operator - but a secret encrypted for others without the checkpoint would
  /// otherwise leave no trace of the decision, which makes a skipped confirmation impossible to explain after the
  /// fact. Reasons name no secret or recipient, only the shape of the decision.
  private func skippingConfirmation(
    _ reason: String
  ) -> Bool {
    Diagnostics.logger.info("Permission confirmation skipped: \(reason, privacy: .public)")
    return false
  }

  /// Tells the operator that backing out left a created-but-unshared resource behind. It is private and owned by
  /// them, and submitting the form again shares that same resource instead of creating a second one.
  private func notifyResourceAwaitingShare() {
    guard self.confirmationCreatedResource != nil
    else { return }
    SnackBarMessageEvent.send("resource.permission.confirm.create.pending.share")
  }

  /// Runs after the operator confirms permissions in the create flow: creates the resource privately (once), then
  /// applies the confirmed permissions. On drift the screen reopens with refreshed folder permissions so the
  /// operator can review and retry the share (the resource is not re-created). If the operator backs out after
  /// creation the resource is left private and can be shared later.
  private func applyConfirmedCreate(
    permissionSnapshotService: PermissionSnapshotService,
    resourceShareConfirmation: ResourceShareConfirmation,
    navigationToConfirmPermissions: NavigationToConfirmPermissions,
    folderID: ResourceFolder.ID,
    operatorID: User.ID,
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

      // The created resource carries the operator's own owner permission, whose identifier the share step needs
      // to align it with the confirmed list.
      guard let resourceID: Resource.ID = resource.id,
        let ownPermissionID: Permission.ID = resource.permissions.first(where: {
          $0.userID == operatorID
        })?
        .permissionID
      else {
        SnackBarMessageEvent.send(.error("resource.form.error.invalid"))
        return .failed
      }

      do {
        try await resourceShareConfirmation.applyToCreatedResource(
          resourceID,
          ownPermissionID,
          folderID,
          confirmed,
          snapshot
        )
      }
      catch let error as PermissionDriftDetected {
        // Reopen with refreshed folder permissions; the resource stays created (private) meanwhile. The error
        // names the recipients behind the drift, so the operator understands why the list just changed - sent
        // before the refresh, which may fail on its own and would otherwise replace the explanation.
        SnackBarMessageEvent.send(.error(error.displayableMessage))
        return await self.reopenWithRefreshed {
          try await permissionSnapshotService.forFolder(folderID)
        }
      }

      // Fully shared - the operation succeeded. Nothing below may turn that into a failure: the confirmation
      // screen would stay up and a second confirm would re-apply permissions the resource already carries.
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

  /// Runs after the operator confirms permissions in the edit flow: re-checks drift against the resource's current
  /// permissions and, if clear, applies the edit with the confirmed recipients in the safe order (remove →
  /// update+re-encrypt for kept → grant added). For a read-only edit the confirmed set equals the current one, so
  /// this reduces to a plain re-encrypting update.
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
        return .retryWithRefreshed(currentSnapshot)
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
      // Part of the change landed before failing, so the reviewed list is stale by our own doing. Surface the
      // cause that stopped the operation and reopen with the real state, so the next attempt starts from it
      // instead of tripping the drift check on our own revocation.
      error.logged()
      SnackBarMessageEvent.send(.error(error.displayableMessage))
      return await self.reopenWithRefreshed {
        try await permissionSnapshotService.forResource(resourceID)
      }
    }
    catch let error as PermissionDriftDetected {
      // Drift found while applying rather than by the pre-check: reopen with fresh data, as the create flow does.
      error.logged()
      SnackBarMessageEvent.send(.error(error.displayableMessage))
      return await self.reopenWithRefreshed {
        try await permissionSnapshotService.forResource(resourceID)
      }
    }
    catch {
      error.logged()
      SnackBarMessageEvent.send(.error(error))
      return .failed
    }
  }

  /// Sends any edit made to the form since an earlier confirmation attempt created the resource. The form was
  /// pointed at the created resource on creation, so this submits an update rather than creating a second one.
  /// Nothing is sent when the form still matches what was created.
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

  /// Hands over to the presenting screen once a confirmed operation reached the server, and makes sure the
  /// confirmation screen is gone afterwards.
  ///
  /// The presenting screen returns to where its flow started, which sits below the confirmation - and reverting
  /// to it removes everything above it, the confirmation included, in a single navigation change. Popping the
  /// confirmation first would make it two changes in a row, and the second one, applied while the first is still
  /// transitioning, is dropped - leaving the operator on the screen the confirmation was opened from.
  ///
  /// Navigation failures are logged rather than propagated: the change is already applied, and turning one into a
  /// failed outcome would keep the operator on the confirmation screen, free to apply it a second time.
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

  /// Refreshed permissions for the confirmation screen to reopen with. Falls back to `.failed` (the screen keeps
  /// what it shows) when even the refresh fails - the message explaining why is already on screen either way.
  private func reopenWithRefreshed(
    _ refresh: () async throws -> PermissionSnapshot
  ) async -> ConfirmPermissionsOutcome {
    do {
      let refreshed: PermissionSnapshot = try await refresh()
      return .retryWithRefreshed(refreshed)
    }
    catch {
      error.logged()
      return .failed
    }
  }

  private static func folderIsShared(
    _ snapshot: PermissionSnapshot,
    operatorID: User.ID
  ) -> Bool {
    snapshot.permissions.contains { (permission: ResourcePermission) -> Bool in
      switch permission {
      case .userGroup:
        return true

      case .user(let id, _, _):
        return id != operatorID
      }
    }
  }

  /// Whether the operator owns the parent folder, directly or through a group holding ownership on it - the
  /// server evaluates ownership the same way, so an owner by group membership may edit the permissions too.
  private static func operatorOwnsFolder(
    _ snapshot: PermissionSnapshot,
    operatorID: User.ID
  ) -> Bool {
    snapshot.permissions.contains { (permission: ResourcePermission) -> Bool in
      switch permission {
      case .user(let id, let level, _):
        return id == operatorID && level == .owner

      case .userGroup(let id, let level, _):
        return level == .owner && (snapshot.group(id)?.members.contains(operatorID) ?? false)
      }
    }
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
