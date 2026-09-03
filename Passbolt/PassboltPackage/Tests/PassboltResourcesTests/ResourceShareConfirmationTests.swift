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
    patch(
      \PermissionSnapshotService.forResource,
      with: always(.empty)
    )
    patch(
      \MetadataKeysService.validatePinnedKey,
      with: always(.valid)
    )
  }

  /// Hand-added recipients hold no permission on the folder, so a fresh capture omits them and the drift check
  /// never re-verifies their keys - a key substituted between adding and confirming would go unnoticed.
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
      try await sut.applyToCreatedResource(.init(), .init(), confirmed, snapshot),
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
      try await sut.applyToCreatedResource(.init(), .init(), confirmed, .empty),
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
      try await sut.applyToCreatedResource(.init(), .init(), confirmed, .empty),
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
      try await sut.applyToCreatedResource(.init(), .init(), confirmed, .empty),
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
      try await sut.applyToCreatedResource(.init(), .init(), confirmed, .empty),
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
      try await sut.applyToCreatedResource(.mock_1, .init(), confirmed, snapshot)
    )
    await fulfillment(of: [shared], timeout: 1.0)
  }

  /// The resource is created with the operator as sole owner only to have something to share from. What they
  /// keep is what the folder grants them, so that bootstrap permission is settled once the grants have put
  /// another owner in place - never before, or the drop would leave the resource momentarily ownerless.

  /// Inheriting ownership is what the resource was already created with, so there is nothing to settle and no
  /// second request to send.
  func test_applyToCreatedResource_leavesTheBootstrapPermission_whenTheOperatorInheritsOwnership() async throws {
    let confirmed: OrderedSet<ResourcePermission> = [
      .user(id: .mock_ada, permission: .owner, permissionID: .init()),
      .userGroup(id: .mock_1, permission: .owner, permissionID: .init()),
    ]
    self.prepareSuccessfulShare()
    let requests: CriticalState<Array<RecordedShare>> = .init(.init())
    self.recordShareRequests(into: requests)

    let sut: ResourceShareConfirmation = try self.testedInstance()
    await verifyIfNotThrows(
      try await sut.applyToCreatedResource(.mock_1, .init(), confirmed, .empty)
    )

    await verifyIf(
      requests.get(),
      isEqual: [.init(granted: 1, updated: 0, deleted: 0)],
      "Only the group is granted; the creator's ownership is left exactly as created"
    )
  }

  /// The folder grants the operator update, so the owner permission they were bootstrapped with is lowered to
  /// it - creating a resource inside a folder does not promote them above that folder.
  func test_applyToCreatedResource_lowersTheBootstrapPermission_whenTheOperatorInheritsLess() async throws {
    let confirmed: OrderedSet<ResourcePermission> = [
      .user(id: .mock_ada, permission: .write, permissionID: .init()),
      .user(id: .mock_1, permission: .owner, permissionID: .init()),
    ]
    self.prepareSuccessfulShare()
    patch(
      \PermissionSnapshotService.forResource,
      with: always(.bootstrappedByOperator)
    )
    let requests: CriticalState<Array<RecordedShare>> = .init(.init())
    self.recordShareRequests(into: requests)

    let sut: ResourceShareConfirmation = try self.testedInstance()
    await verifyIfNotThrows(
      try await sut.applyToCreatedResource(.mock_1, .init(), confirmed, .empty)
    )

    await verifyIf(
      requests.get(),
      isEqual: [
        .init(granted: 1, updated: 0, deleted: 0),
        .init(granted: 0, updated: 1, deleted: 0),
      ],
      "The other owner is granted first, then the creator's own permission is lowered to what they inherit"
    )
  }

  /// The folder grants the operator access only through a group, so they hold no permission of their own on it
  /// and the bootstrap one is dropped. The group owns the resource by then, so nothing is left ownerless.
  func test_applyToCreatedResource_dropsTheBootstrapPermission_whenTheFolderGrantsThemNothingDirectly()
    async throws
  {
    let confirmed: OrderedSet<ResourcePermission> = [
      .userGroup(id: .mock_1, permission: .owner, permissionID: .init())
    ]
    self.prepareSuccessfulShare()
    patch(
      \PermissionSnapshotService.forResource,
      with: always(.bootstrappedByOperator)
    )
    let requests: CriticalState<Array<RecordedShare>> = .init(.init())
    self.recordShareRequests(into: requests)

    let sut: ResourceShareConfirmation = try self.testedInstance()
    await verifyIfNotThrows(
      try await sut.applyToCreatedResource(.mock_1, .init(), confirmed, .empty)
    )

    await verifyIf(
      requests.get(),
      isEqual: [
        .init(granted: 1, updated: 0, deleted: 0),
        .init(granted: 0, updated: 0, deleted: 1),
      ],
      "The group is granted access before the creator's own permission is revoked, never after"
    )
  }

  /// The capture taken to find the bootstrap permission may not name the operator - it is already gone. There is
  /// then nothing to send, and certainly nothing to fail over.
  func test_applyToCreatedResource_sendsNoOwnPermissionChange_whenTheCaptureDoesNotNameTheOperator() async throws {
    let confirmed: OrderedSet<ResourcePermission> = [
      .userGroup(id: .mock_1, permission: .owner, permissionID: .init())
    ]
    self.prepareSuccessfulShare()
    let requests: CriticalState<Array<RecordedShare>> = .init(.init())
    self.recordShareRequests(into: requests)

    let sut: ResourceShareConfirmation = try self.testedInstance()
    await verifyIfNotThrows(
      try await sut.applyToCreatedResource(.mock_1, .init(), confirmed, .empty)
    )

    await verifyIf(requests.get().count, isEqual: 1, "Only the grants go out")
  }

  /// Records what each share request carried, so a test can assert on how many went out and in what order.
  private func recordShareRequests(
    into requests: CriticalState<Array<RecordedShare>>
  ) {
    patch(
      \ResourceShareNetworkOperation.execute,
      with: { request in
        requests.access { (recorded: inout Array<RecordedShare>) in
          recorded.append(
            .init(
              granted: request.body.newPermissions.count,
              updated: request.body.updatedPermissions.count,
              deleted: request.body.deletedPermissions.count
            )
          )
        }
      }
    )
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

/// One share request reduced to what these tests assert on: how many permissions it granted, changed and revoked.
/// Recorded in order, so the sequence of requests is assertable too.
// swift-format-ignore: AlwaysUseLowerCamelCase
private struct RecordedShare: Equatable, Sendable {

  fileprivate let granted: Int
  fileprivate let updated: Int
  fileprivate let deleted: Int
}

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

  /// The created resource as the server holds it moments after creation: the operator's bootstrap owner
  /// permission, carrying the identifier only the server can supply.
  fileprivate static var bootstrappedByOperator: Self {
    .init(
      permissions: [.user(id: .mock_ada, permission: .owner, permissionID: .init())],
      users: .init(),
      groups: .init(),
      created: 0
    )
  }
}

