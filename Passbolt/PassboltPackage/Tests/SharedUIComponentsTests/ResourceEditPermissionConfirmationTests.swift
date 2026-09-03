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
import FeatureScopes
import Metadata
import OSFeatures
import Shared
import TestExtensions

@testable import Display
@testable import Resources
@testable import SharedUIComponents

/// The checkpoint interposed before a resource secret is encrypted for others, shared by every screen that submits
/// a resource form. Exercised directly rather than through any one screen - the rules it enforces (never encrypt
/// for a recipient the operator did not review, never create the same resource twice, never report success for an
/// operation that did not reach the server) are the same wherever a resource is created or edited.
// swift-format-ignore: AlwaysUseLowerCamelCase, NeverForceUnwrap
final class ResourceEditPermissionConfirmationTests: FeaturesTestCase {

  /// Current form state, as `ResourceEditForm.state` exposes it.
  private let formState: Variable<Resource> = .init(
    initial: Resource.mock_newInFolder
  )
  /// Contexts the confirmation screen was presented with, in the order they were presented.
  private let presentedContexts: CriticalState<[ConfirmPermissionsContext]> = .init(.init())
  /// Navigation performed by the flow, in order.
  private let navigationEvents: CriticalState<[String]> = .init(.init())
  /// Calls that reached the server, in order - the flow may never repeat one of these.
  private let serverCalls: CriticalState<[String]> = .init(.init())
  /// Resources handed to `onApplied`, in order.
  private let appliedResources: CriticalState<[Resource]> = .init(.init())
  /// Metadata key validation failures handed to `onInvalidMetadataKey`, in order.
  private let invalidMetadataKeyReasons: CriticalState<[MetadataPinnedKeyValidationError.Reason]> = .init(.init())

  override func commonPrepare() async throws {
    try await super.commonPrepare()

    set(
      SessionScope.self,
      context: .init(
        account: .mock_ada,
        configuration: .mock_default
      )
    )
    self.editing(Resource.mock_newInFolder)

    patch(
      \ResourceEditForm.state,
      with: formState.asAnyUpdatable()
    )
    patch(
      \ResourceEditForm.isSecretEdited,
      with: always(true)
    )
    patch(
      \NavigationToConfirmPermissions.mockPerform,
      with: { (_: Bool, context: ConfirmPermissionsContext) in
        self.presentedContexts.access { (contexts: inout [ConfirmPermissionsContext]) in
          contexts.append(context)
        }
        self.navigationEvents.access { (events: inout [String]) in
          events.append("present-confirmation")
        }
      }
    )
    patch(
      \NavigationToConfirmPermissions.mockRevert,
      with: { (_: Bool) in
        self.navigationEvents.access { (events: inout [String]) in
          events.append("revert-confirmation")
        }
      }
    )
    // Nothing of the confirmation is on the navigation stack yet, so it can be presented.
    patch(
      \NavigationToConfirmPermissions.canPerformCheck,
      with: { (_: StaticString, _: UInt) -> Bool in true }
    )
  }
}

// MARK: - Deciding whether to confirm - create
// swift-format-ignore: AlwaysUseLowerCamelCase, NeverForceUnwrap
extension ResourceEditPermissionConfirmationTests {

  func test_createConfirmation_isSkipped_whenResourceHasNoParentFolder() async throws {
    self.editing(
      Resource.mock_newInFolder.with { (resource: inout Resource) in
        resource.path = .init()
      }
    )

    let takenOver: Bool = try await self.tested()
      .presentCreateConfirmationIfNeeded(
        onApplied: self.recordApplied,
        onInvalidMetadataKey: self.recordInvalidMetadataKey
      )

    XCTAssertFalse(takenOver, "A resource outside of any folder inherits nothing - there is nothing to confirm")
    XCTAssertEqual(self.navigationEvents.get(), .init())
  }

  func test_createConfirmation_isSkipped_whenParentFolderHoldsNobodyButTheOperator() async throws {
    patch(
      \PermissionSnapshotService.forFolder,
      with: always(.mock_private)
    )

    let takenOver: Bool = try await self.tested()
      .presentCreateConfirmationIfNeeded(
        onApplied: self.recordApplied,
        onInvalidMetadataKey: self.recordInvalidMetadataKey
      )

    XCTAssertFalse(takenOver, "Creating in a private folder implies no sharing")
    XCTAssertEqual(self.navigationEvents.get(), .init())
  }

  func test_createConfirmation_isEditable_whenOperatorOwnsTheFolder() async throws {
    patch(
      \PermissionSnapshotService.forFolder,
      with: always(.mock_shared)
    )

    let takenOver: Bool = try await self.tested()
      .presentCreateConfirmationIfNeeded(
        onApplied: self.recordApplied,
        onInvalidMetadataKey: self.recordInvalidMetadataKey
      )

    XCTAssertTrue(takenOver)
    XCTAssertEqual(try self.lastPresentedContext().mode, .create(editable: true))
    XCTAssertEqual(try self.lastPresentedContext().operatorID, .mock_ada)
  }

  /// Without ownership of the folder the operator may review the inherited recipients but not change them - the
  /// server would reject the share anyway.
  func test_createConfirmation_isReadOnly_whenOperatorDoesNotOwnTheFolder() async throws {
    patch(
      \PermissionSnapshotService.forFolder,
      with: always(.mock_ownedBySomeoneElse)
    )

    let takenOver: Bool = try await self.tested()
      .presentCreateConfirmationIfNeeded(
        onApplied: self.recordApplied,
        onInvalidMetadataKey: self.recordInvalidMetadataKey
      )

    XCTAssertTrue(takenOver)
    XCTAssertEqual(try self.lastPresentedContext().mode, .create(editable: false))
  }

