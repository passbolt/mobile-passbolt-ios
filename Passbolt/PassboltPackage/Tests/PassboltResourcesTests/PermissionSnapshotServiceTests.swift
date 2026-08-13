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
import OSFeatures
import TestExtensions

import struct Foundation.Date

@testable import PassboltResources

// swift-format-ignore: AlwaysUseLowerCamelCase
final class PermissionSnapshotServiceTests: FeaturesTestCase {

  override func commonPrepare() async throws {
    try await super.commonPrepare()
    register(
      { $0.usePassboltPermissionSnapshotService() },
      for: PermissionSnapshotService.self
    )
    set(
      SessionScope.self,
      context: .init(
        account: .mock_ada,
        configuration: .mock_default
      )
    )
    patch(
      \OSTime.timestamp,
      with: always(0)
    )
  }

  func test_drift_whenSnapshotsAreIdentical_returnsNoDrift() async throws {
    let sut: PermissionSnapshotService = try self.testedInstance()
    let snapshot: PermissionSnapshot = Self.snapshot()

    await verifyIf(
      sut.drift(snapshot, snapshot).hasDrift,
      isEqual: false,
      "Identical snapshots must not report drift"
    )
  }

  func test_drift_whenPermissionLevelChanges_reportsChangedPermissions() async throws {
    let sut: PermissionSnapshotService = try self.testedInstance()
    let confirmed: PermissionSnapshot = Self.snapshot(adaPermission: .read)
    let current: PermissionSnapshot = Self.snapshot(adaPermission: .owner)

    let drift: PermissionDrift = sut.drift(confirmed, current)
    await verifyIf(
      drift.changedPermissions,
      isEqual: true,
      "A changed permission level must be reported as permission drift"
    )
  }

  func test_drift_whenArecipientFingerprintChanges_reportsChangedFingerprints() async throws {
    let sut: PermissionSnapshotService = try self.testedInstance()
    let confirmed: PermissionSnapshot = Self.snapshot(adaFingerprint: "FP_ADA")
    let current: PermissionSnapshot = Self.snapshot(adaFingerprint: "FP_ADA_TAMPERED")

    let drift: PermissionDrift = sut.drift(confirmed, current)
    await verifyIf(
      drift.changedFingerprints,
      isEqual: true,
      "A substituted recipient key fingerprint must be reported as fingerprint drift"
    )
  }

  func test_drift_whenGroupMembershipChanges_reportsChangedMemberships() async throws {
    let sut: PermissionSnapshotService = try self.testedInstance()
    let groupID: UserGroup.ID = .init()
    let confirmed: PermissionSnapshot = Self.snapshotWithGroup(groupID: groupID, members: [.mock_1])
    let current: PermissionSnapshot = Self.snapshotWithGroup(groupID: groupID, members: [.mock_1, .mock_2])

    let drift: PermissionDrift = sut.drift(confirmed, current)
    await verifyIf(
      drift.changedMemberships,
      isEqual: true,
      "Someone added to an already-permitted group must be reported as membership drift"
    )
  }

  func test_drift_whenSnapshotsAreIdentical_namesNoRecipients() async throws {
    let sut: PermissionSnapshotService = try self.testedInstance()
    let snapshot: PermissionSnapshot = Self.snapshot()

    await verifyIf(
      sut.drift(snapshot, snapshot).changedRecipients.isEmpty,
      isEqual: true,
      "No recipient may be named when nothing changed"
    )
  }

  func test_drift_whenPermissionLevelChanges_namesTheRecipient() async throws {
    let sut: PermissionSnapshotService = try self.testedInstance()
    let confirmed: PermissionSnapshot = Self.snapshot(adaPermission: .read)
    let current: PermissionSnapshot = Self.snapshot(adaPermission: .owner)

    await verifyIf(
      sut.drift(confirmed, current).changedRecipients,
      isEqual: ["First Last"],
      "The recipient whose level changed must be named, once"
    )
  }

  func test_drift_whenArecipientFingerprintChanges_namesTheRecipient() async throws {
    let sut: PermissionSnapshotService = try self.testedInstance()
    let confirmed: PermissionSnapshot = Self.snapshot(adaFingerprint: "FP_ADA")
    let current: PermissionSnapshot = Self.snapshot(adaFingerprint: "FP_ADA_TAMPERED")

    await verifyIf(
      sut.drift(confirmed, current).changedRecipients,
      isEqual: ["First Last"],
      "The recipient whose key changed must be named"
    )
  }

