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

import Metadata
import NetworkOperations
import Session
import TestExtensions
import XCTest

@testable import PassboltResources

/// Covers `ResourceEditForm.applyConfirmedPermissions` - the edit pipeline, applying the confirmed recipients in
/// the safe order: revoke, re-encrypt for those keeping access, then grant the newly added.
// swift-format-ignore: AlwaysUseLowerCamelCase, NeverUseImplicitlyUnwrappedOptionals, NeverForceUnwrap
final class ResourceEditFormConfirmedPermissionsTests: FeaturesTestCase {

  private nonisolated static let referenceTimestamp: Timestamp = 1_768_390_000

  override func commonPrepare() async throws {
    try await super.commonPrepare()
    register(
      { $0.usePassboltResourceEditForm() },
      for: ResourceEditForm.self
    )
    set(
      SessionScope.self,
      context: .init(
        account: .mock_ada,
        configuration: .mock_default
      )
    )
    set(
      ResourceEditScope.self,
      context: .init(
        editedResource: .mock_1,
        availableTypes: [Resource.mock_1.type]
      )
    )
    patch(
      \OSTime.timestamp,
      with: always(Self.referenceTimestamp)
    )
    patch(
      \MetadataKeysService.validatePinnedKey,
      with: always(.valid)
    )
    patch(  // encryption is exercised elsewhere; here we only care which recipients it is called for
      \SessionCryptography.encryptAndSignMessage,
      with: always(.init(rawValue: "encrypted"))
    )
    patch(  // refresh outcome is irrelevant to the pipeline assertions
      \SessionData.refreshIfNeeded,
      with: always(Void())
    )
    patch(  // metadata key migration is exercised elsewhere; granting new access only has to request it
      \ResourceSharePreparation.prepareResourceForSharing,
      with: always(Void())
    )
  }

  func test_applyConfirmed_whenNothingChanges_reEncryptsForKept_andDoesNotShare() async throws {
    let adaPermissionID: Permission.ID = .init()
    let otherPermissionID: Permission.ID = .init()
    let snapshot: PermissionSnapshot = Self.snapshot(
      adaPermissionID: adaPermissionID,
      otherPermissionID: otherPermissionID
    )
    // Confirming the unchanged set must reduce to a plain re-encrypting update for the current holders.
    let confirmed: OrderedSet<ResourcePermission> = snapshot.permissions

    let editCalled: XCTestExpectation = .init(description: "resource is re-encrypted via editResource")
    patch(
      \ResourceNetworkOperationDispatch.editResource,
      with: { _, _, sentSecrets in
        // A rotating update always carries a secret set - `.none` means "secret unchanged" and would be a defect.
        let secrets: OrderedSet<EncryptedMessage> = try XCTUnwrap(sentSecrets)
        XCTAssertTrue(secrets.contains { $0.recipient == .mock_ada }, "operator must be re-encrypted for")
        XCTAssertTrue(secrets.contains { $0.recipient == .mock_1 }, "kept member must be re-encrypted for")
        editCalled.fulfill()
        return .init(resource: .mock_1)
      }
    )
    // The share network operation is intentionally NOT patched: with no permission change it must never be reached,
    // and its placeholder would trap if it were.

    let tested: ResourceEditForm = try self.testedInstance()
    await verifyIfNotThrows(
      try await tested.applyConfirmedPermissions(confirmed, snapshot)
    )
    await fulfillment(of: [editCalled], timeout: 1.0)
  }

  /// `editResource` derives the metadata key type from `resource.isShared`, which counts the permissions the form
  /// loaded - a stale copy makes a shared resource look personal and the server refuses the update. The confirmed
  /// set was just checked against a fresh capture, so it decides this.
  func test_applyConfirmed_sendsTheConfirmedRecipients_onTheUpdatedResource() async throws {
    let adaPermissionID: Permission.ID = .init()
    let otherPermissionID: Permission.ID = .init()
    var snapshot: PermissionSnapshot = Self.snapshot(
      adaPermissionID: adaPermissionID,
      otherPermissionID: otherPermissionID
    )
    // The form opened on a copy that knows of nobody but the operator - the state that made a shared resource
    // look personal.
    snapshot.permissions = [
      .user(id: .mock_ada, permission: .owner, permissionID: adaPermissionID),
      .user(id: .mock_1, permission: .owner, permissionID: otherPermissionID),
    ]
    // Nothing is changed, so the whole apply reduces to the update - exactly the reported scenario.
    let confirmed: OrderedSet<ResourcePermission> = snapshot.permissions

    let editCalled: XCTestExpectation = .init(description: "the resource is updated")
    patch(
      \ResourceNetworkOperationDispatch.editResource,
      with: { (resource: Resource, _, _) in
        XCTAssertEqual(
          resource.permissions,
          confirmed,
          "The confirmed recipients travel with the update, not whatever the form happened to load"
        )
        XCTAssertTrue(
          resource.isShared,
          "A shared resource must not be sent as a personal one - the server refuses it"
        )
        editCalled.fulfill()
        return .init(resource: .mock_1)
      }
    )
    patch(
      \ResourceShareNetworkOperation.execute,
      with: { _ in XCTFail("Nothing changed, so no permission is shared") }
    )

    let tested: ResourceEditForm = try self.testedInstance()
    await verifyIfNotThrows(
      try await tested.applyConfirmedPermissions(confirmed, snapshot)
    )

    await fulfillment(of: [editCalled], timeout: 1.0)
  }

