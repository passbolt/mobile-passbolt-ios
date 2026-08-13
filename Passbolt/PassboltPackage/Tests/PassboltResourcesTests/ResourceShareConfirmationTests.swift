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

import NetworkOperations
import Session
import TestExtensions
import XCTest

@testable import PassboltResources

// swift-format-ignore: AlwaysUseLowerCamelCase
final class ResourceShareConfirmationTests: FeaturesTestCase {

  override func commonPrepare() async throws {
    try await super.commonPrepare()
    register(
      { $0.usePassboltResourceShareConfirmation() },
      for: ResourceShareConfirmation.self
    )
    set(
      SessionScope.self,
      context: .init(
        account: .mock_ada,
        configuration: .mock_default
      )
    )
    patch(
      \ResourceSharePreparation.prepareResourceForSharing,
      with: always(Void())
    )
    patch(
      \ResourceSimulateShareNetworkOperation.execute,
      with: always(.init(changes: .init()))
    )
    patch(
      \PermissionSnapshotService.forFolder,
      with: always(.empty)
    )
    patch(
      \PermissionSnapshotService.unexpectedRecipients,
      with: always(.init())
    )
    patch(  // recapturing added recipients has its own test; elsewhere it yields the current snapshot unchanged
      \PermissionSnapshotService.expanding,
      with: { (current: PermissionSnapshot, _, _) in current }
    )
  }

  /// Recipients the operator added on the confirmation screen hold no permission on the folder, so a fresh capture
  /// of it does not describe them and the drift check would never re-verify their keys. They have to be recaptured
  /// into the current snapshot first, or a key substituted between adding and confirming would go unnoticed at the
  /// exact moment the secret is encrypted for them.
  func test_applyToCreatedResource_recapturesTheAddedRecipients_beforeCheckingDrift() async throws {
    var snapshot: PermissionSnapshot = .empty
    snapshot.users[.mock_1] = PermissionSnapshotUser.mock(id: .mock_1)

    // Something has to be shared, otherwise the apply short-circuits before the drift check.
    let confirmed: OrderedSet<ResourcePermission> = [
      .user(id: .mock_1, permission: .read, permissionID: .none)
    ]

    let recaptured: XCTestExpectation = .init(description: "the added recipient is recaptured")
    patch(
      \PermissionSnapshotService.expanding,
      with: { (current: PermissionSnapshot, addedUsers: Array<User.ID>, _) in
        XCTAssertEqual(addedUsers, [.mock_1], "the recipient the folder does not describe must be recaptured")
        recaptured.fulfill()
        return current
      }
    )
    // Drift is reported so the operation stops right after the check - this test only cares that the recapture
    // happened before it, which the drift throw proves by ordering.
    patch(
      \PermissionSnapshotService.drift,
      with: always(
        .init(
          changedPermissions: true,
          changedFingerprints: false,
          changedMemberships: false
        )
      )
    )

    let sut: ResourceShareConfirmation = try self.testedInstance()

    await verifyIf(
      try await sut.applyToCreatedResource(.init(), .init(), .init(), confirmed, snapshot),
      throws: PermissionDriftDetected.self
    )
    await fulfillment(of: [recaptured], timeout: 1.0)
  }

  /// Confirming the resource as it was created - private, owned by the operator - shares nothing, so no empty
  /// share request may be sent. Neither the drift check nor the share operation is patched here, so reaching
  /// either would trap on its placeholder: returning cleanly proves the whole apply was skipped.
  func test_applyToCreatedResource_whenNothingIsShared_appliesNothing() async throws {
    let confirmed: OrderedSet<ResourcePermission> = [
      .user(id: .mock_ada, permission: .owner, permissionID: .init())
    ]

    let sut: ResourceShareConfirmation = try self.testedInstance()

    await verifyIfNotThrows(
      try await sut.applyToCreatedResource(.init(), .init(), .init(), confirmed, .empty),
      "A confirmed list that changes nothing must be applied without touching the server"
    )
  }

  func test_applyToCreatedResource_whenTheFolderDescribesEveryone_doesNotRecapture() async throws {
    let confirmed: OrderedSet<ResourcePermission> = [
      .user(id: .mock_1, permission: .read, permissionID: .none)
    ]
    patch(
      \PermissionSnapshotService.expanding,
      with: { (_: PermissionSnapshot, _, _) in
        XCTFail("Nothing may be recaptured when the fresh capture already describes every recipient")
        return .empty
      }
    )
    patch(
      \PermissionSnapshotService.drift,
      with: always(
        .init(
          changedPermissions: true,
          changedFingerprints: false,
          changedMemberships: false
        )
      )
    )

    let sut: ResourceShareConfirmation = try self.testedInstance()

    await verifyIf(
      try await sut.applyToCreatedResource(.init(), .init(), .init(), confirmed, .empty),
      throws: PermissionDriftDetected.self
    )
  }