// MARK: - Applying a confirmed share

/// Sharing never rotates the secret, so the revoke/re-encrypt/grant ordering collapses into one atomic call. The
/// operator's own change does not: the server evaluates a request against the principal making it.
// swift-format-ignore: AlwaysUseLowerCamelCase
extension ResourceShareConfirmationTests {

  /// Neither the drift check nor the share operation is patched here, so reaching either would trap on its
  /// placeholder: returning cleanly proves the whole apply was skipped.
  func test_applyToSharedResource_whenNothingChanged_appliesNothing() async throws {
    var snapshot: PermissionSnapshot = .empty
    snapshot.permissions = [.user(id: .mock_ada, permission: .owner, permissionID: .mock_1)]

    let sut: ResourceShareConfirmation = try self.testedInstance()

    await verifyIfNotThrows(
      try await sut.applyToSharedResource(.mock_1, snapshot.permissions, snapshot)
    )
  }

  /// The resource already exists, so unlike the create flow nothing has to be sent before drift can be measured.
  /// A change since the review must leave the resource exactly as it was.
  func test_applyToSharedResource_abortsOnDrift_withoutSendingAnything() async throws {
    var snapshot: PermissionSnapshot = .empty
    snapshot.permissions = [.user(id: .mock_ada, permission: .owner, permissionID: .mock_1)]
    snapshot.users[.mock_1] = PermissionSnapshotUser.mock(id: .mock_1)
    let confirmed: OrderedSet<ResourcePermission> = snapshot.permissions.union([
      .user(id: .mock_1, permission: .read, permissionID: .none)
    ])

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
    // Neither the share call nor the metadata migration is patched - reaching either traps on its placeholder.

    let sut: ResourceShareConfirmation = try self.testedInstance()

    await verifyIf(
      try await sut.applyToSharedResource(.mock_1, confirmed, snapshot),
      throws: PermissionDriftDetected.self
    )
  }