  func test_applyConfirmed_removesLosingRecipientBeforeReEncrypting_andNeverEncryptsForThem() async throws {
    let adaPermissionID: Permission.ID = .init()
    let otherPermissionID: Permission.ID = .init()
    let snapshot: PermissionSnapshot = Self.snapshot(
      adaPermissionID: adaPermissionID,
      otherPermissionID: otherPermissionID
    )
    // Confirming only the operator drops mock_1 — the losing recipient must lose access before the secret rotates
    // and must never be among the re-encryption recipients.
    let confirmed: OrderedSet<ResourcePermission> = [
      .user(id: .mock_ada, permission: .owner, permissionID: adaPermissionID)
    ]

    let removeCalled: XCTestExpectation = .init(description: "losing recipient is removed first")
    let editCalled: XCTestExpectation = .init(description: "secret is re-encrypted after removal")
    patch(
      \ResourceShareNetworkOperation.execute,
      with: { request in
        XCTAssertTrue(
          request.body.deletedPermissions.contains { $0.id == otherPermissionID },
          "the losing recipient's permission must be deleted"
        )
        XCTAssertTrue(request.body.newPermissions.isEmpty, "removal step must not grant anyone")
        XCTAssertTrue(request.body.newSecrets.isEmpty, "removal step must not carry a secret")
        removeCalled.fulfill()
      }
    )
    patch(
      \ResourceNetworkOperationDispatch.editResource,
      with: { _, _, sentSecrets in
        let secrets: OrderedSet<EncryptedMessage> = try XCTUnwrap(sentSecrets)
        XCTAssertTrue(secrets.contains { $0.recipient == .mock_ada }, "kept operator must be re-encrypted for")
        XCTAssertFalse(
          secrets.contains { $0.recipient == .mock_1 },
          "the removed recipient must never receive the new secret"
        )
        editCalled.fulfill()
        return .init(resource: .mock_1)
      }
    )

    let tested: ResourceEditForm = try self.testedInstance()
    _ = try await tested.applyConfirmedPermissions(confirmed, snapshot)

    // enforceOrder proves the removal completes before the secret is rotated.
    await fulfillment(of: [removeCalled, editCalled], timeout: 1.0, enforceOrder: true)
  }

  func test_applyConfirmed_grantsAddedRecipientWithNewSecret_afterReEncryptingKept() async throws {
    let adaPermissionID: Permission.ID = .init()
    let otherPermissionID: Permission.ID = .init()
    var snapshot: PermissionSnapshot = Self.snapshot(
      adaPermissionID: adaPermissionID,
      otherPermissionID: otherPermissionID
    )
    // The added recipient's key must already be present in the (expanded) snapshot.
    snapshot.users[.mock_2] = PermissionSnapshotUser.mock(id: .mock_2)
    let confirmed: OrderedSet<ResourcePermission> = [
      .user(id: .mock_ada, permission: .owner, permissionID: adaPermissionID),
      .user(id: .mock_1, permission: .read, permissionID: otherPermissionID),
      .user(id: .mock_2, permission: .read, permissionID: .none),  // newly added
    ]

    let editCalled: XCTestExpectation = .init(description: "kept recipients are re-encrypted")
    let grantCalled: XCTestExpectation = .init(description: "added recipient is granted with the new secret")
    patch(
      \ResourceNetworkOperationDispatch.editResource,
      with: { _, _, sentSecrets in
        let secrets: OrderedSet<EncryptedMessage> = try XCTUnwrap(sentSecrets)
        XCTAssertTrue(secrets.contains { $0.recipient == .mock_ada }, "kept operator must be re-encrypted for")
        XCTAssertTrue(secrets.contains { $0.recipient == .mock_1 }, "kept member must be re-encrypted for")
        XCTAssertFalse(
          secrets.contains { $0.recipient == .mock_2 },
          "the added recipient is granted in the share step, not the re-encryption step"
        )
        editCalled.fulfill()
        return .init(resource: .mock_1)
      }
    )
    patch(
      \ResourceShareNetworkOperation.execute,
      with: { request in
        XCTAssertEqual(request.body.newPermissions.count, 1, "only the added recipient is granted")
        XCTAssertTrue(
          request.body.newSecrets.contains { $0.recipient == .mock_2 },
          "the added recipient must receive the new secret"
        )
        XCTAssertTrue(request.body.deletedPermissions.isEmpty, "nothing is removed in this edit")
        grantCalled.fulfill()
      }
    )

    let tested: ResourceEditForm = try self.testedInstance()
    _ = try await tested.applyConfirmedPermissions(confirmed, snapshot)

    await fulfillment(of: [editCalled, grantCalled], timeout: 1.0, enforceOrder: true)
  }

