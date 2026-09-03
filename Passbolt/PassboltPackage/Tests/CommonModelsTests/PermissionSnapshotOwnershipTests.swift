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

import XCTest

@testable import CommonModels

/// Ownership is what the confirmation screen validates before letting a change through, and the server resolves it
/// through groups - so a direct owner row is not the only thing that counts, and losing the group that owns on the
/// operator's behalf costs them ownership just as surely as losing their own row.
final class PermissionSnapshotOwnershipTests: XCTestCase {

  private let operatorID: User.ID = .init()
  private let otherID: User.ID = .init()
  private let groupID: UserGroup.ID = .init()

  func test_grantsOwnership_whenTheOperatorHoldsItDirectly() {
    let snapshot: PermissionSnapshot = self.snapshot()

    XCTAssertTrue(
      snapshot.grantsOwnership(
        to: self.operatorID,
        in: [.user(id: self.operatorID, permission: .owner, permissionID: .none)]
      )
    )
  }

  func test_doesNotGrantOwnership_whenTheOperatorHoldsALowerLevel() {
    let snapshot: PermissionSnapshot = self.snapshot()

    XCTAssertFalse(
      snapshot.grantsOwnership(
        to: self.operatorID,
        in: [.user(id: self.operatorID, permission: .write, permissionID: .none)]
      )
    )
  }

  func test_doesNotGrantOwnership_whenSomebodyElseOwns() {
    let snapshot: PermissionSnapshot = self.snapshot()

    XCTAssertFalse(
      snapshot.grantsOwnership(
        to: self.operatorID,
        in: [.user(id: self.otherID, permission: .owner, permissionID: .none)]
      )
    )
  }

  /// The hand-over case: the operator keeps ownership through a group they belong to.
  func test_grantsOwnership_whenAnOwnerGroupContainsTheOperator() {
    let snapshot: PermissionSnapshot = self.snapshot(groupMembers: [self.operatorID, self.otherID])

    XCTAssertTrue(
      snapshot.grantsOwnership(
        to: self.operatorID,
        in: [.userGroup(id: self.groupID, permission: .owner, permissionID: .none)]
      )
    )
  }

  func test_doesNotGrantOwnership_whenTheOwnerGroupExcludesTheOperator() {
    let snapshot: PermissionSnapshot = self.snapshot(groupMembers: [self.otherID])

    XCTAssertFalse(
      snapshot.grantsOwnership(
        to: self.operatorID,
        in: [.userGroup(id: self.groupID, permission: .owner, permissionID: .none)]
      )
    )
  }

  /// Membership alone is not ownership - the group has to own.
  func test_doesNotGrantOwnership_whenTheOperatorsGroupHoldsALowerLevel() {
    let snapshot: PermissionSnapshot = self.snapshot(groupMembers: [self.operatorID])

    XCTAssertFalse(
      snapshot.grantsOwnership(
        to: self.operatorID,
        in: [.userGroup(id: self.groupID, permission: .write, permissionID: .none)]
      )
    )
  }

  /// A group the capture never described contributes nothing - it fails closed rather than guessing membership.
  func test_doesNotGrantOwnership_whenTheSnapshotDoesNotDescribeTheGroup() {
    let snapshot: PermissionSnapshot = self.snapshot()

    XCTAssertFalse(
      snapshot.grantsOwnership(
        to: self.operatorID,
        in: [.userGroup(id: self.groupID, permission: .owner, permissionID: .none)]
      )
    )
  }

  func test_doesNotGrantOwnership_whenNothingIsGranted() {
    let snapshot: PermissionSnapshot = self.snapshot()

    XCTAssertFalse(snapshot.grantsOwnership(to: self.operatorID, in: .init()))
  }

  private func snapshot(
    groupMembers: OrderedSet<User.ID>? = .none
  ) -> PermissionSnapshot {
    var groups: OrderedDictionary<UserGroup.ID, PermissionSnapshotGroup> = .init()
    if let groupMembers: OrderedSet<User.ID> = groupMembers {
      groups[self.groupID] = .init(
        id: self.groupID,
        name: "Group",
        members: groupMembers
      )
    }
    return .init(
      permissions: .init(),
      users: .init(),
      groups: groups,
      created: 0
    )
  }
}