  /// A recipient the operator picked holds no permission on the resource yet, so a fresh capture does not describe
  /// them and their key would never be re-verified before the secret is encrypted for them.
  func test_applyToSharedResource_recapturesTheAddedRecipients_beforeCheckingDrift() async throws {
    var snapshot: PermissionSnapshot = .empty
    snapshot.permissions = [.user(id: .mock_ada, permission: .owner, permissionID: .mock_1)]
    snapshot.users[.mock_1] = PermissionSnapshotUser.mock(id: .mock_1)
    let confirmed: OrderedSet<ResourcePermission> = snapshot.permissions.union([
      .user(id: .mock_1, permission: .read, permissionID: .none)
    ])

    let recaptured: XCTestExpectation = .init(description: "the added recipient is recaptured")
    patch(
      \PermissionSnapshotService.expanding,
      with: { (current: PermissionSnapshot, addedUsers: Array<User.ID>, _) in
        XCTAssertEqual(addedUsers, [.mock_1], "the recipient the resource does not describe must be recaptured")
        recaptured.fulfill()
        return current
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
      try await sut.applyToSharedResource(.mock_1, confirmed, snapshot),
      throws: PermissionDriftDetected.self
    )
    await fulfillment(of: [recaptured], timeout: 1.0)
  }

  /// The dry-run runs against the server's view of group membership. A recipient it reports who was not in the
  /// reviewed snapshot is someone the operator never saw - drift, not a grant.
  func test_applyToSharedResource_throwsDrift_forARecipientTheOperatorNeverSaw() async throws {
    var snapshot: PermissionSnapshot = .empty
    snapshot.permissions = [.user(id: .mock_ada, permission: .owner, permissionID: .mock_1)]
    snapshot.users[.mock_1] = PermissionSnapshotUser.mock(id: .mock_1)
    let confirmed: OrderedSet<ResourcePermission> = snapshot.permissions.union([
      .user(id: .mock_1, permission: .read, permissionID: .none)
    ])

    patch(
      \PermissionSnapshotService.drift,
      with: always(.none)
    )
    patch(
      \ResourceSimulateShareNetworkOperation.execute,
      with: always(.init(changes: [.added: [.mock_2]]))
    )
    patch(
      \PermissionSnapshotService.unexpectedRecipients,
      with: always([.mock_2])
    )

    let sut: ResourceShareConfirmation = try self.testedInstance()

    await verifyIf(
      try await sut.applyToSharedResource(.mock_1, confirmed, snapshot),
      throws: PermissionDriftDetected.self
    )
  }

  /// The secret is not rotated: the recipients keeping access already hold the very same message, so only the ones
  /// gaining access receive one - encrypted with the key captured in the reviewed snapshot.
  func test_applyToSharedResource_encryptsTheExistingSecret_forAddedRecipientsOnly() async throws {
    var snapshot: PermissionSnapshot = .empty
    snapshot.permissions = [
      .user(id: .mock_ada, permission: .owner, permissionID: .mock_1),
      .user(id: .mock_2, permission: .read, permissionID: .mock_3),
    ]
    snapshot.users[.mock_1] = PermissionSnapshotUser.mock(id: .mock_1)
    snapshot.users[.mock_2] = PermissionSnapshotUser.mock(id: .mock_2)
    let confirmed: OrderedSet<ResourcePermission> = snapshot.permissions.union([
      .user(id: .mock_1, permission: .read, permissionID: .none)
    ])

    patch(
      \PermissionSnapshotService.drift,
      with: always(.none)
    )
    patch(
      \ResourceSimulateShareNetworkOperation.execute,
      with: always(.init(changes: [.added: [.mock_1]]))
    )
    let secretFetched: XCTestExpectation = .init(description: "the existing secret is fetched, never rotated")
    patch(
      \ResourceSecretFetchNetworkOperation.execute,
      with: { _ in
        secretFetched.fulfill()
        return .init(data: "encrypted-secret")
      }
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

    let shared: XCTestExpectation = .init(description: "the added recipient is granted with the secret")
    patch(
      \ResourceShareNetworkOperation.execute,
      with: { request in
        XCTAssertEqual(
          request.body.newSecrets.map(\.recipient),
          [.mock_1],
          "only the recipient gaining access needs the secret"
        )
        shared.fulfill()
      }
    )

    let sut: ResourceShareConfirmation = try self.testedInstance()

    await verifyIfNotThrows(
      try await sut.applyToSharedResource(.mock_1, confirmed, snapshot)
    )
    await fulfillment(of: [secretFetched, shared], timeout: 1.0)
  }

  /// Everyone else goes out together - no rotation, so no ordering hazard and no half-applied window. The
  /// operator's own downgrade follows, or the server evaluates the rest against a principal losing the right.
  func test_applyToSharedResource_appliesEveryoneElseFirst_andTheOperatorsOwnChangeSecond() async throws {
    var snapshot: PermissionSnapshot = .empty
    snapshot.permissions = [
      .user(id: .mock_ada, permission: .owner, permissionID: .mock_1),
      .user(id: .mock_1, permission: .read, permissionID: .mock_2),
    ]
    snapshot.users[.mock_ada] = PermissionSnapshotUser.mock(id: .mock_ada)
    snapshot.users[.mock_1] = PermissionSnapshotUser.mock(id: .mock_1)
    // The operator hands ownership over and steps down to read; the other recipient loses access entirely.
    let confirmed: OrderedSet<ResourcePermission> = [
      .user(id: .mock_ada, permission: .read, permissionID: .mock_1),
      .user(id: .mock_2, permission: .owner, permissionID: .none),
    ]
    snapshot.users[.mock_2] = PermissionSnapshotUser.mock(id: .mock_2)

    patch(
      \PermissionSnapshotService.drift,
      with: always(.none)
    )
    patch(
      \ResourceSimulateShareNetworkOperation.execute,
      with: always(.init(changes: [.added: [.mock_2]]))
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

    let calls: CriticalState<Array<ResourceShareNetworkOperationVariable>> = .init(.init())
    patch(
      \ResourceShareNetworkOperation.execute,
      with: { request in
        calls.access { (recorded: inout Array<ResourceShareNetworkOperationVariable>) in
          recorded.append(request)
        }
      }
    )

    let sut: ResourceShareConfirmation = try self.testedInstance()

    await verifyIfNotThrows(
      try await sut.applyToSharedResource(.mock_1, confirmed, snapshot)
    )

    let recorded: Array<ResourceShareNetworkOperationVariable> = calls.get()
    XCTAssertEqual(recorded.count, 2, "everyone else first, the operator's own change second")
    XCTAssertEqual(
      recorded.first?.body.newPermissions.count,
      1,
      "the new owner is granted in the first call"
    )
    XCTAssertEqual(
      recorded.first?.body.deletedPermissions.count,
      1,
      "the recipient losing access is revoked in the same call"
    )
    XCTAssertTrue(
      recorded.first?.body.updatedPermissions.isEmpty ?? false,
      "the operator's own downgrade must not travel with it"
    )
    XCTAssertEqual(
      recorded.last?.body.updatedPermissions.count,
      1,
      "the operator's own downgrade is applied last, on its own"
    )
    XCTAssertTrue(
      recorded.last?.body.newSecrets.isEmpty ?? false,
      "the operator already holds the secret"
    )
  }

  /// Everyone else's access already changed by then, so the reviewed list is stale by our own doing. Saying so is
  /// what stops the next attempt measuring drift against a change we made ourselves.
  func test_applyToSharedResource_reportsPartialApplication_whenTheOperatorsOwnChangeFails() async throws {
    var snapshot: PermissionSnapshot = .empty
    snapshot.permissions = [
      .user(id: .mock_ada, permission: .owner, permissionID: .mock_1)
    ]
    snapshot.users[.mock_ada] = PermissionSnapshotUser.mock(id: .mock_ada)
    snapshot.users[.mock_1] = PermissionSnapshotUser.mock(id: .mock_1)
    let confirmed: OrderedSet<ResourcePermission> = [
      .user(id: .mock_ada, permission: .read, permissionID: .mock_1),
      .user(id: .mock_1, permission: .owner, permissionID: .none),
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
    let refreshed: XCTestExpectation = .init(description: "the local copy is realigned with what did land")
    patch(
      \SessionData.refreshIfNeeded,
      with: {
        refreshed.fulfill()
      }
    )

    let calls: CriticalState<Int> = .init(0)
    patch(
      \ResourceShareNetworkOperation.execute,
      with: { _ in
        let index: Int = calls.access { (count: inout Int) -> Int in
          count += 1
          return count
        }
        guard index > 1
        else { return }
        throw MockIssue.error()
      }
    )

    let sut: ResourceShareConfirmation = try self.testedInstance()

    await verifyIf(
      try await sut.applyToSharedResource(.mock_1, confirmed, snapshot),
      throws: PermissionsPartiallyApplied.self
    )
    await fulfillment(of: [refreshed], timeout: 1.0)
  }

  /// The server rejects an ownerless resource. The confirmation screen does not offer removing the last owner, and
  /// nothing else re-checks it, so the rule has to hold where the change is actually made.
  func test_applyToSharedResource_throwsMissingResourceOwner_whenNoOwnerRemains() async throws {
    var snapshot: PermissionSnapshot = .empty
    snapshot.permissions = [
      .user(id: .mock_ada, permission: .owner, permissionID: .mock_1)
    ]
    let confirmed: OrderedSet<ResourcePermission> = [
      .user(id: .mock_ada, permission: .read, permissionID: .mock_1)
    ]

    let sut: ResourceShareConfirmation = try self.testedInstance()

    await verifyIf(
      try await sut.applyToSharedResource(.mock_1, confirmed, snapshot),
      throws: MissingResourceOwner.self
    )
  }

  /// A metadata key that cannot be trusted stops the share before anything is sent - the drift check and the share
  /// call are left unpatched, so reaching either would trap on its placeholder.
  func test_applyToSharedResource_sendsNothing_whenThePinnedKeyIsInvalid() async throws {
    var snapshot: PermissionSnapshot = .empty
    snapshot.permissions = [.user(id: .mock_ada, permission: .owner, permissionID: .mock_1)]
    snapshot.users[.mock_1] = PermissionSnapshotUser.mock(id: .mock_1)
    let confirmed: OrderedSet<ResourcePermission> = snapshot.permissions.union([
      .user(id: .mock_1, permission: .read, permissionID: .none)
    ])

    patch(
      \MetadataKeysService.validatePinnedKey,
      with: always(.invalid(.unknown))
    )

    let sut: ResourceShareConfirmation = try self.testedInstance()

    await verifyIf(
      try await sut.applyToSharedResource(.mock_1, confirmed, snapshot),
      throws: MetadataPinnedKeyValidationError.self
    )
  }
}