  /// The server evaluates ownership through group membership too, so an owner by membership may edit the list.
  func test_createConfirmation_isEditable_whenOperatorOwnsTheFolderThroughAGroup() async throws {
    patch(
      \PermissionSnapshotService.forFolder,
      with: always(.mock_ownedByOperatorsGroup)
    )

    let takenOver: Bool = try await self.tested()
      .presentCreateConfirmationIfNeeded(
        onApplied: self.recordApplied,
        onInvalidMetadataKey: self.recordInvalidMetadataKey
      )

    XCTAssertTrue(takenOver)
    XCTAssertEqual(try self.lastPresentedContext().mode, .create(editable: true))
  }

  /// The operator is not a member of the owning group, so ownership by membership does not apply to them.
  func test_createConfirmation_isReadOnly_whenOwningGroupDoesNotContainTheOperator() async throws {
    patch(
      \PermissionSnapshotService.forFolder,
      with: always(.mock_ownedByForeignGroup)
    )

    let takenOver: Bool = try await self.tested()
      .presentCreateConfirmationIfNeeded(
        onApplied: self.recordApplied,
        onInvalidMetadataKey: self.recordInvalidMetadataKey
      )

    XCTAssertTrue(takenOver)
    XCTAssertEqual(try self.lastPresentedContext().mode, .create(editable: false))
  }
}

// MARK: - Deciding whether to confirm - edit
// swift-format-ignore: AlwaysUseLowerCamelCase, NeverForceUnwrap
extension ResourceEditPermissionConfirmationTests {

  func test_editConfirmation_isSkipped_whenResourceDoesNotExistYet() async throws {
    let takenOver: Bool = try await self.tested()
      .presentEditConfirmationIfNeeded(
        onApplied: self.recordApplied,
        onInvalidMetadataKey: self.recordInvalidMetadataKey
      )

    XCTAssertFalse(takenOver, "A resource that does not exist yet goes through the create flow")
    XCTAssertEqual(self.navigationEvents.get(), .init())
  }

  /// Nobody else holds it, so there is nothing to confirm and no screen - but the edit is still applied against
  /// the capture rather than through the plain submission, which draws its recipients from the local copy.
  func test_editConfirmation_appliesWithoutAScreen_whenTheCaptureSaysPrivate() async throws {
    self.editing(Resource.mock_private)
    patch(
      \PermissionSnapshotService.forResource,
      with: always(.mock_private)
    )
    let appliedAgainst: CriticalState<Array<OrderedSet<ResourcePermission>>> = .init(.init())
    patch(
      \ResourceEditForm.applyConfirmedPermissions,
      with: { (permissions: OrderedSet<ResourcePermission>, _: PermissionSnapshot) in
        appliedAgainst.access { (sets: inout Array<OrderedSet<ResourcePermission>>) in sets.append(permissions) }
        return Resource.mock_private
      }
    )

    let takenOver: Bool = try await self.tested()
      .presentEditConfirmationIfNeeded(
        onApplied: self.recordApplied,
        onInvalidMetadataKey: self.recordInvalidMetadataKey
      )

    XCTAssertTrue(takenOver, "The flow applied the edit, so the caller must not submit it again")
    XCTAssertEqual(self.navigationEvents.get(), .init(), "A private resource has no recipients to confirm")
    XCTAssertEqual(appliedAgainst.get(), [PermissionSnapshot.mock_private.permissions])
    XCTAssertEqual(self.appliedResources.get().count, 1)
  }

  /// The local copy is rebuilt only on sign-in and full refresh, so a resource shared since then still reads as
  /// private there. Deciding from it would skip this screen in exactly the case it exists for.
  func test_editConfirmation_isPresented_whenTheCaptureSaysSharedAndTheLocalCopySaysPrivate() async throws {
    self.editing(Resource.mock_private)
    patch(
      \PermissionSnapshotService.forResource,
      with: always(.mock_shared)
    )

    let takenOver: Bool = try await self.tested()
      .presentEditConfirmationIfNeeded(
        onApplied: self.recordApplied,
        onInvalidMetadataKey: self.recordInvalidMetadataKey
      )

    XCTAssertTrue(takenOver)
    XCTAssertEqual(self.navigationEvents.get(), ["present-confirmation"])
    XCTAssertEqual(try self.lastPresentedContext().snapshot.permissions, PermissionSnapshot.mock_shared.permissions)
  }

  /// The reverse staleness: the local copy still lists recipients the resource was unshared from. The capture
  /// decides, and the recipients it names - not the cached ones - are what the secret is re-encrypted for.
  func test_editConfirmation_ignoresTheLocalCopy_whenItStillSaysShared() async throws {
    self.editing(Resource.mock_shared)
    patch(
      \PermissionSnapshotService.forResource,
      with: always(.mock_private)
    )
    patch(
      \ResourceEditForm.sendForm,
      with: { @MainActor in
        XCTFail("The cached recipient set must not decide who the secret is encrypted for")
        return Resource.mock_shared
      }
    )
    let appliedAgainst: CriticalState<Array<OrderedSet<ResourcePermission>>> = .init(.init())
    patch(
      \ResourceEditForm.applyConfirmedPermissions,
      with: { (permissions: OrderedSet<ResourcePermission>, _: PermissionSnapshot) in
        appliedAgainst.access { (sets: inout Array<OrderedSet<ResourcePermission>>) in sets.append(permissions) }
        return Resource.mock_shared
      }
    )

    let takenOver: Bool = try await self.tested()
      .presentEditConfirmationIfNeeded(
        onApplied: self.recordApplied,
        onInvalidMetadataKey: self.recordInvalidMetadataKey
      )

    XCTAssertTrue(takenOver)
    XCTAssertEqual(self.navigationEvents.get(), .init())
    XCTAssertEqual(appliedAgainst.get(), [PermissionSnapshot.mock_private.permissions])
  }

