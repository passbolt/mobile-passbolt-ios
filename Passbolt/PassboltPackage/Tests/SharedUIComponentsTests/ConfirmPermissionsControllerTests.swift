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
import OSFeatures
import SessionData
import Shared
import TestExtensions
import Users

@testable import Display
@testable import Resources
@testable import SharedUIComponents

/// The screen the operator reviews recipients on before a secret is encrypted for them. Everything it enforces is a
/// rule about who ends up holding the secret: which recipients are shown, which of them may be changed, and what is
/// handed to the flow on confirmation.
///
/// The operator's own row carries the heaviest of those rules. It is the only thing keeping a resource from ending
/// up without an owner - there is no owner validation behind it - so its immutability is asserted from both ends:
/// the boundary that rejects the change, and the row and details screen that never offer it.
// swift-format-ignore: AlwaysUseLowerCamelCase, NeverForceUnwrap
final class ConfirmPermissionsControllerTests: FeaturesTestCase {

  /// Recipient sets handed to the flow on confirmation, in order.
  private let confirmedPermissions: CriticalState<Array<OrderedSet<ResourcePermission>>> = .init(.init())
  /// Snapshots handed to the flow alongside them - after a refresh this is no longer the one the screen opened with.
  private let confirmedSnapshots: CriticalState<Array<PermissionSnapshot>> = .init(.init())
  /// What the flow reports back for the next confirmation.
  private let confirmationOutcome: CriticalState<ConfirmPermissionsOutcome> = .init(.applied)
  private let cancellations: CriticalState<Int> = .init(0)

  override func commonPrepare() async throws {
    try await super.commonPrepare()

    set(
      SessionScope.self,
      context: .init(
        account: .mock_ada,
        configuration: .mock_default
      )
    )

    patch(
      \SessionData.refreshUsersAndGroups,
      with: always(Void())
    )
    patch(
      \Users.userAvatarImage,
      with: always(Data?.none)
    )
    patch(
      \NavigationToConfirmPermissions.mockRevert,
      with: always(Void())
    )
  }

  /// The screen as the presenting flow opens it. `onConfirm` records what it was handed and answers with whatever
  /// the test set as the outcome.
  private func tested(
    mode: ConfirmPermissionsMode = .edit(editable: true),
    snapshot: PermissionSnapshot = .mock_shared
  ) throws -> ConfirmPermissionsController {
    try self.testedInstance(
      context: .init(
        mode: mode,
        snapshot: snapshot,
        operatorID: .mock_ada,
        onConfirm: { (confirmed: OrderedSet<ResourcePermission>, snapshot: PermissionSnapshot) in
          self.confirmedPermissions.access { (sets: inout Array<OrderedSet<ResourcePermission>>) in
            sets.append(confirmed)
          }
          self.confirmedSnapshots.access { (snapshots: inout Array<PermissionSnapshot>) in
            snapshots.append(snapshot)
          }
          return self.confirmationOutcome.get()
        },
        onCancel: {
          self.cancellations.access { (count: inout Int) in count += 1 }
        }
      )
    )
  }

  /// The rows currently rendered, as the recipient they grant access to paired with whether they may be changed.
  private func rows(
    of tested: ConfirmPermissionsController
  ) async -> Array<RenderedRow> {
    await tested.viewState.current.rows
      .map { (row: ConfirmPermissionRowItem) -> RenderedRow in
        .init(recipient: row.recipientID, editable: row.isEditable)
      }
  }

  /// The level a recipient currently holds in the rendered list, or `.none` when no row grants them access.
  private func level(
    of recipient: String,
    in tested: ConfirmPermissionsController
  ) async -> Permission? {
    await tested.viewState.current.rows
      .first(where: { (row: ConfirmPermissionRowItem) -> Bool in row.recipientID == recipient })?
      .level
  }
}

// MARK: - The operator's own row

// swift-format-ignore: AlwaysUseLowerCamelCase, NeverForceUnwrap
extension ConfirmPermissionsControllerTests {

  /// The operator must remain an owner. Nothing behind this screen re-checks it, so the guard has to hold at the
  /// controller boundary and not only in the view that hides the affordance.
  func test_setUserPermission_isIgnored_forTheOperatorsOwnRow() async throws {
    let tested: ConfirmPermissionsController = try self.tested()

    tested.setUserPermission(.mock_ada, to: .read)

    let level: Permission? = await self.level(of: "user-\(User.ID.mock_ada)", in: tested)
    XCTAssertEqual(level, .owner, "The operator must keep the ownership they opened the screen with")
  }