  func test_applyConfirmed_prepareResourceForSharing_runsOnlyWhenAccessIsGranted() async throws {
    let adaPermissionID: Permission.ID = .init()
    let otherPermissionID: Permission.ID = .init()
    var snapshot: PermissionSnapshot = Self.snapshot(
      adaPermissionID: adaPermissionID,
      otherPermissionID: otherPermissionID
    )
    snapshot.users[.mock_2] = PermissionSnapshotUser.mock(id: .mock_2)

    let preparations: CriticalState<Int> = .init(0)
    patch(
      \ResourceSharePreparation.prepareResourceForSharing,
      with: { _ in
        preparations.access { (count: inout Int) in count += 1 }
      }
    )
    patch(
      \ResourceNetworkOperationDispatch.editResource,
      with: always(.init(resource: .mock_1))
    )
    patch(
      \ResourceShareNetworkOperation.execute,
      with: always(Void())
    )

    let tested: ResourceEditForm = try self.testedInstance()

    // Re-encrypting for the current holders touches no new recipient, so no metadata migration is needed.
    _ = try await tested.applyConfirmedPermissions(snapshot.permissions, snapshot)
    await verifyIf(
      preparations.get(),
      isEqual: 0,
      "An edit that grants nobody must not request a metadata key migration"
    )

    // Granting a recipient that never had access does need the metadata readable by them.
    var confirmed: OrderedSet<ResourcePermission> = snapshot.permissions
    confirmed.append(.user(id: .mock_2, permission: .read, permissionID: .none))
    _ = try await tested.applyConfirmedPermissions(confirmed, snapshot)
    await verifyIf(
      preparations.get(),
      isEqual: 1,
      "Granting access to a new recipient must prepare the resource for sharing first"
    )
  }

  func test_applyConfirmed_appliesLevelChange_withoutIssuingANewSecretForAlreadyPresentRecipient() async throws {
    let adaPermissionID: Permission.ID = .init()
    let otherPermissionID: Permission.ID = .init()
    let snapshot: PermissionSnapshot = Self.snapshot(
      adaPermissionID: adaPermissionID,
      otherPermissionID: otherPermissionID
    )
    // mock_1 keeps access but is upgraded read -> owner; it already holds the secret so no new secret is issued.
    let confirmed: OrderedSet<ResourcePermission> = [
      .user(id: .mock_ada, permission: .owner, permissionID: adaPermissionID),
      .user(id: .mock_1, permission: .owner, permissionID: otherPermissionID),
    ]

    let editCalled: XCTestExpectation = .init(description: "kept recipients are re-encrypted")
    let updateCalled: XCTestExpectation = .init(description: "level change is applied")
    patch(
      \ResourceNetworkOperationDispatch.editResource,
      with: { _, _, sentSecrets in
        let secrets: OrderedSet<EncryptedMessage> = try XCTUnwrap(sentSecrets)
        XCTAssertTrue(secrets.contains { $0.recipient == .mock_1 }, "upgraded recipient is re-encrypted as kept")
        editCalled.fulfill()
        return .init(resource: .mock_1)
      }
    )
    patch(
      \ResourceShareNetworkOperation.execute,
      with: { request in
        XCTAssertTrue(
          request.body.updatedPermissions.contains { $0.id == otherPermissionID },
          "the upgraded permission must be updated"
        )
        XCTAssertTrue(request.body.newPermissions.isEmpty, "no recipient is added")
        XCTAssertTrue(request.body.newSecrets.isEmpty, "an already-present recipient needs no new secret")
        updateCalled.fulfill()
      }
    )

    let tested: ResourceEditForm = try self.testedInstance()
    _ = try await tested.applyConfirmedPermissions(confirmed, snapshot)

    await fulfillment(of: [editCalled, updateCalled], timeout: 1.0, enforceOrder: true)
  }

  // MARK: - Failing part way through

  /// Revoking access happens in its own request, so a later failure leaves the resource no longer matching the
  /// reviewed snapshot. It has to be reported as such: the drift check would otherwise blame the operator's next
  /// attempt on a server-side change and hide the failure that actually stopped this one.
  func test_applyConfirmed_whenTheUpdateFailsAfterRevoking_reportsPartiallyApplied() async throws {
    let adaPermissionID: Permission.ID = .init()
    let otherPermissionID: Permission.ID = .init()
    let snapshot: PermissionSnapshot = Self.snapshot(
      adaPermissionID: adaPermissionID,
      otherPermissionID: otherPermissionID
    )
    // Dropping mock_1 makes the revocation step run before the update that then fails.
    let confirmed: OrderedSet<ResourcePermission> = [
      .user(id: .mock_ada, permission: .owner, permissionID: adaPermissionID)
    ]
    patch(
      \ResourceShareNetworkOperation.execute,
      with: always(Void())
    )
    patch(
      \ResourceNetworkOperationDispatch.editResource,
      with: alwaysThrow(MockIssue.error())
    )

    let tested: ResourceEditForm = try self.testedInstance()
    await verifyIf(
      try await tested.applyConfirmedPermissions(confirmed, snapshot),
      throws: PermissionsPartiallyApplied.self,
      "A failure after access was revoked must be reported as a partially applied change"
    )
  }