  func test_drift_whenGroupMembershipChanges_namesTheGroup() async throws {
    let sut: PermissionSnapshotService = try self.testedInstance()
    let groupID: UserGroup.ID = .init()
    let confirmed: PermissionSnapshot = Self.snapshotWithGroup(groupID: groupID, members: [.mock_1])
    let current: PermissionSnapshot = Self.snapshotWithGroup(groupID: groupID, members: [.mock_1, .mock_2])

    await verifyIf(
      sut.drift(confirmed, current).changedRecipients,
      isEqual: ["Group"],
      "The group whose membership changed must be named"
    )
  }

  func test_driftMessage_namesASingleChangedRecipient() async throws {
    let drift: PermissionDrift = .init(
      changedPermissions: true,
      changedFingerprints: false,
      changedMemberships: false,
      changedRecipients: ["First Last"]
    )

    await verifyIf(
      Self.resolve(drift.displayableMessage),
      isEqual: "resource.permission.confirm.drift.single.message|First Last"
    )
  }

  func test_driftMessage_namesTheFirstOfSeveralChangedRecipients() async throws {
    let drift: PermissionDrift = .init(
      changedPermissions: true,
      changedFingerprints: false,
      changedMemberships: false,
      changedRecipients: ["First Last", "Other Person"]
    )

    await verifyIf(
      Self.resolve(drift.displayableMessage),
      isEqual: "resource.permission.confirm.drift.multiple.message|First Last"
    )
  }

  func test_driftMessage_whenNoRecipientIsNamed_fallsBackToTheGenericMessage() async throws {
    await verifyIf(
      Self.resolve(PermissionDrift.none.displayableMessage),
      isEqual: "resource.permission.confirm.drift.message|%@"
    )
  }

  func test_unexpectedRecipients_returnsRecipientsAbsentFromConfirmedSnapshot() async throws {
    let sut: PermissionSnapshotService = try self.testedInstance()
    let confirmed: PermissionSnapshot = Self.snapshot()  // contains only .mock_ada

    await verifyIf(
      sut.unexpectedRecipients(confirmed, [.mock_ada, .mock_2]),
      isEqual: [.mock_2],
      "A dry-run recipient absent from the confirmed snapshot must be reported as unexpected"
    )
  }

  func test_unexpectedRecipients_whenAllRecipientsConfirmed_returnsEmpty() async throws {
    let sut: PermissionSnapshotService = try self.testedInstance()
    let confirmed: PermissionSnapshot = Self.snapshot()  // contains only .mock_ada

    await verifyIf(
      sut.unexpectedRecipients(confirmed, [.mock_ada]).isEmpty,
      isEqual: true,
      "No unexpected recipients when every dry-run recipient is in the snapshot"
    )
  }

  // MARK: - Capturing a snapshot

  func test_forResource_capturesTheGrantedUsersAndTheirKeys() async throws {
    self.patchResourceFetch(permissions: [Self.userPermission(userID: .mock_ada)])
    patch(
      \UsersFetchByIDsNetworkOperation.execute,
      with: always([.create(id: .mock_ada, fingerprint: "FP_ADA", publicKey: "KEY_ADA")])
    )
    let sut: PermissionSnapshotService = try self.testedInstance()

    let snapshot: PermissionSnapshot = try await sut.forResource(.mock_1)
    await verifyIf(
      snapshot.user(.mock_ada)?.publicKey == "KEY_ADA",
      isEqual: true,
      "The granted user must be captured with the key the secret would be encrypted with"
    )
  }

  /// A member the server describes without a usable key (never activated, deleted) cannot hold a secret. Keeping
  /// them in the membership would both list a recipient that receives nothing and make the encryption fail.
  func test_forResource_leavesGroupMembersWithoutAUsableKeyOutOfTheMembership() async throws {
    let groupID: UserGroup.ID = .init()
    self.patchResourceFetch(permissions: [Self.groupPermission(groupID: groupID)])
    patch(
      \UserGroupsFetchByIDsNetworkOperation.execute,
      with: always([.create(id: groupID, memberIDs: [.mock_1, .mock_2])])
    )
    patch(
      \UsersFetchByIDsNetworkOperation.execute,
      with: always([
        .create(id: .mock_1),
        .create(id: .mock_2, active: false, hasKey: false),  // invited, no key yet
      ])
    )
    let sut: PermissionSnapshotService = try self.testedInstance()

    let snapshot: PermissionSnapshot = try await sut.forResource(.mock_1)
    await verifyIf(
      snapshot.group(groupID)?.members == [.mock_1],
      isEqual: true,
      "Only members that can actually hold the secret may be captured as group membership"
    )
    await verifyIf(
      snapshot.user(.mock_2) == nil,
      isEqual: true,
      "A member without a usable key must not be described as a recipient"
    )
  }