  func test_applyToCreatedResource_whenFolderDrifted_throwsAndDoesNotShare() async throws {
    // The folder drifted from the confirmed snapshot. The share network operation is intentionally NOT patched:
    // if it were reached its placeholder would trap, so a clean throw proves nothing was shared.
    // Someone other than the operator is granted, so there is something to share and the drift check is reached.
    let confirmed: OrderedSet<ResourcePermission> = [
      .user(id: .mock_1, permission: .read, permissionID: .none)
    ]
    patch(
      \PermissionSnapshotService.drift,
      with: always(
        .init(
          changedPermissions: true,
          changedFingerprints: false,
          changedMemberships: false
        )
      )
    )

    let sut: ResourceShareConfirmation = try self.testedInstance()

    await verifyIf(
      try await sut.applyToCreatedResource(.init(), .init(), .init(), confirmed, .empty),
      throws: PermissionDriftDetected.self,
      "Folder drift must abort the operation before sharing"
    )
  }

  func test_applyToCreatedResource_whenDryRunReportsUnconfirmedRecipient_throws() async throws {
    // No permission/fingerprint/membership drift, but the dry-run surfaced a recipient not in the snapshot.
    // Someone other than the operator is granted, so there is something to share and the check is reached.
    let confirmed: OrderedSet<ResourcePermission> = [
      .user(id: .mock_1, permission: .read, permissionID: .none)
    ]
    patch(
      \PermissionSnapshotService.drift,
      with: always(.none)
    )
    patch(
      \PermissionSnapshotService.unexpectedRecipients,
      with: always([.mock_1])
    )

    let sut: ResourceShareConfirmation = try self.testedInstance()

    await verifyIf(
      try await sut.applyToCreatedResource(.init(), .init(), .init(), confirmed, .empty),
      throws: PermissionDriftDetected.self,
      "A dry-run recipient absent from the confirmed snapshot must abort before sharing"
    )
  }

  func test_applyToCreatedResource_grantsConfirmedRecipients_withTheSecretEncryptedForThem() async throws {
    var snapshot: PermissionSnapshot = .empty
    snapshot.users[.mock_1] = PermissionSnapshotUser.mock(id: .mock_1)
    // The operator is already the sole owner of the freshly created resource, so only the other recipient is
    // granted - and only they need the secret.
    let confirmed: OrderedSet<ResourcePermission> = [
      .user(id: .mock_ada, permission: .owner, permissionID: .init()),
      .user(id: .mock_1, permission: .read, permissionID: .init()),
    ]

    patch(
      \PermissionSnapshotService.drift,
      with: always(.none)
    )
    patch(
      \ResourceSimulateShareNetworkOperation.execute,
      with: always(.init(changes: [.added: [.mock_1]]))
    )
    patch(
      \ResourceSecretFetchNetworkOperation.execute,
      with: always(.init(data: "encrypted-secret"))
    )
    patch(
      \SessionCryptography.decryptMessage,
      with: always("decrypted-secret")
    )
    patch(
      \SessionCryptography.encryptAndSignMessage,
      with: always(.init(rawValue: "re-encrypted"))
    )
    patch(
      \SessionData.refreshIfNeeded,
      with: always(Void())
    )

    let shared: XCTestExpectation = .init(description: "the confirmed recipients are granted in one share call")
    patch(
      \ResourceShareNetworkOperation.execute,
      with: { request in
        XCTAssertEqual(request.body.newPermissions.count, 1, "the operator is already the owner - only the other")
        XCTAssertTrue(request.body.updatedPermissions.isEmpty, "the operator keeps the ownership they confirmed")
        XCTAssertTrue(request.body.deletedPermissions.isEmpty, "nothing is revoked on a freshly created resource")
        XCTAssertTrue(
          request.body.newSecrets.contains { $0.recipient == .mock_1 },
          "the granted recipient must receive the secret"
        )
        XCTAssertFalse(
          request.body.newSecrets.contains { $0.recipient == .mock_ada },
          "the operator already holds the secret"
        )
        shared.fulfill()
      }
    )

    let sut: ResourceShareConfirmation = try self.testedInstance()
    await verifyIfNotThrows(
      try await sut.applyToCreatedResource(.mock_1, .init(), .init(), confirmed, snapshot)
    )
    await fulfillment(of: [shared], timeout: 1.0)
  }