  /// A capture that cannot be taken is not an excuse to fall back on the copy it exists to distrust.
  func test_editConfirmation_failsClosed_whenTheCaptureCannotBeTaken() async throws {
    self.editing(Resource.mock_private)
    patch(
      \PermissionSnapshotService.forResource,
      with: alwaysThrow(MockIssue.error())
    )
    patch(
      \ResourceEditForm.sendForm,
      with: { @MainActor in
        XCTFail("Nothing may be submitted when the current permissions are unknown")
        return Resource.mock_private
      }
    )

    await verifyIf(
      try await self.tested()
        .presentEditConfirmationIfNeeded(
          onApplied: self.recordApplied,
          onInvalidMetadataKey: self.recordInvalidMetadataKey
        ),
      throws: MockIssue.self
    )
    XCTAssertEqual(self.navigationEvents.get(), .init())
    XCTAssertEqual(self.appliedResources.get().count, 0)
  }

  /// A metadata-only edit leaves the secret - and therefore everyone it is encrypted for - untouched.
  func test_editConfirmation_isSkipped_whenOnlyMetadataChanged() async throws {
    self.editing(Resource.mock_shared)
    patch(
      \ResourceEditForm.isSecretEdited,
      with: always(false)
    )
    // Left on its placeholder deliberately: this guard has to stay ahead of the capture, so that an edit which
    // re-encrypts for nobody costs no round trip. Reaching it here would trap.

    let takenOver: Bool = try await self.tested()
      .presentEditConfirmationIfNeeded(
        onApplied: self.recordApplied,
        onInvalidMetadataKey: self.recordInvalidMetadataKey
      )

    XCTAssertFalse(takenOver)
    XCTAssertEqual(self.navigationEvents.get(), .init())
  }

  func test_editConfirmation_isEditable_whenOperatorOwnsTheResource() async throws {
    self.editing(Resource.mock_shared)
    patch(
      \PermissionSnapshotService.forResource,
      with: always(.mock_shared)
    )

    let takenOver: Bool = try await self.tested()
      .presentEditConfirmationIfNeeded(
        onApplied: self.recordApplied,
        onInvalidMetadataKey: self.recordInvalidMetadataKey
      )

    XCTAssertTrue(takenOver)
    XCTAssertEqual(try self.lastPresentedContext().mode, .edit(editable: true))
  }

  /// Holding only the update permission is enough to change the secret, but not to change who receives it. The
  /// capture decides that too - the cached resource still claiming ownership must not open the list for editing.
  func test_editConfirmation_isReadOnly_whenTheCaptureSaysOperatorOnlyHoldsUpdatePermission() async throws {
    self.editing(Resource.mock_shared)
    patch(
      \PermissionSnapshotService.forResource,
      with: always(.mock_ownedBySomeoneElse)
    )

    let takenOver: Bool = try await self.tested()
      .presentEditConfirmationIfNeeded(
        onApplied: self.recordApplied,
        onInvalidMetadataKey: self.recordInvalidMetadataKey
      )

    XCTAssertTrue(takenOver)
    XCTAssertEqual(try self.lastPresentedContext().mode, .edit(editable: false))
  }

  /// And the inverse, so neither direction can be read from the wrong source.
  func test_editConfirmation_isEditable_whenTheCaptureSaysOwner_andTheLocalCopySaysOtherwise() async throws {
    self.editing(
      Resource.mock_shared.with { (resource: inout Resource) in
        resource.permission = .write
      }
    )
    patch(
      \PermissionSnapshotService.forResource,
      with: always(.mock_shared)
    )

    let takenOver: Bool = try await self.tested()
      .presentEditConfirmationIfNeeded(
        onApplied: self.recordApplied,
        onInvalidMetadataKey: self.recordInvalidMetadataKey
      )

    XCTAssertTrue(takenOver)
    XCTAssertEqual(try self.lastPresentedContext().mode, .edit(editable: true))
  }

  /// Ownership held through a group counts, exactly as the server evaluates it.
  func test_editConfirmation_isEditable_whenTheCaptureSaysOwnerThroughAGroup() async throws {
    self.editing(Resource.mock_shared)
    patch(
      \PermissionSnapshotService.forResource,
      with: always(.mock_ownedByOperatorsGroup)
    )

    let takenOver: Bool = try await self.tested()
      .presentEditConfirmationIfNeeded(
        onApplied: self.recordApplied,
        onInvalidMetadataKey: self.recordInvalidMetadataKey
      )

    XCTAssertTrue(takenOver)
    XCTAssertEqual(try self.lastPresentedContext().mode, .edit(editable: true))
  }
}

// MARK: - Applying a confirmed create
// swift-format-ignore: AlwaysUseLowerCamelCase, NeverForceUnwrap
extension ResourceEditPermissionConfirmationTests {