  func test_removeUser_isIgnored_forTheOperatorsOwnRow() async throws {
    let tested: ConfirmPermissionsController = try self.tested()

    tested.removeUser(.mock_ada)

    let rows: Array<RenderedRow> = await self.rows(of: tested)
    XCTAssertTrue(
      rows.contains(where: { $0.recipient == "user-\(User.ID.mock_ada)" }),
      "The operator may not remove themselves - the resource would be left without an owner"
    )
  }

  func test_rows_markTheOperatorsOwnRowNotEditable_whileTheRestAreEditable() async throws {
    let tested: ConfirmPermissionsController = try self.tested()

    let rows: Array<RenderedRow> = await self.rows(of: tested)

    XCTAssertEqual(
      rows.first(where: { $0.recipient == "user-\(User.ID.mock_ada)" })?.editable,
      false
    )
    XCTAssertEqual(
      rows.first(where: { $0.recipient == "user-\(User.ID.mock_1)" })?.editable,
      true
    )
  }

  /// The level is picked on the details screen, so the row being non-editable is not enough - the screen it opens
  /// must not offer the picker either.
  func test_openUserDetails_offersNoEditing_forTheOperatorsOwnRow() async throws {
    let presentedEditable: CriticalState<Array<Bool>> = .init(.init())
    patch(
      \NavigationToConfirmUserPermissionDetails.mockPerform,
      with: { (_: Bool, context: ConfirmUserPermissionDetailsController.Context) in
        presentedEditable.access { (flags: inout Array<Bool>) in flags.append(context.editable) }
      }
    )
    let tested: ConfirmPermissionsController = try self.tested()

    await tested.openUserDetails(.mock_ada)
    await tested.openUserDetails(.mock_1)

    XCTAssertEqual(presentedEditable.get(), [false, true])
  }
}

// MARK: - Editing the recipients

// swift-format-ignore: AlwaysUseLowerCamelCase, NeverForceUnwrap
extension ConfirmPermissionsControllerTests {

  func test_setUserPermission_changesTheLevel_ofAnotherRecipient() async throws {
    let tested: ConfirmPermissionsController = try self.tested()

    tested.setUserPermission(.mock_1, to: .owner)

    let level: Permission? = await self.level(of: "user-\(User.ID.mock_1)", in: tested)
    XCTAssertEqual(level, .owner)
  }

  func test_removeUser_dropsTheRecipient() async throws {
    let tested: ConfirmPermissionsController = try self.tested()

    tested.removeUser(.mock_1)

    let rows: Array<RenderedRow> = await self.rows(of: tested)
    XCTAssertEqual(rows.map(\.recipient), ["user-\(User.ID.mock_ada)"])
  }

  func test_setUserGroupPermission_changesTheLevel_ofAGroup() async throws {
    let tested: ConfirmPermissionsController = try self.tested(snapshot: .mock_sharedWithGroup)

    tested.setUserGroupPermission(.mock_1, to: .owner)

    let level: Permission? = await self.level(of: "group-\(UserGroup.ID.mock_1)", in: tested)
    XCTAssertEqual(level, .owner)
  }

  func test_removeUserGroup_dropsTheGroup() async throws {
    let tested: ConfirmPermissionsController = try self.tested(snapshot: .mock_sharedWithGroup)

    tested.removeUserGroup(.mock_1)

    let rows: Array<RenderedRow> = await self.rows(of: tested)
    XCTAssertFalse(rows.contains(where: { $0.recipient == "group-\(UserGroup.ID.mock_1)" }))
  }

  /// What the details screen reports back has to reach the recipient set the encryption binds to, not just the row.
  func test_detailsScreenSelection_reachesTheConfirmedRecipients() async throws {
    patch(
      \NavigationToConfirmUserPermissionDetails.mockPerform,
      with: { (_: Bool, context: ConfirmUserPermissionDetailsController.Context) in
        await context.setPermission(.owner)
      }
    )
    let tested: ConfirmPermissionsController = try self.tested()

    await tested.openUserDetails(.mock_1)
    await tested.confirm()

    let confirmed: OrderedSet<ResourcePermission>? = self.confirmedPermissions.get().first
    XCTAssertEqual(
      confirmed?.first(where: { $0.userID == .mock_1 })?.permission,
      .owner
    )
  }
}