  /// A response short of the requested ids (truncated, paginated) would silently shrink the reviewed recipient
  /// list, so capturing fails instead of producing an incomplete snapshot.
  func test_forResource_whenAUserIsNotAnswered_throwsSnapshotIncomplete() async throws {
    let groupID: UserGroup.ID = .init()
    self.patchResourceFetch(permissions: [Self.groupPermission(groupID: groupID)])
    patch(
      \UserGroupsFetchByIDsNetworkOperation.execute,
      with: always([.create(id: groupID, memberIDs: [.mock_1, .mock_2])])
    )
    patch(
      \UsersFetchByIDsNetworkOperation.execute,
      with: always([.create(id: .mock_1)])  // .mock_2 was requested but never answered
    )
    let sut: PermissionSnapshotService = try self.testedInstance()

    await verifyIf(
      try await sut.forResource(.mock_1),
      throws: PermissionSnapshotIncomplete.self,
      "A by-ids response short of the requested ids must not yield a snapshot"
    )
  }

  /// An unanswered group is the wider version of the same gap: its whole membership would be missing, hiding the
  /// group from the reviewed list and leaving its members out of a secret rotation they still hold access for.
  func test_forResource_whenAGroupIsNotAnswered_throwsSnapshotIncomplete() async throws {
    let answeredGroupID: UserGroup.ID = .init()
    let unansweredGroupID: UserGroup.ID = .init()
    self.patchResourceFetch(
      permissions: [
        Self.groupPermission(groupID: answeredGroupID),
        Self.groupPermission(groupID: unansweredGroupID),
      ]
    )
    patch(
      \UserGroupsFetchByIDsNetworkOperation.execute,
      with: always([.create(id: answeredGroupID, memberIDs: [.mock_1])])
    )
    patch(
      \UsersFetchByIDsNetworkOperation.execute,
      with: always([.create(id: .mock_1)])
    )
    let sut: PermissionSnapshotService = try self.testedInstance()

    await verifyIf(
      try await sut.forResource(.mock_1),
      throws: PermissionSnapshotIncomplete.self,
      "A group the server did not answer for must not yield a snapshot missing that recipient"
    )
  }

  func test_forResource_whenEveryGroupIsAnswered_capturesThemAll() async throws {
    let firstGroupID: UserGroup.ID = .init()
    let secondGroupID: UserGroup.ID = .init()
    self.patchResourceFetch(
      permissions: [
        Self.groupPermission(groupID: firstGroupID),
        Self.groupPermission(groupID: secondGroupID),
      ]
    )
    patch(
      \UserGroupsFetchByIDsNetworkOperation.execute,
      with: always([
        .create(id: firstGroupID, memberIDs: [.mock_1]),
        .create(id: secondGroupID, memberIDs: [.mock_2]),
      ])
    )
    patch(
      \UsersFetchByIDsNetworkOperation.execute,
      with: always([.create(id: .mock_1), .create(id: .mock_2)])
    )
    let sut: PermissionSnapshotService = try self.testedInstance()

    let snapshot: PermissionSnapshot = try await sut.forResource(.mock_1)
    await verifyIf(
      snapshot.group(firstGroupID) != nil && snapshot.group(secondGroupID) != nil,
      isEqual: true,
      "Every answered group must be captured in the snapshot"
    )
  }

  // MARK: - Recipients missing between snapshots

  func test_recipientsMissing_namesTheRecipientsTheOtherSnapshotDoesNotDescribe() async throws {
    let groupID: UserGroup.ID = .init()
    let confirmed: PermissionSnapshot = .init(
      permissions: [],
      users: [
        .mock_1: PermissionSnapshotUser.mock(id: .mock_1),
        .mock_2: PermissionSnapshotUser.mock(id: .mock_2),
      ],
      groups: [groupID: .init(id: groupID, name: "Group", members: [.mock_1])],
      created: 0
    )
    let current: PermissionSnapshot = .init(
      permissions: [],
      users: [.mock_1: PermissionSnapshotUser.mock(id: .mock_1)],
      groups: .init(),
      created: 0
    )

    let missing: (users: Array<User.ID>, groups: Array<UserGroup.ID>) = confirmed.recipientsMissing(from: current)
    await verifyIf(
      missing.users == [.mock_2],
      isEqual: true,
      "A user the other snapshot does not describe must be named"
    )
    await verifyIf(
      missing.groups == [groupID],
      isEqual: true,
      "A group the other snapshot does not describe must be named"
    )
  }