  func test_confirmedCreate_createsPrivatelyThenAppliesConfirmedPermissions() async throws {
    self.patchCreateFlow()

    let confirmation: ResourceEditPermissionConfirmation = try self.tested()
    _ = try await confirmation.presentCreateConfirmationIfNeeded(
      onApplied: self.recordApplied,
      onInvalidMetadataKey: self.recordInvalidMetadataKey
    )
    let outcome: ConfirmPermissionsOutcome = await self.confirm(.mock_shared)

    guard case .applied = outcome
    else { return XCTFail("Confirmed create should report the permissions as applied") }
    XCTAssertEqual(self.serverCalls.get(), ["create-private", "apply-to-created"])
    XCTAssertEqual(self.appliedResources.get().map(\.id), [Resource.mock_created.id])
  }

  /// Drift found while sharing leaves the resource created and private. Confirming again has to share that same
  /// resource - creating a second one would leave the operator with a duplicate they never asked for.
  func test_confirmedCreate_reopensWithRefreshedPermissions_andCreatesTheResourceOnlyOnce() async throws {
    self.patchCreateFlow()
    let confirmedSnapshot: PermissionSnapshot = .mock_shared
    let refreshedSnapshot: PermissionSnapshot = .mock_ownedBySomeoneElse
    let driftedOnce: CriticalState<Bool> = .init(false)
    patch(
      \PermissionSnapshotService.forFolder,
      with: { @Sendable (_: ResourceFolder.ID) -> PermissionSnapshot in
        driftedOnce.get() ? refreshedSnapshot : confirmedSnapshot
      }
    )
    patch(
      \ResourceShareConfirmation.applyToCreatedResource,
      with: {
        @Sendable
        (
          _: Resource.ID,
          _: ResourceFolder.ID,
          _: OrderedSet<ResourcePermission>,
          _: PermissionSnapshot
        ) throws in
        self.serverCalls.access { (calls: inout [String]) in calls.append("apply-to-created") }
        guard driftedOnce.get()
        else {
          driftedOnce.set(true)
          throw PermissionDriftDetected.error()
        }
      }
    )

    let confirmation: ResourceEditPermissionConfirmation = try self.tested()
    _ = try await confirmation.presentCreateConfirmationIfNeeded(
      onApplied: self.recordApplied,
      onInvalidMetadataKey: self.recordInvalidMetadataKey
    )

    let driftOutcome: ConfirmPermissionsOutcome = await self.confirm(.mock_shared)
    guard case .retryWithRefreshed(let handedBack, _) = driftOutcome
    else { return XCTFail("Drift should reopen the confirmation with refreshed permissions") }
    XCTAssertEqual(handedBack, refreshedSnapshot)
    XCTAssertEqual(self.appliedResources.get(), .init(), "Nothing was applied, so nothing may be reported as saved")

    let retryOutcome: ConfirmPermissionsOutcome = await self.confirm(refreshedSnapshot)
    guard case .applied = retryOutcome
    else { return XCTFail("The retried share should report the permissions as applied") }
    XCTAssertEqual(
      self.serverCalls.get(),
      ["create-private", "apply-to-created", "apply-to-created"],
      "The resource must be created once and shared again, never created twice"
    )
  }

  /// The form stays editable behind an abandoned confirmation, so a retry has to carry whatever changed since -
  /// otherwise the edit is dropped without a trace.
  func test_confirmedCreate_sendsEditsMadeSinceTheResourceWasCreated() async throws {
    self.patchCreateFlow()
    // Drift on every attempt keeps the created resource awaiting its share, so the retries stay observable.
    patch(
      \ResourceShareConfirmation.applyToCreatedResource,
      with: {
        @Sendable
        (
          _: Resource.ID,
          _: ResourceFolder.ID,
          _: OrderedSet<ResourcePermission>,
          _: PermissionSnapshot
        ) throws in
        self.serverCalls.access { (calls: inout [String]) in calls.append("apply-to-created") }
        throw PermissionDriftDetected.error()
      }
    )
    patch(
      \ResourceEditForm.sendForm,
      with: { @MainActor in
        self.serverCalls.access { (calls: inout [String]) in calls.append("send-form") }
        return self.formState.value
      }
    )

    let confirmation: ResourceEditPermissionConfirmation = try self.tested()
    _ = try await confirmation.presentCreateConfirmationIfNeeded(
      onApplied: self.recordApplied,
      onInvalidMetadataKey: self.recordInvalidMetadataKey
    )
    _ = await self.confirm(.mock_shared)

    // The operator renamed the resource while the drift message was up.
    self.formState.mutate { (resource: inout Resource) in
      resource.meta.name = .string("Renamed")
    }
    _ = await self.confirm(.mock_shared)
    // Nothing changed since - the same edit may not be sent twice.
    _ = await self.confirm(.mock_shared)

    XCTAssertEqual(
      self.serverCalls.get(),
      [
        "create-private", "apply-to-created",
        "send-form", "apply-to-created",
        "apply-to-created",
      ]
    )
  }