// MARK: - Read-only mode

// swift-format-ignore: AlwaysUseLowerCamelCase, NeverForceUnwrap
extension ConfirmPermissionsControllerTests {

  /// An operator who does not own the resource may review the recipients but not change them. The view hides the
  /// affordances; these are the guards behind them.
  func test_setUserPermission_isIgnored_whenTheListIsReadOnly() async throws {
    let tested: ConfirmPermissionsController = try self.tested(mode: .edit(editable: false))

    tested.setUserPermission(.mock_1, to: .owner)

    let level: Permission? = await self.level(of: "user-\(User.ID.mock_1)", in: tested)
    XCTAssertEqual(level, .read)
  }

  func test_removeUser_isIgnored_whenTheListIsReadOnly() async throws {
    let tested: ConfirmPermissionsController = try self.tested(mode: .edit(editable: false))

    tested.removeUser(.mock_1)

    let rows: Array<RenderedRow> = await self.rows(of: tested)
    XCTAssertTrue(rows.contains(where: { $0.recipient == "user-\(User.ID.mock_1)" }))
  }

  func test_addRecipients_opensNothing_whenTheListIsReadOnly() async throws {
    patch(
      \NavigationToConfirmAddRecipients.mockPerform,
      with: { (_: Bool, _: ConfirmAddRecipientsController.Context) in
        XCTFail("A read-only list may not gain recipients")
      }
    )
    let tested: ConfirmPermissionsController = try self.tested(mode: .edit(editable: false))

    await tested.addRecipients()
  }

  func test_rows_areAllNonEditable_whenTheListIsReadOnly() async throws {
    let tested: ConfirmPermissionsController = try self.tested(mode: .edit(editable: false))

    let rows: Array<RenderedRow> = await self.rows(of: tested)

    XCTAssertFalse(rows.isEmpty)
    XCTAssertTrue(rows.allSatisfy { $0.editable == false })
  }
}

// MARK: - Adding recipients

// swift-format-ignore: AlwaysUseLowerCamelCase, NeverForceUnwrap
extension ConfirmPermissionsControllerTests {

  func test_addRecipients_excludesRecipientsAlreadyHoldingAccess() async throws {
    let excludedUsers: CriticalState<Set<User.ID>> = .init(.init())
    let excludedGroups: CriticalState<Set<UserGroup.ID>> = .init(.init())
    patch(
      \NavigationToConfirmAddRecipients.mockPerform,
      with: { (_: Bool, context: ConfirmAddRecipientsController.Context) in
        excludedUsers.set(context.excludedUsers)
        excludedGroups.set(context.excludedGroups)
      }
    )
    let tested: ConfirmPermissionsController = try self.tested(snapshot: .mock_sharedWithGroup)

    await tested.addRecipients()

    XCTAssertEqual(excludedUsers.get(), [.mock_ada])
    XCTAssertEqual(excludedGroups.get(), [.mock_1], "A group already holding access may not be picked twice")
  }

  func test_addedRecipient_isGrantedReadAccess() async throws {
    patch(
      \PermissionSnapshotService.expanding,
      with: { @Sendable (_: PermissionSnapshot, _: Array<User.ID>, _: Array<UserGroup.ID>) -> PermissionSnapshot in
        .mock_sharedWithAddedRecipient
      }
    )
    patch(
      \NavigationToConfirmAddRecipients.mockPerform,
      with: { (_: Bool, context: ConfirmAddRecipientsController.Context) in
        await context.onSelect([.mock_2], .init())
      }
    )
    let tested: ConfirmPermissionsController = try self.tested()

    await tested.addRecipients()

    let level: Permission? = await self.level(of: "user-\(User.ID.mock_2)", in: tested)
    XCTAssertEqual(level, .read, "A recipient added by hand starts with the lowest access")
  }