  func test_recipientsMissing_whenTheOtherSnapshotDescribesEveryone_namesNobody() async throws {
    let snapshot: PermissionSnapshot = Self.snapshot()

    let missing: (users: Array<User.ID>, groups: Array<UserGroup.ID>) = snapshot.recipientsMissing(from: snapshot)
    await verifyIf(
      missing.users.isEmpty && missing.groups.isEmpty,
      isEqual: true,
      "A snapshot compared against itself must report no missing recipients"
    )
  }
}

// swift-format-ignore: AlwaysUseLowerCamelCase
extension PermissionSnapshotServiceTests {

  /// Answers the single-resource fetch with the given permission list. Groups resolve to nothing unless the test
  /// patches the groups fetch too, which is what a permission list of plain users needs.
  fileprivate func patchResourceFetch(
    permissions: OrderedSet<GenericPermissionDTO>
  ) {
    let resource: ResourceDTO = .mock_1.with { $0.permissions = permissions }
    patch(
      \ResourceFetchNetworkOperation.execute,
      with: always(resource)
    )
  }

  fileprivate static func userPermission(
    userID: User.ID
  ) -> GenericPermissionDTO {
    .userToResource(
      id: .init(),
      userID: userID,
      resourceID: .mock_1,
      permission: .owner
    )
  }

  fileprivate static func groupPermission(
    groupID: UserGroup.ID
  ) -> GenericPermissionDTO {
    .userGroupToResource(
      id: .init(),
      userGroupID: groupID,
      resourceID: .mock_1,
      permission: .read
    )
  }

  /// Resolves a message without relying on the localization bundle, so both the chosen key and the substituted
  /// argument can be asserted: the stubbed lookup yields `<key>|%@`.
  fileprivate static func resolve(
    _ message: DisplayableString
  ) -> String {
    message.string(
      localizaton: { (key: LocalizedString.Key, _, _) -> String in "\(key.rawValue)|%@" }
    )
  }

  /// Snapshot with a single direct user permission for `.mock_ada`.
  fileprivate static func snapshot(
    adaPermission: Permission = .owner,
    adaFingerprint: Fingerprint = "FP_ADA"
  ) -> PermissionSnapshot {
    .init(
      permissions: [
        .user(id: .mock_ada, permission: adaPermission, permissionID: .init())
      ],
      users: [
        .mock_ada: PermissionSnapshotUser.mock(id: .mock_ada, fingerprint: adaFingerprint)
      ],
      groups: .init(),
      created: 0
    )
  }

  /// Snapshot with a single group permission and the given membership.
  fileprivate static func snapshotWithGroup(
    groupID: UserGroup.ID,
    members: OrderedSet<User.ID>
  ) -> PermissionSnapshot {
    var users: OrderedDictionary<User.ID, PermissionSnapshotUser> = .init()
    for memberID: User.ID in members {
      users[memberID] = PermissionSnapshotUser.mock(id: memberID)
    }
    return .init(
      permissions: [
        .userGroup(id: groupID, permission: .read, permissionID: .init())
      ],
      users: users,
      groups: [
        groupID: .init(id: groupID, name: "Group", members: members)
      ],
      created: 0
    )
  }
}

extension UserGroupDTO {

  fileprivate static func create(
    id: UserGroup.ID,
    memberIDs: Array<User.ID>
  ) -> UserGroupDTO {
    .init(
      id: id,
      name: "Group",
      userReferences: memberIDs.map { (memberID: User.ID) in .init(id: memberID) }
    )
  }
}

extension UserDTO {

  fileprivate static func create(
    id: User.ID,
    active: Bool = true,
    hasKey: Bool = true,
    fingerprint: Fingerprint = "FP",
    publicKey: ArmoredPGPPublicKey = "KEY"
  ) -> UserDTO {
    .init(
      id: id,
      active: active,
      deleted: false,
      username: "user@passbolt.com",
      profile: .init(
        firstName: "First",
        lastName: "Last",
        avatar: .init(urlString: "https://passbolt.com/avatar")
      ),
      key: hasKey ? .create(fingerprint: fingerprint, publicKey: publicKey) : .none,
      role: "user",
      isSuspended: false
    )
  }

}

extension PGPKeyDetails {

  fileprivate static func create(
    fingerprint: Fingerprint,
    publicKey: ArmoredPGPPublicKey
  ) -> PGPKeyDetails {
    .init(
      publicKey: publicKey,
      userID: "uid",
      fingerprint: fingerprint,
      length: 4096,
      algorithm: "rsa",
      created: Date(timeIntervalSince1970: 0),
      expires: .none
    )
  }
}