  /// A resource left created-but-unshared still has to be shared, so the confirmation reopens for it - the
  /// alternative is an orphan the operator is never offered a way to share.
  func test_createConfirmation_isPresentedAgain_whenAResourceIsAwaitingShare() async throws {
    self.patchCreateFlow()
    patch(
      \ResourceShareConfirmation.applyToCreatedResource,
      with: {
        @Sendable
        (
          _: Resource.ID,
          _: ResourceFolder.ID,
          _: OrderedSet<ResourcePermission>,
          _: PermissionSnapshot
        ) throws in
        throw PermissionDriftDetected.error()
      }
    )

    let confirmation: ResourceEditPermissionConfirmation = try self.tested()
    _ = try await confirmation.presentCreateConfirmationIfNeeded(
      onApplied: self.recordApplied,
      onInvalidMetadataKey: self.recordInvalidMetadataKey
    )
    _ = await self.confirm(.mock_shared)

    let takenOver: Bool = try await confirmation.presentCreateConfirmationIfNeeded(
      onApplied: self.recordApplied,
      onInvalidMetadataKey: self.recordInvalidMetadataKey
    )

    XCTAssertTrue(takenOver)
    XCTAssertEqual(self.navigationEvents.get(), ["present-confirmation", "present-confirmation"])
  }

  func test_confirmedCreate_offersTrustingTheMetadataKey_whenValidationFails() async throws {
    self.patchCreateFlow()
    patch(
      \ResourceEditForm.createResourcePrivate,
      with: { @MainActor in
        throw MetadataPinnedKeyValidationError.error(reason: .deleted, context: .context(.message("Mock")))
      }
    )

    let confirmation: ResourceEditPermissionConfirmation = try self.tested()
    _ = try await confirmation.presentCreateConfirmationIfNeeded(
      onApplied: self.recordApplied,
      onInvalidMetadataKey: self.recordInvalidMetadataKey
    )
    let outcome: ConfirmPermissionsOutcome = await self.confirm(.mock_shared)

    guard case .failed = outcome
    else { return XCTFail("An unusable metadata key must not report the create as applied") }
    XCTAssertEqual(self.invalidMetadataKeyReasons.get(), [.deleted])
    XCTAssertEqual(self.appliedResources.get(), .init())
  }
}

// MARK: - Applying a confirmed edit
// swift-format-ignore: AlwaysUseLowerCamelCase, NeverForceUnwrap
extension ResourceEditPermissionConfirmationTests {

  func test_confirmedEdit_appliesConfirmedPermissions_whenNothingDrifted() async throws {
    self.patchEditFlow()

    let confirmation: ResourceEditPermissionConfirmation = try self.tested()
    _ = try await confirmation.presentEditConfirmationIfNeeded(
      onApplied: self.recordApplied,
      onInvalidMetadataKey: self.recordInvalidMetadataKey
    )
    let outcome: ConfirmPermissionsOutcome = await self.confirm(.mock_shared)

    guard case .applied = outcome
    else { return XCTFail("Confirmed edit should report the permissions as applied") }
    XCTAssertEqual(self.serverCalls.get(), ["apply-confirmed-permissions"])
    XCTAssertEqual(self.appliedResources.get().map(\.id), [Resource.mock_shared.id])
  }

  /// The whole point of the checkpoint: what the operator reviewed no longer matches the server, so the secret is
  /// not re-encrypted and the updated recipients go back for review.
  func test_confirmedEdit_reopensWithoutApplying_whenPermissionsDrifted() async throws {
    self.patchEditFlow()
    patch(
      \PermissionSnapshotService.drift,
      with: { @Sendable (_: PermissionSnapshot, _: PermissionSnapshot) -> PermissionDrift in
        .init(
          changedPermissions: true,
          changedFingerprints: false,
          changedMemberships: false,
          changedRecipients: ["Someone Else"]
        )
      }
    )

    let confirmation: ResourceEditPermissionConfirmation = try self.tested()
    _ = try await confirmation.presentEditConfirmationIfNeeded(
      onApplied: self.recordApplied,
      onInvalidMetadataKey: self.recordInvalidMetadataKey
    )
    let outcome: ConfirmPermissionsOutcome = await self.confirm(.mock_shared)

    guard case .retryWithRefreshed(let handedBack, _) = outcome
    else { return XCTFail("Drift should reopen the confirmation with the current permissions") }
    XCTAssertEqual(handedBack, .mock_shared)
    XCTAssertEqual(self.serverCalls.get(), .init(), "The secret must not be re-encrypted once drift was found")
  }

  /// Recipients the operator added by hand hold no permission on the resource yet, so a fresh capture does not
  /// describe them - they are re-captured before the drift check, or their keys would never be verified.
  func test_confirmedEdit_expandsAddedRecipients_beforeCheckingDrift() async throws {
    self.patchEditFlow()
    let expandedUsers: CriticalState<[User.ID]> = .init(.init())
    patch(
      \PermissionSnapshotService.forResource,
      with: always(.mock_private)  // the added recipient holds nothing on the resource yet
    )
    patch(
      \PermissionSnapshotService.expanding,
      with: {
        @Sendable
        (
          snapshot: PermissionSnapshot,
          addedUserIDs: [User.ID],
          _: [UserGroup.ID]
        ) -> PermissionSnapshot in
        expandedUsers.access { (users: inout [User.ID]) in users.append(contentsOf: addedUserIDs) }
        return snapshot
      }
    )
    let driftComparedAgainst: CriticalState<PermissionSnapshot?> = .init(.none)
    patch(
      \PermissionSnapshotService.drift,
      with: { @Sendable (_: PermissionSnapshot, current: PermissionSnapshot) -> PermissionDrift in
        driftComparedAgainst.access { (captured: inout PermissionSnapshot?) in captured = current }
        return .none
      }
    )

    let confirmation: ResourceEditPermissionConfirmation = try self.tested()
    _ = try await confirmation.presentEditConfirmationIfNeeded(
      onApplied: self.recordApplied,
      onInvalidMetadataKey: self.recordInvalidMetadataKey
    )
    // The confirmed snapshot describes a recipient the resource does not carry yet.
    _ = await self.confirm(.mock_shared)

    XCTAssertEqual(expandedUsers.get(), [.mock_1])
    XCTAssertNotNil(driftComparedAgainst.get(), "Drift must still be checked against the expanded snapshot")
  }