  /// A recipient the expanded snapshot cannot describe has no usable key, so nothing could be encrypted for them.
  /// Granting them would add a permission that renders no row and that no secret reaches - an invisible grant,
  /// which is what this screen exists to prevent.
  func test_addedRecipient_isDroppedAndReported_whenTheSnapshotCannotDescribeThem() async throws {
    // The picked recipient came back without a usable key, so the expanded snapshot describes nobody new.
    patch(
      \PermissionSnapshotService.expanding,
      with: { @Sendable (_: PermissionSnapshot, _: Array<User.ID>, _: Array<UserGroup.ID>) -> PermissionSnapshot in
        .mock_shared
      }
    )
    patch(
      \NavigationToConfirmAddRecipients.mockPerform,
      with: { (_: Bool, context: ConfirmAddRecipientsController.Context) in
        await context.onSelect([.mock_2], .init())
      }
    )
    let messages: SnackBarMessageEvent.Subscription = SnackBarMessageEvent.subscribe()
    let tested: ConfirmPermissionsController = try self.tested()

    await tested.addRecipients()

    let rows: Array<RenderedRow> = await self.rows(of: tested)
    XCTAssertFalse(
      rows.contains(where: { $0.recipient == "user-\(User.ID.mock_2)" }),
      "A recipient no secret can be encrypted for must not be granted access"
    )
    let message: SnackBarMessageEvent.Payload? = try await messages.nextEvent()
    XCTAssertEqual(
      message,
      SnackBarMessageEvent.Payload.show(.error("resource.permission.confirm.recipient.unavailable.message")),
      "The operator has to be told that not everyone they picked was added"
    )
  }
}

// MARK: - Confirming

// swift-format-ignore: AlwaysUseLowerCamelCase, NeverForceUnwrap
extension ConfirmPermissionsControllerTests {

  func test_confirm_handsTheEditedRecipientsAndTheDisplayedSnapshotToTheFlow() async throws {
    let tested: ConfirmPermissionsController = try self.tested()
    tested.setUserPermission(.mock_1, to: .write)

    await tested.confirm()

    let confirmed: OrderedSet<ResourcePermission>? = self.confirmedPermissions.get().first
    XCTAssertEqual(confirmed?.count, 2)
    XCTAssertEqual(confirmed?.first(where: { $0.userID == .mock_1 })?.permission, .write)
    XCTAssertEqual(self.confirmedSnapshots.get().first, .mock_shared)
  }

  /// Drift means the recipients moved under the operator. The list has to show what the resource holds now, and the
  /// edits made against the stale list have to go with it - confirming again must not re-apply them blindly.
  func test_confirm_replacesTheListWithTheRefreshedRecipients_onDrift() async throws {
    self.confirmationOutcome.set(.retryWithRefreshed(.mock_private))
    let tested: ConfirmPermissionsController = try self.tested()
    tested.setUserPermission(.mock_1, to: .owner)

    await tested.confirm()

    let rows: Array<RenderedRow> = await self.rows(of: tested)
    XCTAssertEqual(
      rows.map(\.recipient),
      ["user-\(User.ID.mock_ada)"],
      "The refreshed snapshot replaces the reviewed list entirely"
    )

    self.confirmationOutcome.set(.applied)
    await tested.confirm()

    XCTAssertEqual(
      self.confirmedPermissions.get().last,
      PermissionSnapshot.mock_private.permissions,
      "Edits made against the stale list are dropped with it"
    )
    XCTAssertEqual(self.confirmedSnapshots.get().last, .mock_private)
  }

  func test_cancel_reportsToTheFlowAndLeavesTheScreen() async throws {
    let navigationReverted: CriticalState<Int> = .init(0)
    patch(
      \NavigationToConfirmPermissions.mockRevert,
      with: { (_: Bool) in
        navigationReverted.access { (count: inout Int) in count += 1 }
      }
    )
    let tested: ConfirmPermissionsController = try self.tested()

    await tested.cancel()

    XCTAssertEqual(self.cancellations.get(), 1)
    XCTAssertEqual(navigationReverted.get(), 1)
    XCTAssertTrue(self.confirmedPermissions.get().isEmpty, "Backing out confirms nothing")
  }
}

// MARK: - Duplicate access warning

// swift-format-ignore: AlwaysUseLowerCamelCase, NeverForceUnwrap
extension ConfirmPermissionsControllerTests {

  func test_duplicateWarning_isShown_whenARecipientAlsoHoldsAccessThroughAGroup() async throws {
    let tested: ConfirmPermissionsController = try self.tested(snapshot: .mock_sharedWithDuplicateAccess)

    let warning: DisplayableString? = await tested.viewState.current.duplicateWarning

    XCTAssertNotNil(warning)
  }