  func test_applyConfirmed_whenTheUpdateFailsWithNothingApplied_reportsTheFailureItself() async throws {
    let adaPermissionID: Permission.ID = .init()
    let otherPermissionID: Permission.ID = .init()
    let snapshot: PermissionSnapshot = Self.snapshot(
      adaPermissionID: adaPermissionID,
      otherPermissionID: otherPermissionID
    )
    // Nothing is revoked here, so nothing reached the server before the failure.
    let confirmed: OrderedSet<ResourcePermission> = snapshot.permissions
    patch(
      \ResourceNetworkOperationDispatch.editResource,
      with: alwaysThrow(MockIssue.error())
    )

    let tested: ResourceEditForm = try self.testedInstance()
    await verifyIf(
      try await tested.applyConfirmedPermissions(confirmed, snapshot),
      throws: MockIssue.self,
      "With nothing applied yet the failure must be surfaced as it is"
    )
  }

  /// Nothing is revoked here, but the secret rotation lands before the grant fails. The resource has still moved
  /// away from the reviewed snapshot, so the failure must not be reported as though nothing had happened.
  func test_applyConfirmed_whenGrantingFailsAfterTheSecretWasRotated_reportsPartiallyApplied() async throws {
    let adaPermissionID: Permission.ID = .init()
    let otherPermissionID: Permission.ID = .init()
    var snapshot: PermissionSnapshot = Self.snapshot(
      adaPermissionID: adaPermissionID,
      otherPermissionID: otherPermissionID
    )
    // Described but holding no permission yet - the recipient the operator added on the confirmation screen.
    snapshot.users[.mock_2] = PermissionSnapshotUser.mock(id: .mock_2)
    // Everyone in the snapshot is kept and mock_2 is granted, so only the granting step can fail.
    var confirmed: OrderedSet<ResourcePermission> = snapshot.permissions
    confirmed.append(.user(id: .mock_2, permission: .read, permissionID: .none))

    let editCalled: XCTestExpectation = .init(description: "the secret is rotated before the grant fails")
    patch(
      \ResourceNetworkOperationDispatch.editResource,
      with: { _, _, _ in
        editCalled.fulfill()
        return .init(resource: .mock_1)
      }
    )
    patch(
      \ResourceShareNetworkOperation.execute,
      with: alwaysThrow(MockIssue.error())
    )

    let tested: ResourceEditForm = try self.testedInstance()
    await verifyIf(
      try await tested.applyConfirmedPermissions(confirmed, snapshot),
      throws: PermissionsPartiallyApplied.self,
      "A failure after the secret was rotated must be reported as a partially applied change"
    )
    await fulfillment(of: [editCalled], timeout: 1.0)
  }

  // MARK: - Creating privately

  func test_createResourcePrivate_encryptsOnlyForTheOperator_andNeverInheritsFolderPermissions() async throws {
    self.setCreatedResourceContext()
    patch(
      \UsersPGPMessages.encryptMessageForUsers,
      with: { (userIDs: OrderedSet<User.ID>, _: String) -> OrderedSet<EncryptedMessage> in
        XCTAssertEqual(userIDs, [.mock_ada], "The private resource is encrypted for its creator alone")
        return [.mock_1]
      }
    )
    patch(
      \SessionData.updateResource,
      with: always(Void())
    )
    let createCalled: XCTestExpectation = .init(description: "resource is created")
    patch(
      \ResourceNetworkOperationDispatch.createResource,
      with: { (_: Resource, secrets: OrderedSet<EncryptedMessage>, inheritFolderPermissions: Bool) in
        XCTAssertEqual(secrets, [.mock_1], "Only the creator's secret may be sent")
        XCTAssertFalse(
          inheritFolderPermissions,
          "Folder permissions must not be inherited - they are applied only after the operator confirms them"
        )
        createCalled.fulfill()
        return .init(resource: .mock_1, ownerPermissionID: .mock_1)
      }
    )

    let tested: ResourceEditForm = try self.testedInstance()
    await verifyIfNotThrows(
      try await tested.createResourcePrivate()
    )
    await fulfillment(of: [createCalled], timeout: 1.0)
  }

  func test_createResourcePrivate_synthesizesTheOwnerPermission_whenTheResponseCarriesNone() async throws {
    self.setCreatedResourceContext()
    patch(
      \UsersPGPMessages.encryptMessageForUsers,
      with: always([.mock_1])
    )
    patch(  // the create response omits `permissions` and carries only the owner permission id
      \ResourceNetworkOperationDispatch.createResource,
      with: always(.init(resource: .mock_1, ownerPermissionID: .mock_1))
    )
    let updateCalled: XCTestExpectation = .init(description: "the created resource is stored locally")
    patch(
      \SessionData.updateResource,
      with: { (dto: ResourceDTO) in
        XCTAssertEqual(dto.permissions.count, 1, "The operator's ownership must be stored")
        XCTAssertEqual(dto.permissions.first?.userID, Account.mock_ada.userID)
        XCTAssertEqual(dto.permissions.first?.permission, .owner)
        updateCalled.fulfill()
      }
    )

    let tested: ResourceEditForm = try self.testedInstance()
    _ = try await tested.createResourcePrivate()
    await fulfillment(of: [updateCalled], timeout: 1.0)
  }

