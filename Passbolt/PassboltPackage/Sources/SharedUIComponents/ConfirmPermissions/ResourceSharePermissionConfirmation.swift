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
import Commons
import Display
import FeatureScopes
import Metadata
import Resources

/// Drives the confirmation the operator shares from. Unlike ``ResourceEditPermissionConfirmation`` there is no
/// form behind it - the confirmation screen *is* the share screen.
@MainActor public final class ResourceSharePermissionConfirmation {

  private let features: Features
  private let resourceID: Resource.ID

  /// Whether the screen is up - see the sibling flow for why navigation alone cannot answer that.
  private var confirmationPresented: Bool = false

  public init(
    features: Features,
    resourceID: Resource.ID
  ) throws {
    try features.ensureScope(SessionScope.self)
    // Owned: a caller may hand over a container only it keeps alive, and this flow outlives the screen that
    // opened it.
    self.features = features.takeOwned()
    self.resourceID = resourceID
  }

  /// Captures the current recipients and opens the confirmation on them. The share is applied from here rather
  /// than the screen that opened it, which may be gone - a contextual menu dismisses itself before the push.
  public func present() async throws {
    let navigationToConfirmPermissions: NavigationToConfirmPermissions = try self.features.instance()
    let permissionSnapshotService: PermissionSnapshotService = try self.features.instance()
    let resourceShareConfirmation: ResourceShareConfirmation = try self.features.instance()
    let currentAccount: Account = try self.features.sessionAccount()

    let snapshot: PermissionSnapshot = try await permissionSnapshotService.forResource(self.resourceID)

    let context: ConfirmPermissionsContext = .init(
      mode: .share,
      snapshot: snapshot,
      operatorID: currentAccount.userID,
      // Strong capture: the screen this context is handed to confirms back into this flow, and nothing else keeps
      // it alive once the screen that opened it is gone. It is released with the confirmation screen.
      onConfirm: { (confirmed: OrderedSet<ResourcePermission>, currentSnapshot: PermissionSnapshot) in
        await self.applyConfirmedShare(
          permissionSnapshotService: permissionSnapshotService,
          resourceShareConfirmation: resourceShareConfirmation,
          navigationToConfirmPermissions: navigationToConfirmPermissions,
          confirmed: confirmed,
          snapshot: currentSnapshot
        )
      },
      // The screen reverts itself, leaving the operator where they opened it from with nothing changed.
      onCancel: { @MainActor in
        self.confirmationPresented = false
      }
    )

    if navigationToConfirmPermissions.canPerform() == false, self.confirmationPresented {
      Diagnostics.logger
        .info("Share permission confirmation not pushed - it is displayed already and is the one to confirm from")
      return
    }
    try await navigationToConfirmPermissions.perform(context: context)
    self.confirmationPresented = true
  }

  /// Applies the confirmed recipients, with drift check and encryption both bound to the reviewed snapshot.
  private func applyConfirmedShare(
    permissionSnapshotService: PermissionSnapshotService,
    resourceShareConfirmation: ResourceShareConfirmation,
    navigationToConfirmPermissions: NavigationToConfirmPermissions,
    confirmed: OrderedSet<ResourcePermission>,
    snapshot: PermissionSnapshot
  ) async -> ConfirmPermissionsOutcome {
    do {
      try await resourceShareConfirmation.applyToSharedResource(self.resourceID, confirmed, snapshot)
      // Shared - nothing below may report failure, or a second confirm would re-apply what already landed.
      await self.finishConfirmed(navigationToConfirmPermissions: navigationToConfirmPermissions)
      return .applied
    }
    catch let error as MetadataPinnedKeyValidationError {
      // Offer trusting the rotated key, then apply the same reviewed set again.
      await presentMetadataPinnedKeyValidation(
        features: self.features,
        reason: error.reason,
        onTrustedKey: { [weak self] in
          await self?
            .retryAfterTrustedKey(
              resourceShareConfirmation: resourceShareConfirmation,
              navigationToConfirmPermissions: navigationToConfirmPermissions,
              confirmed: confirmed,
              snapshot: snapshot
            )
        }
      )
      // The screen stays put; the retry above drives what happens next.
      return .failed
    }
    catch let error as PermissionsPartiallyApplied {
      // Stale by our own doing - reopen with the real state so the next attempt does not trip on our own change.
      error.logged()
      SnackBarMessageEvent.send(.error(error.displayableMessage))
      return await self.reopenWithRefreshed(permissionSnapshotService, confirmed: confirmed)
    }
    catch let error as PermissionDriftDetected {
      error.logged()
      SnackBarMessageEvent.send(.error(error.displayableMessage))
      return await self.reopenWithRefreshed(permissionSnapshotService, confirmed: confirmed)
    }
    catch {
      error.logged()
      SnackBarMessageEvent.send(.error(error))
      return .failed
    }
  }

  /// Re-applies the reviewed set after a rotated metadata key was trusted; a failure leaves the screen as it is.
  private func retryAfterTrustedKey(
    resourceShareConfirmation: ResourceShareConfirmation,
    navigationToConfirmPermissions: NavigationToConfirmPermissions,
    confirmed: OrderedSet<ResourcePermission>,
    snapshot: PermissionSnapshot
  ) async {
    do {
      try await resourceShareConfirmation.applyToSharedResource(self.resourceID, confirmed, snapshot)
      await self.finishConfirmed(navigationToConfirmPermissions: navigationToConfirmPermissions)
    }
    catch {
      error.logged()
      SnackBarMessageEvent.send(.error(error))
    }
  }

  /// Leaves the confirmation once the share landed; navigation failures are logged rather than thrown, or the
  /// operator could apply it twice.
  private func finishConfirmed(
    navigationToConfirmPermissions: NavigationToConfirmPermissions
  ) async {
    self.confirmationPresented = false
    // `canPerform` is false only while the confirmation is still in the navigation stack.
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
    confirmed: OrderedSet<ResourcePermission>
  ) async -> ConfirmPermissionsOutcome {
    do {
      let refreshed: PermissionSnapshot = try await permissionSnapshotService.forResource(self.resourceID)
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
}