  /// The resource is created with the operator as owner, but the confirmed list is what the resource must end up
  /// matching - exactly as inheriting the folder's permissions would leave it.
  func test_applyToCreatedResource_downgradesTheOperator_whenConfirmedWithALowerLevel() async throws {
    let ownPermissionID: Permission.ID = .init()
    let confirmed: OrderedSet<ResourcePermission> = [
      .user(id: .mock_ada, permission: .read, permissionID: .init()),
      .userGroup(id: .mock_1, permission: .owner, permissionID: .init()),
    ]
    self.prepareSuccessfulShare()

    let shared: XCTestExpectation = .init(description: "the operator's own permission is downgraded")
    patch(
      \ResourceShareNetworkOperation.execute,
      with: { request in
        XCTAssertEqual(request.body.updatedPermissions.count, 1, "only the operator's own permission is updated")
        XCTAssertEqual(request.body.updatedPermissions.first?.id, ownPermissionID)
        XCTAssertEqual(request.body.updatedPermissions.first?.permission, .read)
        XCTAssertTrue(request.body.deletedPermissions.isEmpty, "the operator keeps access, at a lower level")
        shared.fulfill()
      }
    )

    let sut: ResourceShareConfirmation = try self.testedInstance()
    await verifyIfNotThrows(
      try await sut.applyToCreatedResource(.mock_1, ownPermissionID, .init(), confirmed, .empty)
    )
    await fulfillment(of: [shared], timeout: 1.0)
  }

  func test_applyToCreatedResource_revokesTheOperator_whenConfirmedListGrantsThemNothing() async throws {
    let ownPermissionID: Permission.ID = .init()
    // Owned through the group only - the same shape the folder had.
    let confirmed: OrderedSet<ResourcePermission> = [
      .userGroup(id: .mock_1, permission: .owner, permissionID: .init())
    ]
    self.prepareSuccessfulShare()

    let shared: XCTestExpectation = .init(description: "the operator's own permission is revoked")
    patch(
      \ResourceShareNetworkOperation.execute,
      with: { request in
        XCTAssertEqual(request.body.deletedPermissions.count, 1, "the operator holds no confirmed permission")
        XCTAssertEqual(request.body.deletedPermissions.first?.id, ownPermissionID)
        XCTAssertTrue(request.body.updatedPermissions.isEmpty)
        shared.fulfill()
      }
    )

    let sut: ResourceShareConfirmation = try self.testedInstance()
    await verifyIfNotThrows(
      try await sut.applyToCreatedResource(.mock_1, ownPermissionID, .init(), confirmed, .empty)
    )
    await fulfillment(of: [shared], timeout: 1.0)
  }

  /// Dropping the creator with nobody else owning the resource would leave it ownerless, so the creator stays.
  func test_applyToCreatedResource_keepsTheOperator_whenNobodyElseWouldOwnTheResource() async throws {
    let confirmed: OrderedSet<ResourcePermission> = [
      .user(id: .mock_1, permission: .read, permissionID: .init())
    ]
    self.prepareSuccessfulShare()

    let shared: XCTestExpectation = .init(description: "the operator's own permission is left alone")
    patch(
      \ResourceShareNetworkOperation.execute,
      with: { request in
        XCTAssertTrue(request.body.deletedPermissions.isEmpty, "the last owner must not be revoked")
        XCTAssertTrue(request.body.updatedPermissions.isEmpty)
        shared.fulfill()
      }
    )

    let sut: ResourceShareConfirmation = try self.testedInstance()
    await verifyIfNotThrows(
      try await sut.applyToCreatedResource(.mock_1, .init(), .init(), confirmed, .empty)
    )
    await fulfillment(of: [shared], timeout: 1.0)
  }

  /// Everything the share step needs when the recipients themselves are not what the test is about: no drift and
  /// no newly-added recipient, so no secret has to be re-encrypted.
  private func prepareSuccessfulShare() {
    patch(
      \PermissionSnapshotService.drift,
      with: always(.none)
    )
    patch(
      \ResourceSimulateShareNetworkOperation.execute,
      with: always(.init(changes: .init()))
    )
    patch(
      \SessionData.refreshIfNeeded,
      with: always(Void())
    )
  }
}

// MARK: - Fixtures
// swift-format-ignore: AlwaysUseLowerCamelCase
extension PermissionSnapshot {

  /// A capture describing nobody - what a freshly created private resource starts from, before the confirmed
  /// recipients are recaptured into it.
  fileprivate static var empty: Self {
    .init(
      permissions: .init(),
      users: .init(),
      groups: .init(),
      created: 0
    )
  }
}