  /// The confirmation step aligns the creator's own permission with the confirmed list, which it can only do with
  /// the identifier of the permission created here - so the returned resource has to carry it.
  func test_createResourcePrivate_returnsTheResourceCarryingTheOperatorsOwnPermission() async throws {
    self.setCreatedResourceContext()
    patch(
      \UsersPGPMessages.encryptMessageForUsers,
      with: always([.mock_1])
    )
    patch(
      \ResourceNetworkOperationDispatch.createResource,
      with: always(.init(resource: .mock_1, ownerPermissionID: .mock_1))
    )
    patch(
      \SessionData.updateResource,
      with: always(Void())
    )

    let tested: ResourceEditForm = try self.testedInstance()
    let created: Resource = try await tested.createResourcePrivate()

    XCTAssertEqual(created.permissions.count, 1)
    XCTAssertEqual(created.permissions.first?.userID, Account.mock_ada.userID)
    XCTAssertEqual(created.permissions.first?.permissionID, .mock_1)
  }

  func test_createResourcePrivate_fallsBackToARefresh_whenTheTargetedUpdateFails() async throws {
    self.setCreatedResourceContext()
    patch(
      \UsersPGPMessages.encryptMessageForUsers,
      with: always([.mock_1])
    )
    patch(
      \ResourceNetworkOperationDispatch.createResource,
      with: always(.init(resource: .mock_1, ownerPermissionID: .mock_1))
    )
    patch(
      \SessionData.updateResource,
      with: alwaysThrow(MockIssue.error())
    )
    let refreshCalled: XCTestExpectation = .init(description: "the database is rebuilt instead")
    patch(
      \SessionData.refreshIfNeeded,
      with: {
        refreshCalled.fulfill()
      }
    )

    let tested: ResourceEditForm = try self.testedInstance()
    await verifyIfNotThrows(
      try await tested.createResourcePrivate(),
      "The resource exists on the server - a local storage failure must not fail the creation"
    )
    await fulfillment(of: [refreshCalled], timeout: 1.0)
  }

  /// The confirmation can be reopened after the resource was already created (drift, or the operator backing out).
  /// The form has to stand for the created resource by then, so a further submission updates it instead of
  /// creating a second one - and so edits made in between are not silently dropped.
  func test_createResourcePrivate_pointsTheFormAtTheCreatedResource() async throws {
    self.setCreatedResourceContext()
    patch(
      \UsersPGPMessages.encryptMessageForUsers,
      with: always([.mock_1])
    )
    patch(
      \ResourceNetworkOperationDispatch.createResource,
      with: always(.init(resource: .mock_1, ownerPermissionID: .mock_1))
    )
    patch(
      \SessionData.updateResource,
      with: always(Void())
    )

    let tested: ResourceEditForm = try self.testedInstance()
    let created: Resource = try await tested.createResourcePrivate()

    let formState: Resource = try await tested.state.value
    XCTAssertEqual(formState.id, created.id, "The form must carry the identifier of the created resource")
    XCTAssertFalse(formState.isLocal, "The form must no longer look like a resource yet to be created")
    XCTAssertEqual(
      formState.permissions.first?.permissionID,
      created.permissions.first?.permissionID,
      "The form must carry the created owner permission the share step needs"
    )
  }

  /// Guards the comparison the reopened confirmation makes to decide whether an edit still has to be sent: right
  /// after creation the form must equal what was returned, so an untouched form sends nothing.
  func test_createResourcePrivate_leavesTheFormEqualToTheReturnedResource() async throws {
    self.setCreatedResourceContext()
    patch(
      \UsersPGPMessages.encryptMessageForUsers,
      with: always([.mock_1])
    )
    patch(
      \ResourceNetworkOperationDispatch.createResource,
      with: always(.init(resource: .mock_1, ownerPermissionID: .mock_1))
    )
    patch(
      \SessionData.updateResource,
      with: always(Void())
    )

    let tested: ResourceEditForm = try self.testedInstance()
    let created: Resource = try await tested.createResourcePrivate()

    await verifyIf(
      try await tested.state.value == created,
      isEqual: true,
      "An untouched form must compare equal to the created resource, so no needless edit is sent on retry"
    )
  }
}

// swift-format-ignore: AlwaysUseLowerCamelCase, NeverUseImplicitlyUnwrappedOptionals, NeverForceUnwrap
extension ResourceEditFormConfirmedPermissionsTests {