  /// Recipients losing access are revoked before the secret is rotated, so a failure in between leaves the
  /// reviewed list stale by our own doing - the next attempt has to start from the real state.
  func test_confirmedEdit_reopensWithRefreshedPermissions_whenTheChangeLandedPartially() async throws {
    self.patchEditFlow()
    let confirmedSnapshot: PermissionSnapshot = .mock_shared
    let refreshedSnapshot: PermissionSnapshot = .mock_private
    let applyAttempted: CriticalState<Bool> = .init(false)
    patch(
      \PermissionSnapshotService.forResource,
      with: { @Sendable (_: Resource.ID) -> PermissionSnapshot in
        applyAttempted.get() ? refreshedSnapshot : confirmedSnapshot
      }
    )
    patch(
      \ResourceEditForm.applyConfirmedPermissions,
      with: { @Sendable (_: OrderedSet<ResourcePermission>, _: PermissionSnapshot) throws -> Resource in
        applyAttempted.set(true)
        throw PermissionsPartiallyApplied.error(underlyingError: MockIssue.error())
      }
    )

    let confirmation: ResourceEditPermissionConfirmation = try self.tested()
    _ = try await confirmation.presentEditConfirmationIfNeeded(
      onApplied: self.recordApplied,
      onInvalidMetadataKey: self.recordInvalidMetadataKey
    )
    let outcome: ConfirmPermissionsOutcome = await self.confirm(.mock_shared)

    guard case .retryWithRefreshed(let handedBack, _) = outcome
    else { return XCTFail("A partially applied change should reopen with the real state") }
    XCTAssertEqual(handedBack, refreshedSnapshot)
    XCTAssertEqual(self.appliedResources.get(), .init())
  }

  func test_confirmedEdit_offersTrustingTheMetadataKey_whenValidationFails() async throws {
    self.patchEditFlow()
    patch(
      \ResourceEditForm.applyConfirmedPermissions,
      with: { @Sendable (_: OrderedSet<ResourcePermission>, _: PermissionSnapshot) throws -> Resource in
        throw MetadataPinnedKeyValidationError.error(reason: .deleted, context: .context(.message("Mock")))
      }
    )

    let confirmation: ResourceEditPermissionConfirmation = try self.tested()
    _ = try await confirmation.presentEditConfirmationIfNeeded(
      onApplied: self.recordApplied,
      onInvalidMetadataKey: self.recordInvalidMetadataKey
    )
    let outcome: ConfirmPermissionsOutcome = await self.confirm(.mock_shared)

    guard case .failed = outcome
    else { return XCTFail("An unusable metadata key must not report the edit as applied") }
    XCTAssertEqual(self.invalidMetadataKeyReasons.get(), [.deleted])
  }
}

// MARK: - Leaving the confirmation
// swift-format-ignore: AlwaysUseLowerCamelCase, NeverForceUnwrap
extension ResourceEditPermissionConfirmationTests {

  /// Trusting a rotated metadata key runs the whole submission again while the confirmation it was rejected from
  /// is still displayed. The screen is a unique destination, so pushing it again would throw and report a failure
  /// for a screen the operator is looking at - it is left alone instead.
  func test_confirmation_isNotPresentedAgain_whenThisFlowAlreadyDisplaysIt() async throws {
    self.patchCreateFlow()
    let confirmationDisplayed: CriticalState<Bool> = .init(false)
    patch(
      \NavigationToConfirmPermissions.canPerformCheck,
      with: { (_: StaticString, _: UInt) -> Bool in !confirmationDisplayed.get() }
    )

    let confirmation: ResourceEditPermissionConfirmation = try self.tested()
    _ = try await confirmation.presentCreateConfirmationIfNeeded(
      onApplied: self.recordApplied,
      onInvalidMetadataKey: self.recordInvalidMetadataKey
    )
    confirmationDisplayed.set(true)
    let takenOver: Bool = try await confirmation.presentCreateConfirmationIfNeeded(
      onApplied: self.recordApplied,
      onInvalidMetadataKey: self.recordInvalidMetadataKey
    )

    XCTAssertTrue(takenOver, "The displayed confirmation is still the one driving the submission")
    XCTAssertEqual(self.navigationEvents.get(), ["present-confirmation"], "Navigation must be left alone")
  }

  /// Navigation reports the same "cannot push" when there is no navigation state to push onto at all. Nothing is
  /// displayed then, so reporting that the confirmation took over would drop the submission with no screen up and
  /// nothing said - the push is attempted instead, and its failure surfaced like any other.
  func test_confirmation_isStillPushed_whenNavigationDeclinesItWithNothingDisplayed() async throws {
    self.patchCreateFlow()
    patch(
      \NavigationToConfirmPermissions.canPerformCheck,
      with: { (_: StaticString, _: UInt) -> Bool in false }
    )

    _ = try await self.tested()
      .presentCreateConfirmationIfNeeded(
        onApplied: self.recordApplied,
        onInvalidMetadataKey: self.recordInvalidMetadataKey
      )

    XCTAssertEqual(
      self.navigationEvents.get(),
      ["present-confirmation"],
      "A submission this flow never presented anything for must not be dropped silently"
    )
  }