  func test_duplicateWarning_clears_whenTheRedundantGrantIsRemoved() async throws {
    let tested: ConfirmPermissionsController = try self.tested(snapshot: .mock_sharedWithDuplicateAccess)

    tested.removeUser(.mock_1)

    let warning: DisplayableString? = await tested.viewState.current.duplicateWarning
    XCTAssertNil(warning, "Dropping the direct grant leaves the group as the only way in")
  }

  func test_duplicateWarning_isAbsent_whenEveryRecipientHoldsAccessOnce() async throws {
    let tested: ConfirmPermissionsController = try self.tested()

    let warning: DisplayableString? = await tested.viewState.current.duplicateWarning

    XCTAssertNil(warning)
  }
}

// MARK: - Recipients the snapshot does not describe

// swift-format-ignore: AlwaysUseLowerCamelCase, NeverForceUnwrap
extension ConfirmPermissionsControllerTests {

  /// Characterises current behaviour: a permission whose recipient the snapshot does not describe renders no row,
  /// so it is confirmed without ever being shown. The secret does not reach them either - `recipients(of:)` fails
  /// closed the same way - so this is not a leak, but it is a recipient the operator cannot review on the screen
  /// that exists to show them. Worth surfacing rather than skipping; this test pins the behaviour so that changing
  /// it is a deliberate act.
  func test_rows_omitRecipientsTheSnapshotDoesNotDescribe() async throws {
    let tested: ConfirmPermissionsController = try self.tested(snapshot: .mock_withUndescribedRecipient)

    let rows: Array<RenderedRow> = await self.rows(of: tested)
    XCTAssertEqual(rows.map(\.recipient), ["user-\(User.ID.mock_ada)"])

    await tested.confirm()

    XCTAssertEqual(
      self.confirmedPermissions.get().first?.count,
      2,
      "The undescribed recipient is still confirmed, though no row ever showed them"
    )
  }
}

// MARK: - Fixtures

/// A rendered row reduced to what these tests assert on: who it grants access to, and whether the operator may
/// change it.
private struct RenderedRow: Equatable {

  fileprivate let recipient: String
  fileprivate let editable: Bool
}

// swift-format-ignore: AlwaysUseLowerCamelCase, NeverForceUnwrap
extension ConfirmPermissionRowItem {

  fileprivate var isEditable: Bool {
    switch self {
    case .user(_, let editable), .group(_, let editable):
      return editable
    }
  }

  fileprivate var level: Permission {
    switch self {
    case .user(let details, _):
      return details.permission

    case .group(let details, _):
      return details.permission
    }
  }
}

// swift-format-ignore: AlwaysUseLowerCamelCase, NeverForceUnwrap
extension PermissionSnapshot {

  /// Shared with a group as well as with the operator.
  fileprivate static var mock_sharedWithGroup: Self {
    .mock(
      permissions: [
        .user(id: .mock_ada, permission: .owner, permissionID: .mock_1),
        .userGroup(id: .mock_1, permission: .read, permissionID: .mock_2),
      ],
      groups: [
        .mock_1: .mock_owners(members: [.mock_1])
      ]
    )
  }

  /// A recipient granted access directly while already holding it through a confirmed group.
  fileprivate static var mock_sharedWithDuplicateAccess: Self {
    .mock(
      permissions: [
        .user(id: .mock_ada, permission: .owner, permissionID: .mock_1),
        .user(id: .mock_1, permission: .read, permissionID: .mock_2),
        .userGroup(id: .mock_1, permission: .read, permissionID: .mock_3),
      ],
      groups: [
        .mock_1: .mock_owners(members: [.mock_1])
      ]
    )
  }

  /// ``mock_shared`` after expanding it with a recipient picked by hand, as the snapshot service returns it.
  fileprivate static var mock_sharedWithAddedRecipient: Self {
    var snapshot: Self = .mock_shared
    snapshot.users[.mock_2] = .mock(id: .mock_2)
    return snapshot
  }

  /// Holds a permission for someone the capture could not describe - a recipient with no usable key.
  fileprivate static var mock_withUndescribedRecipient: Self {
    var snapshot: Self = .mock(
      permissions: [
        .user(id: .mock_ada, permission: .owner, permissionID: .mock_1),
        .user(id: .mock_1, permission: .read, permissionID: .mock_2),
      ]
    )
    snapshot.users.removeValue(forKey: .mock_1)
    return snapshot
  }
}