  /// Handing the resource to a group the operator belongs to: their own row goes, but not alongside the step 1
  /// revocations, or everything after would be asked for by a principal that just lost the right.
  func test_applyConfirmed_sendsTheOperatorsOwnChangeLast() async throws {
    let adaPermissionID: Permission.ID = .init()
    let otherPermissionID: Permission.ID = .init()
    let groupPermissionID: Permission.ID = .init()
    var snapshot: PermissionSnapshot = Self.snapshot(
      adaPermissionID: adaPermissionID,
      otherPermissionID: otherPermissionID
    )
    snapshot.groups[.mock_1] = .init(id: .mock_1, name: "Owners", members: [.mock_ada, .mock_1])
    snapshot.permissions.append(.userGroup(id: .mock_1, permission: .owner, permissionID: groupPermissionID))
    // Ada drops her own row; the group she belongs to keeps her an owner.
    let confirmed: OrderedSet<ResourcePermission> = [
      .user(id: .mock_1, permission: .read, permissionID: otherPermissionID),
      .userGroup(id: .mock_1, permission: .owner, permissionID: groupPermissionID),
    ]

    let calls: CriticalState<Array<ResourceShareNetworkOperationVariable>> = .init(.init())
    patch(
      \ResourceShareNetworkOperation.execute,
      with: { request in
        calls.access { (recorded: inout Array<ResourceShareNetworkOperationVariable>) in
          recorded.append(request)
        }
      }
    )
    let editCalled: XCTestExpectation = .init(description: "resource is re-encrypted via editResource")
    patch(
      \ResourceNetworkOperationDispatch.editResource,
      with: { _, _, _ in
        // Every share call before this point must be free of the operator's own change.
        let sentSoFar: Array<ResourceShareNetworkOperationVariable> = calls.get()
        XCTAssertFalse(
          sentSoFar.contains { (request: ResourceShareNetworkOperationVariable) -> Bool in
            request.body.deletedPermissions.contains { $0.id == adaPermissionID }
          },
          "The operator's own revocation must not precede the update"
        )
        editCalled.fulfill()
        return .init(resource: .mock_1)
      }
    )

    let tested: ResourceEditForm = try self.testedInstance()
    await verifyIfNotThrows(
      try await tested.applyConfirmedPermissions(confirmed, snapshot)
    )

    await fulfillment(of: [editCalled], timeout: 1.0)
    let recorded: Array<ResourceShareNetworkOperationVariable> = calls.get()
    XCTAssertTrue(
      recorded.last?.body.deletedPermissions.contains { $0.id == adaPermissionID } ?? false,
      "The operator's own change is the last thing sent"
    )
  }

  /// E15: the operator hands ownership to a group added in the same review. Their row is in `deleted` and the
  /// group in `created`, so neither puts them in the kept set - yet their permission still stands while the secret
  /// rotates. The server validates the update against who holds access *at that moment*.
  func test_applyConfirmed_reEncryptsForTheOperator_whenTheirRowGoesAndTheOwningGroupIsNew() async throws {
    let adaPermissionID: Permission.ID = .init()
    let otherPermissionID: Permission.ID = .init()
    var snapshot: PermissionSnapshot = Self.snapshot(
      adaPermissionID: adaPermissionID,
      otherPermissionID: otherPermissionID
    )
    // Added by hand during the review, so it holds no permission yet - only the expanded snapshot describes it.
    snapshot.groups[.mock_1] = .init(id: .mock_1, name: "Owners", members: [.mock_ada, .mock_2])
    snapshot.users[.mock_2] = PermissionSnapshotUser.mock(id: .mock_2)
    let confirmed: OrderedSet<ResourcePermission> = [
      .user(id: .mock_1, permission: .read, permissionID: otherPermissionID),
      .userGroup(id: .mock_1, permission: .owner, permissionID: .none),
    ]

    let editCalled: XCTestExpectation = .init(description: "the rotated secret covers everyone holding access")
    patch(
      \ResourceNetworkOperationDispatch.editResource,
      with: { _, _, sentSecrets in
        let secrets: OrderedSet<EncryptedMessage> = try XCTUnwrap(sentSecrets)
        XCTAssertTrue(
          secrets.contains { $0.recipient == .mock_ada },
          "The operator still holds access here - their own row is revoked last"
        )
        XCTAssertTrue(secrets.contains { $0.recipient == .mock_1 }, "The kept member is re-encrypted for")
        editCalled.fulfill()
        return .init(resource: .mock_1)
      }
    )
    let calls: CriticalState<Array<ResourceShareNetworkOperationVariable>> = .init(.init())
    patch(
      \ResourceShareNetworkOperation.execute,
      with: { request in
        calls.access { (recorded: inout Array<ResourceShareNetworkOperationVariable>) in
          recorded.append(request)
        }
      }
    )

    let tested: ResourceEditForm = try self.testedInstance()
    await verifyIfNotThrows(
      try await tested.applyConfirmedPermissions(confirmed, snapshot)
    )

    await fulfillment(of: [editCalled], timeout: 1.0)
    let recorded: Array<ResourceShareNetworkOperationVariable> = calls.get()
    XCTAssertTrue(
      recorded.last?.body.deletedPermissions.contains { $0.id == adaPermissionID } ?? false,
      "The operator's own row is still the last thing sent"
    )
    XCTAssertFalse(
      recorded.contains { (request: ResourceShareNetworkOperationVariable) -> Bool in
        request.body.newSecrets.contains { $0.recipient == .mock_ada }
      },
      "They were re-encrypted for in the update, so the grant must not issue them a second secret"
    )
  }

