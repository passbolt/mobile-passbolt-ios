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

import TestExtensions

@testable import PassboltResources

/// `ConfirmedPermissionsDiff` decides which recipients are granted, updated and revoked - and through the
/// snapshot expansion, who the secret is encrypted for. Every flow applying confirmed permissions shares it.
// swift-format-ignore: AlwaysUseLowerCamelCase
final class ConfirmedPermissionsDiffTests: FeaturesTestCase {

  func test_diff_whenNothingChanged_isEmptyInEveryDirection() async throws {
    let original: OrderedSet<ResourcePermission> = Self.original()
    let diff: ConfirmedPermissionsDiff = .init(confirmed: original, original: original)

    await verifyIf(diff.created.isEmpty, isEqual: true, "Nothing is granted when nothing changed")
    await verifyIf(diff.updated.isEmpty, isEqual: true, "Nothing is updated when nothing changed")
    await verifyIf(diff.deleted.isEmpty, isEqual: true, "Nothing is revoked when nothing changed")
  }

  func test_diff_treatsAPermissionWithoutIdentifierAsCreated() async throws {
    let original: OrderedSet<ResourcePermission> = Self.original()
    var confirmed: OrderedSet<ResourcePermission> = original
    confirmed.append(.user(id: .mock_2, permission: .read, permissionID: .none))

    let diff: ConfirmedPermissionsDiff = .init(confirmed: confirmed, original: original)

    await verifyIf(
      diff.created,
      isEqual: [.user(id: .mock_2, permission: .read, permissionID: .none)],
      "A recipient carrying no permission identifier is a new grant"
    )
    await verifyIf(diff.deleted.isEmpty, isEqual: true, "Adding a recipient revokes nobody")
  }

  func test_diff_treatsALevelChangeAsUpdated_notAsCreated() async throws {
    let original: OrderedSet<ResourcePermission> = Self.original()
    let confirmed: OrderedSet<ResourcePermission> = [
      .user(id: .mock_ada, permission: .owner, permissionID: Self.adaPermissionID),
      .user(id: .mock_1, permission: .owner, permissionID: Self.otherPermissionID),  // read -> owner
    ]

    let diff: ConfirmedPermissionsDiff = .init(confirmed: confirmed, original: original)

    await verifyIf(
      diff.updated,
      isEqual: [.user(id: .mock_1, permission: .owner, permissionID: Self.otherPermissionID)],
      "An upgraded recipient is updated in place"
    )
    await verifyIf(diff.created.isEmpty, isEqual: true, "An upgrade grants no new access")
    await verifyIf(diff.deleted.isEmpty, isEqual: true, "An upgrade revokes nobody")
  }

  func test_diff_treatsAnAbsentRecipientAsDeleted() async throws {
    let original: OrderedSet<ResourcePermission> = Self.original()
    let confirmed: OrderedSet<ResourcePermission> = [
      .user(id: .mock_ada, permission: .owner, permissionID: Self.adaPermissionID)
    ]

    let diff: ConfirmedPermissionsDiff = .init(confirmed: confirmed, original: original)

    await verifyIf(
      diff.deleted,
      isEqual: [.user(id: .mock_1, permission: .read, permissionID: Self.otherPermissionID)],
      "A recipient dropped from the confirmed set loses access"
    )
    await verifyIf(diff.created.isEmpty, isEqual: true, "A removal grants nobody")
  }

  func test_diff_matchesRecipientsAcrossReissuedPermissionIdentifiers() async throws {
    // The server re-issued the same grant under a new identifier. That is not a change to the recipient set, so
    // it must not read as "the old permission was revoked and a different one created".
    let original: OrderedSet<ResourcePermission> = Self.original()
    let confirmed: OrderedSet<ResourcePermission> = [
      .user(id: .mock_ada, permission: .owner, permissionID: Self.adaPermissionID),
      .user(id: .mock_1, permission: .read, permissionID: .init()),
    ]

    let diff: ConfirmedPermissionsDiff = .init(confirmed: confirmed, original: original)

    await verifyIf(diff.deleted.isEmpty, isEqual: true, "The recipient still holds access, under a new identifier")
    await verifyIf(diff.updated.isEmpty, isEqual: true, "The level is unchanged")
    await verifyIf(diff.created.isEmpty, isEqual: true, "The grant already exists")
  }

  func test_kept_returnsOnlyRecipientsThatAlreadyHoldAccess() async throws {
    let original: OrderedSet<ResourcePermission> = Self.original()
    var confirmed: OrderedSet<ResourcePermission> = original
    confirmed.append(.user(id: .mock_2, permission: .read, permissionID: .none))
    let diff: ConfirmedPermissionsDiff = .init(confirmed: confirmed, original: original)

    await verifyIf(
      OrderedSet(diff.kept.compactMap(\.userID)),
      isEqual: [.mock_ada, .mock_1],
      "The newly added recipient is granted separately - the rotated secret goes to the current holders"
    )
  }

  func test_recipients_expandsGroupsThroughTheSnapshotMembership() async throws {
    let groupID: UserGroup.ID = .init()
    let snapshot: PermissionSnapshot = .init(
      permissions: [.userGroup(id: groupID, permission: .read, permissionID: .init())],
      users: .init(),
      groups: [groupID: .init(id: groupID, name: "Group", members: [.mock_1, .mock_2])],
      created: 0
    )

    await verifyIf(
      snapshot.recipients(of: snapshot.permissions),
      isEqual: [.mock_1, .mock_2],
      "A group permission names every member the secret has to be encrypted for"
    )
  }

  func test_recipients_skipsAGroupTheSnapshotDoesNotDescribe() async throws {
    let snapshot: PermissionSnapshot = .init(
      permissions: .init(),
      users: .init(),
      groups: .init(),
      created: 0
    )

    await verifyIf(
      snapshot.recipients(of: [.userGroup(id: .init(), permission: .read, permissionID: .init())]).isEmpty,
      isEqual: true,
      "An unknown group yields no recipients - encryption fails closed rather than guessing membership"
    )
  }

  /// A snapshot is captured complete (an unanswered id throws instead), so a user it does not describe is one the
  /// server returned without a usable key: nobody can encrypt for them and the server expects no secret either.
  func test_recipients_skipsAUserTheSnapshotDoesNotDescribe() async throws {
    let describedPermission: ResourcePermission = .user(
      id: .mock_ada,
      permission: .owner,
      permissionID: .init()
    )
    let snapshot: PermissionSnapshot = .init(
      permissions: [describedPermission],
      users: [.mock_ada: PermissionSnapshotUser.mock(id: .mock_ada)],
      groups: .init(),
      created: 0
    )

    await verifyIf(
      snapshot.recipients(
        of: [describedPermission, .user(id: .mock_2, permission: .read, permissionID: .init())]
      ),
      isEqual: [.mock_ada],
      "A recipient the snapshot cannot describe holds no key, so no secret is prepared for them"
    )
  }
}

// swift-format-ignore: AlwaysUseLowerCamelCase
extension ConfirmedPermissionsDiffTests {

  fileprivate nonisolated static let adaPermissionID: Permission.ID = .init()
  fileprivate nonisolated static let otherPermissionID: Permission.ID = .init()

  /// The operator (`.mock_ada`, owner) plus one other direct member (`.mock_1`, read).
  fileprivate static func original() -> OrderedSet<ResourcePermission> {
    [
      .user(id: .mock_ada, permission: .owner, permissionID: Self.adaPermissionID),
      .user(id: .mock_1, permission: .read, permissionID: Self.otherPermissionID),
    ]
  }
}