  /// Leaving the confirmation ends this flow's claim on it: the next submission puts a screen up again rather than
  /// reporting that the one the operator already dismissed took over.
  func test_confirmation_isPresentedAgain_afterTheOperatorCancelledIt() async throws {
    self.patchEditFlow()
    let confirmationDisplayed: CriticalState<Bool> = .init(false)
    patch(
      \NavigationToConfirmPermissions.canPerformCheck,
      with: { (_: StaticString, _: UInt) -> Bool in !confirmationDisplayed.get() }
    )

    let confirmation: ResourceEditPermissionConfirmation = try self.tested()
    _ = try await confirmation.presentEditConfirmationIfNeeded(
      onApplied: self.recordApplied,
      onInvalidMetadataKey: self.recordInvalidMetadataKey
    )
    confirmationDisplayed.set(true)
    await self.cancel()
    confirmationDisplayed.set(false)  // the screen reverted itself on cancel

    _ = try await confirmation.presentEditConfirmationIfNeeded(
      onApplied: self.recordApplied,
      onInvalidMetadataKey: self.recordInvalidMetadataKey
    )

    XCTAssertEqual(self.navigationEvents.get(), ["present-confirmation", "present-confirmation"])
  }

  /// A screen that retains this flow only while its confirmation may be displayed is told when the operator backs
  /// out, so it can release the flow - and with it the editing scope holding the decrypted secret - there and then
  /// rather than at its next submission.
  func test_editConfirmation_reportsCancellation_whenTheOperatorBackedOut() async throws {
    self.patchEditFlow()
    let cancellations: CriticalState<Int> = .init(0)

    let confirmation: ResourceEditPermissionConfirmation = try self.tested()
    _ = try await confirmation.presentEditConfirmationIfNeeded(
      onApplied: self.recordApplied,
      onInvalidMetadataKey: self.recordInvalidMetadataKey,
      onCancelled: { cancellations.access { (count: inout Int) in count += 1 } }
    )
    await self.cancel()

    XCTAssertEqual(cancellations.get(), 1)
  }

  /// Applying is not backing out - a screen told of a cancellation it never had would release the flow while the
  /// operation it is driving is still running.
  func test_editConfirmation_reportsNoCancellation_whenTheEditWasApplied() async throws {
    self.patchEditFlow()
    let cancellations: CriticalState<Int> = .init(0)

    let confirmation: ResourceEditPermissionConfirmation = try self.tested()
    _ = try await confirmation.presentEditConfirmationIfNeeded(
      onApplied: self.recordApplied,
      onInvalidMetadataKey: self.recordInvalidMetadataKey,
      onCancelled: { cancellations.access { (count: inout Int) in count += 1 } }
    )
    _ = await self.confirm(.mock_shared)

    XCTAssertEqual(cancellations.get(), 0)
  }

  /// The presenting screen returns to where its flow started, which sits below the confirmation - one navigation
  /// change removes both. Popping the confirmation separately would be a second change applied mid-transition,
  /// and dropped, leaving the operator on the confirmation screen.
  func test_confirmedEdit_doesNotPopTheConfirmation_whenTheFlowAlreadyLeftIt() async throws {
    self.patchEditFlow()

    let confirmation: ResourceEditPermissionConfirmation = try self.tested()
    _ = try await confirmation.presentEditConfirmationIfNeeded(
      onApplied: self.recordApplied,
      onInvalidMetadataKey: self.recordInvalidMetadataKey
    )
    _ = await self.confirm(.mock_shared)

    XCTAssertEqual(self.navigationEvents.get(), ["present-confirmation"])
  }

  /// A flow that stayed where it was leaves the confirmation on the stack, so it is popped on its own.
  func test_confirmedEdit_popsTheConfirmation_whenTheFlowStayedWhereItWas() async throws {
    self.patchEditFlow()
    let confirmationDisplayed: CriticalState<Bool> = .init(false)
    patch(
      \NavigationToConfirmPermissions.canPerformCheck,
      with: { (_: StaticString, _: UInt) -> Bool in !confirmationDisplayed.get() }
    )

    let confirmation: ResourceEditPermissionConfirmation = try self.tested()
    _ = try await confirmation.presentEditConfirmationIfNeeded(
      onApplied: self.recordApplied,
      onInvalidMetadataKey: self.recordInvalidMetadataKey
    )
    confirmationDisplayed.set(true)
    _ = await self.confirm(.mock_shared)

    XCTAssertEqual(self.navigationEvents.get(), ["present-confirmation", "revert-confirmation"])
  }
}

// MARK: - Test helpers
// swift-format-ignore: AlwaysUseLowerCamelCase, NeverForceUnwrap
extension ResourceEditPermissionConfirmationTests {

  private func tested() throws -> ResourceEditPermissionConfirmation {
    try .init(features: self.testedFeatures)
  }

  /// Points both the edit scope and the form at `resource`, as opening the form for it would. The scope decides
  /// whether the flow treats the submission as a create or an edit.
  private func editing(
    _ resource: Resource
  ) {
    set(
      ResourceEditScope.self,
      context: .init(
        editedResource: resource,
        availableTypes: [resource.type]
      )
    )
    self.formState.mutate { (state: inout Resource) in
      state = resource
    }
  }