  /// E14, the mirror image: the operator takes over from the group that owned for them. Their grant cannot wait
  /// until last - step 1 revokes their only access, leaving step 2 with no permission to act on.
  func test_applyConfirmed_grantsTheOperatorsOwnPermissionFirst_whenTakingOverFromTheOwningGroup() async throws {
    let otherPermissionID: Permission.ID = .init()
    let groupPermissionID: Permission.ID = .init()
    // The operator owns only through the group - no direct row of their own.
    var snapshot: PermissionSnapshot = .init(
      permissions: [
        .user(id: .mock_1, permission: .read, permissionID: otherPermissionID),
        .userGroup(id: .mock_1, permission: .owner, permissionID: groupPermissionID),
      ],
      users: [
        .mock_ada: PermissionSnapshotUser.mock(id: .mock_ada),
        .mock_1: PermissionSnapshotUser.mock(id: .mock_1),
      ],
      groups: .init(),
      created: 0
    )
    snapshot.groups[.mock_1] = .init(id: .mock_1, name: "Owners", members: [.mock_ada])
    let confirmed: OrderedSet<ResourcePermission> = [
      .user(id: .mock_1, permission: .read, permissionID: otherPermissionID),
      .user(id: .mock_ada, permission: .owner, permissionID: .none),
    ]

    let calls: CriticalState<Array<ResourceShareNetworkOperationVariable>> = .init(.init())
    patch(
      \ResourceShareNetworkOperation.execute,
      with: { request in
        calls.access { (recorded: inout Array<ResourceShareNetworkOperationVariable>) in
          recorded.append(request)
        }
      }
    )
    let editCalled: XCTestExpectation = .init(description: "the resource is updated while the operator holds access")
    patch(
      \ResourceNetworkOperationDispatch.editResource,
      with: { _, _, sentSecrets in
        let sentSoFar: Array<ResourceShareNetworkOperationVariable> = calls.get()
        XCTAssertTrue(
          sentSoFar.contains { (request: ResourceShareNetworkOperationVariable) -> Bool in
            request.body.newPermissions.contains { $0.userID == .mock_ada }
          },
          "The operator's own permission has to exist before the group carrying their access is revoked"
        )
        let secrets: OrderedSet<EncryptedMessage> = try XCTUnwrap(sentSecrets)
        XCTAssertTrue(secrets.contains { $0.recipient == .mock_ada })
        editCalled.fulfill()
        return .init(resource: .mock_1)
      }
    )

    let tested: ResourceEditForm = try self.testedInstance()
    await verifyIfNotThrows(
      try await tested.applyConfirmedPermissions(confirmed, snapshot)
    )

    await fulfillment(of: [editCalled], timeout: 1.0)
    let recorded: Array<ResourceShareNetworkOperationVariable> = calls.get()
    XCTAssertTrue(
      recorded.first?.body.newPermissions.contains { $0.userID == .mock_ada } ?? false,
      "The operator's own grant is the first thing sent"
    )
    XCTAssertTrue(
      recorded.contains { (request: ResourceShareNetworkOperationVariable) -> Bool in
        request.body.deletedPermissions.contains { $0.id == groupPermissionID }
      },
      "The group is still revoked"
    )
  }

  /// E16: an update-only operator confirms a read-only list. The guard is about ownership they would *lose*, so
  /// it has nothing to say about someone who never had any - demanding it refused every edit they could make.
  func test_applyConfirmed_appliesAReadOnlyEdit_whenTheOperatorHoldsUpdateRightsOnly() async throws {
    let adaPermissionID: Permission.ID = .init()
    let otherPermissionID: Permission.ID = .init()
    let snapshot: PermissionSnapshot = .init(
      permissions: [
        .user(id: .mock_ada, permission: .write, permissionID: adaPermissionID),
        .user(id: .mock_1, permission: .owner, permissionID: otherPermissionID),
      ],
      users: [
        .mock_ada: PermissionSnapshotUser.mock(id: .mock_ada),
        .mock_1: PermissionSnapshotUser.mock(id: .mock_1),
      ],
      groups: .init(),
      created: 0
    )
    // Nothing on a read-only list can be changed, so what is confirmed is what was captured.
    let confirmed: OrderedSet<ResourcePermission> = snapshot.permissions

    let editCalled: XCTestExpectation = .init(description: "the edit is applied")
    patch(
      \ResourceNetworkOperationDispatch.editResource,
      with: { _, _, sentSecrets in
        let secrets: OrderedSet<EncryptedMessage> = try XCTUnwrap(sentSecrets)
        XCTAssertTrue(secrets.contains { $0.recipient == .mock_ada }, "The operator keeps their own access")
        XCTAssertTrue(secrets.contains { $0.recipient == .mock_1 }, "The owner keeps theirs")
        editCalled.fulfill()
        return .init(resource: .mock_1)
      }
    )
    patch(
      \ResourceShareNetworkOperation.execute,
      with: { _ in XCTFail("A read-only edit changes no permission, so nothing is shared") }
    )

    let tested: ResourceEditForm = try self.testedInstance()
    await verifyIfNotThrows(
      try await tested.applyConfirmedPermissions(confirmed, snapshot)
    )

    await fulfillment(of: [editCalled], timeout: 1.0)
  }

  /// The other half of that guard: nobody owning the resource is refused whoever is editing. The server rejects
  /// an ownerless resource, so it is caught before anything is sent - including when the operator holds no
  /// ownership of their own to measure against.
  func test_applyConfirmed_refusesASetNobodyOwns_evenWhenTheOperatorNeverOwnedIt() async throws {
    let adaPermissionID: Permission.ID = .init()
    let otherPermissionID: Permission.ID = .init()
    let snapshot: PermissionSnapshot = .init(
      permissions: [
        .user(id: .mock_ada, permission: .write, permissionID: adaPermissionID),
        .user(id: .mock_1, permission: .owner, permissionID: otherPermissionID),
      ],
      users: [
        .mock_ada: PermissionSnapshotUser.mock(id: .mock_ada),
        .mock_1: PermissionSnapshotUser.mock(id: .mock_1),
      ],
      groups: .init(),
      created: 0
    )
    let confirmed: OrderedSet<ResourcePermission> = [
      .user(id: .mock_ada, permission: .write, permissionID: adaPermissionID),
      .user(id: .mock_1, permission: .write, permissionID: otherPermissionID),
    ]
    // Neither network operation is patched - reaching either would trap on its placeholder.

    let tested: ResourceEditForm = try self.testedInstance()

    await verifyIf(
      try await tested.applyConfirmedPermissions(confirmed, snapshot),
      throws: MissingResourceOwner.self
    )
  }

  /// The screen refuses this, but the screen is not the only way in - and an edit that locks the operator out of
  /// what they are editing cannot be undone from the app.
  func test_applyConfirmed_refusesToLeaveTheOperatorWithoutOwnership() async throws {
    let adaPermissionID: Permission.ID = .init()
    let otherPermissionID: Permission.ID = .init()
    let snapshot: PermissionSnapshot = Self.snapshot(
      adaPermissionID: adaPermissionID,
      otherPermissionID: otherPermissionID
    )
    // Ada steps down to read with nobody and no group holding ownership for her.
    let confirmed: OrderedSet<ResourcePermission> = [
      .user(id: .mock_ada, permission: .read, permissionID: adaPermissionID),
      .user(id: .mock_1, permission: .read, permissionID: otherPermissionID),
    ]
    // Neither network operation is patched - reaching either would trap on its placeholder.

    let tested: ResourceEditForm = try self.testedInstance()

    await verifyIf(
      try await tested.applyConfirmedPermissions(confirmed, snapshot),
      throws: MissingResourceOwner.self
    )
  }

  /// Ownership resolved through a group is ownership - the guard must not demand a direct owner row.
  func test_applyConfirmed_acceptsOwnershipHeldThroughAGroup() async throws {
    let adaPermissionID: Permission.ID = .init()
    let otherPermissionID: Permission.ID = .init()
    let groupPermissionID: Permission.ID = .init()
    var snapshot: PermissionSnapshot = Self.snapshot(
      adaPermissionID: adaPermissionID,
      otherPermissionID: otherPermissionID
    )
    snapshot.groups[.mock_1] = .init(id: .mock_1, name: "Owners", members: [.mock_ada])
    snapshot.permissions.append(.userGroup(id: .mock_1, permission: .owner, permissionID: groupPermissionID))
    let confirmed: OrderedSet<ResourcePermission> = [
      .user(id: .mock_ada, permission: .read, permissionID: adaPermissionID),
      .user(id: .mock_1, permission: .read, permissionID: otherPermissionID),
      .userGroup(id: .mock_1, permission: .owner, permissionID: groupPermissionID),
    ]
    patch(
      \ResourceShareNetworkOperation.execute,
      with: always(Void())
    )
    patch(
      \ResourceNetworkOperationDispatch.editResource,
      with: always(.init(resource: .mock_1))
    )

    let tested: ResourceEditForm = try self.testedInstance()

    await verifyIfNotThrows(
      try await tested.applyConfirmedPermissions(confirmed, snapshot)
    )
  }

  fileprivate func setCreatedResourceContext() {
    var editedResource: Resource = .mock_1
    editedResource.id = .none
    editedResource.path = [.mock_1]
    set(
      ResourceEditScope.self,
      context: .init(
        editedResource: editedResource,
        availableTypes: [Resource.mock_1.type]
      )
    )
  }

  /// Snapshot with the operator (`.mock_ada`, owner) plus one other direct member (`.mock_1`, read).
  fileprivate static func snapshot(
    adaPermissionID: Permission.ID,
    otherPermissionID: Permission.ID
  ) -> PermissionSnapshot {
    .init(
      permissions: [
        .user(id: .mock_ada, permission: .owner, permissionID: adaPermissionID),
        .user(id: .mock_1, permission: .read, permissionID: otherPermissionID),
      ],
      users: [
        .mock_ada: PermissionSnapshotUser.mock(id: .mock_ada),
        .mock_1: PermissionSnapshotUser.mock(id: .mock_1),
      ],
      groups: .init(),
      created: 0
    )
  }
}