  /// Confirms the recipients on the last presented confirmation screen, as the screen's confirm button does.
  private func confirm(
    _ snapshot: PermissionSnapshot
  ) async -> ConfirmPermissionsOutcome {
    guard let context: ConfirmPermissionsContext = self.presentedContexts.get().last
    else {
      XCTFail("Confirmation was never presented")
      return .failed
    }
    return await context.onConfirm(snapshot.permissions, snapshot)
  }

  /// Leaves the last presented confirmation screen, as its cancel button does.
  private func cancel() async {
    guard let context: ConfirmPermissionsContext = self.presentedContexts.get().last
    else { return XCTFail("Confirmation was never presented") }
    await context.onCancel()
  }

  private func lastPresentedContext() throws -> ConfirmPermissionsContext {
    try XCTUnwrap(self.presentedContexts.get().last)
  }

  /// A shared folder the operator owns, with the create steps succeeding.
  private func patchCreateFlow() {
    patch(
      \PermissionSnapshotService.forFolder,
      with: always(.mock_shared)
    )
    let createdResource: Resource = Resource.mock_created
    patch(
      \ResourceEditForm.createResourcePrivate,
      with: { @MainActor in
        self.serverCalls.access { (calls: inout [String]) in calls.append("create-private") }
        // The form is pointed at the created resource, as the live form does.
        self.formState.mutate { (resource: inout Resource) in
          resource = createdResource
        }
        return createdResource
      }
    )
    patch(
      \ResourceShareConfirmation.applyToCreatedResource,
      with: {
        @Sendable
        (
          _: Resource.ID,
          _: ResourceFolder.ID,
          _: OrderedSet<ResourcePermission>,
          _: PermissionSnapshot
        ) in
        self.serverCalls.access { (calls: inout [String]) in calls.append("apply-to-created") }
      }
    )
  }

  /// An existing shared resource the operator owns, with nothing drifted and the edit succeeding.
  private func patchEditFlow() {
    let editedResource: Resource = Resource.mock_shared
    self.editing(editedResource)
    patch(
      \PermissionSnapshotService.forResource,
      with: always(.mock_shared)
    )
    patch(
      \PermissionSnapshotService.drift,
      with: { @Sendable (_: PermissionSnapshot, _: PermissionSnapshot) -> PermissionDrift in .none }
    )
    patch(
      \ResourceEditForm.applyConfirmedPermissions,
      with: { @Sendable (_: OrderedSet<ResourcePermission>, _: PermissionSnapshot) -> Resource in
        self.serverCalls.access { (calls: inout [String]) in calls.append("apply-confirmed-permissions") }
        return editedResource
      }
    )
  }

  private var recordApplied: ResourceEditPermissionConfirmation.OnApplied {
    { [appliedResources] (resource: Resource) in
      appliedResources.access { (resources: inout [Resource]) in
        resources.append(resource)
      }
    }
  }

  private var recordInvalidMetadataKey: ResourceEditPermissionConfirmation.OnInvalidMetadataKey {
    { [invalidMetadataKeyReasons] (reason: MetadataPinnedKeyValidationError.Reason) in
      invalidMetadataKeyReasons.access { (reasons: inout [MetadataPinnedKeyValidationError.Reason]) in
        reasons.append(reason)
      }
    }
  }
}

// MARK: - Fixtures
// swift-format-ignore: AlwaysUseLowerCamelCase, NeverForceUnwrap
extension Resource {

  /// A resource that does not exist on the server yet, being created inside a folder.
  fileprivate static var mock_newInFolder: Resource {
    var resource: Resource = .init(
      id: .none,
      path: [.mock_1],
      type: .mock_1,
      permission: .owner
    )
    resource.meta.name = .string("Mock_new")
    resource.secret.password = .string("R@nD0m")
    return resource
  }

  /// The resource as `createResourcePrivate` returns it - on the server, owned by the operator alone.
  fileprivate static var mock_created: Resource {
    var resource: Resource = .init(
      id: .mock_1,
      path: [.mock_1],
      type: .mock_1,
      permission: .owner,
      permissions: [
        .user(id: .mock_ada, permission: .owner, permissionID: .mock_1)
      ],
      modified: .init(rawValue: 0)
    )
    resource.meta.name = .string("Mock_new")
    resource.secret.password = .string("R@nD0m")
    return resource
  }

  /// An existing resource shared with someone else, owned by the operator.
  fileprivate static var mock_shared: Resource {
    var resource: Resource = .init(
      id: .mock_1,
      type: .mock_1,
      permission: .owner,
      permissions: [
        .user(id: .mock_ada, permission: .owner, permissionID: .mock_1),
        .user(id: .mock_1, permission: .read, permissionID: .mock_2),
      ],
      modified: .init(rawValue: 0)
    )
    resource.meta.name = .string("Mock_shared")
    resource.secret.password = .string("R@nD0m")
    return resource
  }

  /// An existing resource nobody but the operator holds a permission on.
  fileprivate static var mock_private: Resource {
    var resource: Resource = .init(
      id: .mock_1,
      type: .mock_1,
      permission: .owner,
      permissions: [
        .user(id: .mock_ada, permission: .owner, permissionID: .mock_1)
      ],
      modified: .init(rawValue: 0)
    )
    resource.meta.name = .string("Mock_private")
    resource.secret.password = .string("R@nD0m")
    return resource
  }
}
