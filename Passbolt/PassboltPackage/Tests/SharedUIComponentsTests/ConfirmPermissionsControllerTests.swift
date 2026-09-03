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

  /// Editing lets the operator change their own level - handing the resource over is a legitimate end state, and
  /// what stops a lockout is the validation, not an inert row.
  func test_setUserPermission_changesTheOperatorsOwnRow_whenEditing() async throws {
    let tested: ConfirmPermissionsController = try self.tested()

    tested.setUserPermission(.mock_ada, to: .read)

    let level: Permission? = await self.level(of: "user-\(User.ID.mock_ada)", in: tested)
    XCTAssertEqual(level, .read)
  }

  func test_removeUser_removesTheOperatorsOwnRow_whenEditing() async throws {
    let tested: ConfirmPermissionsController = try self.tested()

    tested.removeUser(.mock_ada)

    let rows: Array<RenderedRow> = await self.rows(of: tested)
    XCTAssertFalse(rows.contains(where: { $0.recipient == "user-\(User.ID.mock_ada)" }))
  }

  func test_rows_markTheOperatorsOwnRowEditable_whenEditing() async throws {
    let tested: ConfirmPermissionsController = try self.tested()

    let rows: Array<RenderedRow> = await self.rows(of: tested)

    XCTAssertEqual(
      rows.first(where: { $0.recipient == "user-\(User.ID.mock_ada)" })?.editable,
      true
    )
    XCTAssertEqual(
      rows.first(where: { $0.recipient == "user-\(User.ID.mock_1)" })?.editable,
      true
    )
  }

  /// The level is picked on the details screen, so the row being editable is not enough - the screen it opens has
  /// to offer the picker too.
  func test_openUserDetails_offersEditing_forTheOperatorsOwnRow_whenEditing() async throws {
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

    XCTAssertEqual(presentedEditable.get(), [true, true])
  }

  /// Creating lets the operator re-level their own row too: keeping only update access to something they made for
  /// a colleague is a real intent, and the ownership rule is what refuses the sets that go too far.
  func test_setUserPermission_changesTheOperatorsOwnRow_whenCreating() async throws {
    let tested: ConfirmPermissionsController = try self.tested(
      mode: .create(editable: true),
      snapshot: .mock_sharedWithSecondOwner
    )

    tested.setUserPermission(.mock_ada, to: .write)

    let level: Permission? = await self.level(of: "user-\(User.ID.mock_ada)", in: tested)
    XCTAssertEqual(level, .write)
    let currentWarning: DisplayableString? = await tested.viewState.current.ownershipWarning
    XCTAssertNil(
      currentWarning,
      "Another owner remains, so the downgrade stands"
    )
  }

  /// The same downgrade with nobody else owning the folder - C7. Now that the row can be re-levelled, this is the
  /// state the ownership rule exists for.
  func test_setUserPermission_isRefused_whenItLeavesTheCreatedResourceWithoutAnOwner() async throws {
    let tested: ConfirmPermissionsController = try self.tested(
      mode: .create(editable: true),
      snapshot: .mock_shared
    )

    tested.setUserPermission(.mock_ada, to: .write)

    let currentWarning: DisplayableString? = await tested.viewState.current.ownershipWarning
    XCTAssertEqual(
      currentWarning,
      .localized(key: "resource.permission.confirm.owner.any.required.message")
    )
    await tested.confirm()
    XCTAssertTrue(self.confirmedPermissions.get().isEmpty, "Nothing may be created that nobody owns")
  }

  /// The level and the removal are both acted on from the details screen, so it has to be told the row is open
  /// for editing - the operator's own included.
  func test_openUserDetails_offersEditing_forTheOperatorsOwnRow_whenCreating() async throws {
    let presentedEditable: CriticalState<Array<Bool>> = .init(.init())
    patch(
      \NavigationToConfirmUserPermissionDetails.mockPerform,
      with: { (_: Bool, context: ConfirmUserPermissionDetailsController.Context) in
        presentedEditable.access { (flags: inout Array<Bool>) in flags.append(context.editable) }
      }
    )
    let tested: ConfirmPermissionsController = try self.tested(mode: .create(editable: true))

    await tested.openUserDetails(.mock_ada)
    await tested.openUserDetails(.mock_1)

    XCTAssertEqual(presentedEditable.get(), [true, true])
  }

  /// Creating locks the operator's own *level* but not their way out of the resource: making one for somebody
  /// else and stepping out of it is a real intent. What stops a lockout is the ownership rule refusing the
  /// resulting set, which the two tests below cover from both sides.
  func test_removeUser_dropsTheOperatorsOwnRow_whenCreating() async throws {
    let tested: ConfirmPermissionsController = try self.tested(
      mode: .create(editable: true),
      snapshot: .mock_sharedWithSecondOwner
    )

    tested.removeUser(.mock_ada)

    let rows: Array<RenderedRow> = await self.rows(of: tested)
    XCTAssertFalse(
      rows.contains(where: { $0.recipient == "user-\(User.ID.mock_ada)" }),
      "The operator may hand the resource they are creating to somebody else"
    )
    let currentWarning: DisplayableString? = await tested.viewState.current.ownershipWarning
    XCTAssertNil(
      currentWarning,
      "Another owner remains, so there is nothing to refuse"
    )
    await tested.confirm()
    XCTAssertEqual(
      self.confirmedPermissions.get().last?.compactMap(\ResourcePermission.userID),
      [.mock_1],
      "The created resource is left to the other owner"
    )
  }

  /// The same removal, with nobody else owning the folder: now it is the ownership rule's business.
  func test_removeUser_isRefused_whenItLeavesTheCreatedResourceWithoutAnOwner() async throws {
    let tested: ConfirmPermissionsController = try self.tested(
      mode: .create(editable: true),
      snapshot: .mock_shared
    )

    tested.removeUser(.mock_ada)

    let currentWarning: DisplayableString? = await tested.viewState.current.ownershipWarning
    XCTAssertEqual(
      currentWarning,
      .localized(key: "resource.permission.confirm.owner.any.required.message")
    )
    await tested.confirm()
    XCTAssertTrue(self.confirmedPermissions.get().isEmpty, "Nothing may be created that nobody owns")
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

  /// A grant the operator added holds no permission on the server, so the refreshed capture cannot list it. It has
  /// to come back anyway: the drift is usually about that very recipient, and the operator is being asked to
  /// review a list it would otherwise have vanished from.
  func test_confirm_restoresTheAddedGrants_onDrift() async throws {
    var refreshed: PermissionSnapshot = .mock_shared
    refreshed.groups[.mock_1] = .mock_owners(members: [.mock_1, .mock_2])
    let addedGroup: ResourcePermission = .userGroup(id: .mock_1, permission: .read, permissionID: .none)
    self.confirmationOutcome.set(.retryWithRefreshed(refreshed, restoring: [addedGroup]))
    let tested: ConfirmPermissionsController = try self.tested(mode: .share)

    await tested.confirm()

    let rows: Array<RenderedRow> = await self.rows(of: tested)
    XCTAssertTrue(
      rows.contains(where: { $0.recipient == "group-\(UserGroup.ID.mock_1)" }),
      "The group the operator added must survive the reopen it is being asked to review"
    )
  }

  /// The restored grant is shown as the refreshed snapshot describes it, not as it was when it was added - that
  /// changed membership is the whole reason the operator is looking at the list again.
  func test_confirm_confirmsTheRestoredGrant_asTheRefreshedSnapshotDescribesIt() async throws {
    var refreshed: PermissionSnapshot = .mock_shared
    refreshed.groups[.mock_1] = .mock_owners(members: [.mock_1, .mock_2])
    let addedGroup: ResourcePermission = .userGroup(id: .mock_1, permission: .read, permissionID: .none)
    self.confirmationOutcome.set(.retryWithRefreshed(refreshed, restoring: [addedGroup]))
    let tested: ConfirmPermissionsController = try self.tested(mode: .share)
    await tested.confirm()

    self.confirmationOutcome.set(.applied)
    await tested.confirm()

    XCTAssertEqual(self.confirmedSnapshots.get().last?.group(.mock_1)?.members, [.mock_1, .mock_2])
    XCTAssertTrue(
      self.confirmedPermissions.get().last?.contains(addedGroup) ?? false,
      "Confirming again applies the restored grant"
    )
  }

  /// A recipient the refreshed capture cannot describe holds no usable key - restoring them would put back a row
  /// that renders nothing and a grant no secret can be encrypted for.
  func test_confirm_dropsARestoredGrant_theRefreshedSnapshotCannotDescribe() async throws {
    let unknownGroup: ResourcePermission = .userGroup(id: .mock_2, permission: .read, permissionID: .none)
    self.confirmationOutcome.set(.retryWithRefreshed(.mock_shared, restoring: [unknownGroup]))
    let tested: ConfirmPermissionsController = try self.tested(mode: .share)

    await tested.confirm()

    XCTAssertFalse(
      self.confirmedPermissions.get().isEmpty,
      "The confirmation was handled"
    )
    let rows: Array<RenderedRow> = await self.rows(of: tested)
    XCTAssertFalse(rows.contains(where: { $0.recipient == "group-\(UserGroup.ID.mock_2)" }))
  }

  /// The refresh may already grant the recipient the operator was adding - someone else got there first. Restoring
  /// on top would double the row and lose the level the server now holds.
  func test_confirm_doesNotRestoreAGrant_theRefreshedSnapshotAlreadyHolds() async throws {
    let alreadyGranted: ResourcePermission = .user(id: .mock_1, permission: .owner, permissionID: .none)
    self.confirmationOutcome.set(.retryWithRefreshed(.mock_shared, restoring: [alreadyGranted]))
    let tested: ConfirmPermissionsController = try self.tested(mode: .share)

    await tested.confirm()

    let rows: Array<RenderedRow> = await self.rows(of: tested)
    XCTAssertEqual(
      rows.filter { $0.recipient == "user-\(User.ID.mock_1)" }.count,
      1,
      "The recipient is listed once, as the server holds them"
    )
    let level: Permission? = await self.level(of: "user-\(User.ID.mock_1)", in: tested)
    XCTAssertEqual(level, .read, "The server's level wins over the abandoned addition")
  }

  /// Drift means the recipients moved under the operator. The list has to show what the resource holds now, and the
  /// edits made against the stale list have to go with it - confirming again must not re-apply them blindly.
  func test_confirm_replacesTheListWithTheRefreshedRecipients_onDrift() async throws {
    self.confirmationOutcome.set(.retryWithRefreshed(.mock_private, restoring: .init()))
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

// MARK: - Ownership validation

/// The rule is on the end state, so it has to catch every route to a lockout - the group that owns on the
/// operator's behalf included - while letting the hand-over that keeps them an owner through.
// swift-format-ignore: AlwaysUseLowerCamelCase, NeverForceUnwrap
extension ConfirmPermissionsControllerTests {

  func test_ownershipWarning_isShown_whenTheOperatorRemovesTheirOwnOwnership() async throws {
    let tested: ConfirmPermissionsController = try self.tested()

    tested.removeUser(.mock_ada)

    let warning: DisplayableString? = await tested.viewState.current.ownershipWarning
    XCTAssertEqual(warning, .localized(key: "resource.permission.confirm.owner.required.message"))
  }

  func test_ownershipWarning_isShown_whenTheOperatorDowngradesThemselves() async throws {
    let tested: ConfirmPermissionsController = try self.tested()

    tested.setUserPermission(.mock_ada, to: .read)

    let currentWarning: DisplayableString? = await tested.viewState.current.ownershipWarning
    XCTAssertNotNil(currentWarning)
  }

  func test_confirm_appliesNothing_whileTheOperatorWouldLoseOwnership() async throws {
    let tested: ConfirmPermissionsController = try self.tested()
    tested.removeUser(.mock_ada)

    await tested.confirm()

    XCTAssertTrue(self.confirmedPermissions.get().isEmpty, "Nothing may be applied that locks the operator out")
  }

  /// Handing the resource to a group the operator belongs to: their direct row goes, their ownership does not.
  func test_ownershipWarning_isAbsent_whenAnOwnerGroupTheyBelongToRemains() async throws {
    let tested: ConfirmPermissionsController = try self.tested(
      snapshot: .mock_sharedWithOperatorsOwnerGroup
    )

    tested.removeUser(.mock_ada)

    let currentWarning: DisplayableString? = await tested.viewState.current.ownershipWarning
    XCTAssertNil(currentWarning)
    await tested.confirm()
    XCTAssertEqual(self.confirmedPermissions.get().count, 1, "The hand-over is allowed to proceed")
  }

  /// The group is the operator's only source of ownership, so dropping it locks them out just as surely as
  /// dropping their own row - the guard on the own row alone never saw this.
  func test_ownershipWarning_isShown_whenTheOperatorRemovesTheGroupThatOwnsForThem() async throws {
    let tested: ConfirmPermissionsController = try self.tested(
      snapshot: .mock_sharedWithOperatorsGroupOnly
    )

    tested.removeUserGroup(.mock_1)

    let currentWarning: DisplayableString? = await tested.viewState.current.ownershipWarning
    XCTAssertNotNil(currentWarning)
  }

  func test_ownershipWarning_isShown_whenTheOperatorDowngradesTheGroupThatOwnsForThem() async throws {
    let tested: ConfirmPermissionsController = try self.tested(
      snapshot: .mock_sharedWithOperatorsGroupOnly
    )

    tested.setUserGroupPermission(.mock_1, to: .write)

    let currentWarning: DisplayableString? = await tested.viewState.current.ownershipWarning
    XCTAssertNotNil(currentWarning)
  }

  func test_ownershipWarning_clears_whenOwnershipIsRestored() async throws {
    let tested: ConfirmPermissionsController = try self.tested()
    tested.setUserPermission(.mock_ada, to: .read)

    tested.setUserPermission(.mock_ada, to: .owner)

    let currentWarning: DisplayableString? = await tested.viewState.current.ownershipWarning
    XCTAssertNil(currentWarning)
  }

  /// Sharing is how a resource is handed over, so an operator who removes their own access there means it -
  /// as long as they leave somebody owning what they handed over.
  func test_ownershipWarning_isAbsent_whenSharingLeavesAnotherOwner() async throws {
    let tested: ConfirmPermissionsController = try self.tested(
      mode: .share,
      snapshot: .mock_sharedWithSecondOwner
    )

    tested.removeUser(.mock_ada)

    let currentWarning: DisplayableString? = await tested.viewState.current.ownershipWarning
    XCTAssertNil(currentWarning)
    await tested.confirm()
    XCTAssertEqual(self.confirmedPermissions.get().count, 1)
  }

  /// A read-only list offers nothing to fix, so a rule that blocks it only strands the operator. This is the
  /// state anyone holding update-but-not-owner rights opens an edit confirmation in: the operator is not an
  /// owner and cannot become one, and blocking there left them unable to save the edit at all.
  func test_ownershipWarning_isAbsent_whenTheListIsReadOnly() async throws {
    let tested: ConfirmPermissionsController = try self.tested(
      mode: .edit(editable: false),
      snapshot: .mock_ownedBySomeoneElse
    )

    let currentWarning: DisplayableString? = await tested.viewState.current.ownershipWarning
    XCTAssertNil(
      currentWarning,
      "The operator holds update rights only - there is no row they could change to satisfy a rule"
    )

    await tested.confirm()

    XCTAssertEqual(self.confirmedPermissions.get().count, 1, "The edit they are entitled to make goes through")
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

  /// Characterises current behaviour: an undescribed recipient renders no row, so it is confirmed unseen. Not a
  /// leak - `recipients(of:)` fails closed too - but a recipient this screen cannot show. Pinned deliberately.
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

  /// Shared with a group the operator belongs to, and with nobody directly - so the operator holds no permission
  /// row of their own, only access through that group.
  fileprivate static var mock_sharedWithOperatorsGroupOnly: Self {
    .mock(
      permissions: [
        .userGroup(id: .mock_1, permission: .owner, permissionID: .mock_1)
      ],
      groups: [
        .mock_1: .mock_owners(members: [.mock_ada, .mock_1])
      ]
    )
  }

  /// The operator owns directly *and* through a group they belong to - removing their own row leaves the group's
  /// ownership behind, which is the hand-over the extension permits.
  fileprivate static var mock_sharedWithOperatorsOwnerGroup: Self {
    .mock(
      permissions: [
        .user(id: .mock_ada, permission: .owner, permissionID: .mock_1),
        .userGroup(id: .mock_1, permission: .owner, permissionID: .mock_2),
      ],
      groups: [
        .mock_1: .mock_owners(members: [.mock_ada, .mock_1])
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

// MARK: - Share mode

/// Sharing opens on the resource's current recipients and permits handing ownership away outright; the own-row
/// behaviour it shares with editing is covered there.
// swift-format-ignore: AlwaysUseLowerCamelCase, NeverForceUnwrap
extension ConfirmPermissionsControllerTests {

  func test_rows_showTheResourcesCurrentRecipients_whenSharing() async throws {
    let tested: ConfirmPermissionsController = try self.tested(mode: .share)

    let rows: Array<RenderedRow> = await self.rows(of: tested)

    XCTAssertEqual(
      rows.map(\RenderedRow.recipient),
      ["user-\(User.ID.mock_ada)", "user-\(User.ID.mock_1)"]
    )
  }

  func test_confirm_handsBackTheSnapshotsRecipients_whenNothingWasEdited() async throws {
    let tested: ConfirmPermissionsController = try self.tested(mode: .share)

    await tested.confirm()

    XCTAssertEqual(self.confirmedPermissions.get().last, PermissionSnapshot.mock_shared.permissions)
  }
}

// MARK: - Create mode

/// Creating in a shared folder starts from that folder's permissions - the operator included, who ends up holding
/// exactly what it grants them. The resource is still *created* with them as sole owner, but that is a bootstrap
/// the apply step settles, not what they keep.
// swift-format-ignore: AlwaysUseLowerCamelCase, NeverForceUnwrap
extension ConfirmPermissionsControllerTests {

  /// The folder grants the operator update access, so that is what the new resource grants them - creating it
  /// does not promote them above the folder they created it in.
  func test_rows_keepTheOperatorsInheritedLevel_whenCreating() async throws {
    let tested: ConfirmPermissionsController = try self.tested(
      mode: .create(editable: true),
      snapshot: .mock_ownedBySomeoneElse
    )

    let level: Permission? = await self.level(of: "user-\(User.ID.mock_ada)", in: tested)

    XCTAssertEqual(level, .write)
  }

  /// A folder may grant the operator access only through a group, leaving them no permission row of their own.
  /// Inheritance leaves it that way: synthesising a direct grant would give them access twice over - which the
  /// duplicate rule then warns about - and hand them a permission the folder never held.
  func test_rows_addNoOperatorRow_whenTheFolderGrantsAccessThroughAGroupOnly() async throws {
    let tested: ConfirmPermissionsController = try self.tested(
      mode: .create(editable: true),
      snapshot: .mock_sharedWithOperatorsGroupOnly
    )

    let rows: Array<RenderedRow> = await self.rows(of: tested)

    XCTAssertEqual(
      rows.map(\RenderedRow.recipient),
      ["group-\(UserGroup.ID.mock_1)"],
      "The group is the operator's access, and the only row the folder justifies"
    )
    let currentDuplicateWarning: DisplayableString? = await tested.viewState.current.duplicateWarning
    XCTAssertNil(
      currentDuplicateWarning,
      "Nothing holds access twice, so the screen has nothing to warn about"
    )
  }

  func test_confirm_handsBackTheOperatorsInheritedLevel_whenCreating() async throws {
    let tested: ConfirmPermissionsController = try self.tested(
      mode: .create(editable: true),
      snapshot: .mock_ownedBySomeoneElse
    )

    await tested.confirm()

    XCTAssertEqual(
      self.confirmedPermissions.get().last?.first(where: { $0.userID == .mock_ada })?.permission,
      .write
    )
  }

  /// Reopening after drift reseeds from the refreshed folder, which has to inherit from it just as the first
  /// render did rather than carry anything over.
  func test_reset_reseedsFromTheRefreshedFolder_whenCreating() async throws {
    let tested: ConfirmPermissionsController = try self.tested(
      mode: .create(editable: true),
      snapshot: .mock_private
    )

    tested.reset(snapshot: .mock_ownedBySomeoneElse)

    let level: Permission? = await self.level(of: "user-\(User.ID.mock_ada)", in: tested)
    XCTAssertEqual(level, .write)
  }

  /// Inheritance decides what the operator's row starts as; nothing then freezes it. Every row on an editable
  /// list is editable, their own included.
  func test_rows_markEveryRowEditable_whenCreating() async throws {
    let tested: ConfirmPermissionsController = try self.tested(
      mode: .create(editable: true),
      snapshot: .mock_ownedBySomeoneElse
    )

    let rows: Array<RenderedRow> = await self.rows(of: tested)

    XCTAssertEqual(rows.map(\RenderedRow.editable), [true, true])
  }

  /// An existing resource's permissions are shown as the server holds them, which is the same rule - there is
  /// simply no bootstrap permission involved.
  func test_rows_keepTheOperatorsOwnLevel_whenEditing() async throws {
    let tested: ConfirmPermissionsController = try self.tested(
      mode: .edit(editable: false),
      snapshot: .mock_ownedBySomeoneElse
    )

    let level: Permission? = await self.level(of: "user-\(User.ID.mock_ada)", in: tested)

    XCTAssertEqual(level, .write)
  }
}

// MARK: - Screen title

/// Sharing opens this screen directly, so it keeps the title its dedicated screen had. The other two flows reach
/// it as a checkpoint on a form the operator already submitted, and say so.
// swift-format-ignore: AlwaysUseLowerCamelCase, NeverForceUnwrap
extension ConfirmPermissionsControllerTests {

  func test_title_isTheShareScreens_whenSharing() async throws {
    XCTAssertEqual(
      ConfirmPermissionsMode.share.title,
      .localized(key: "resource.permission.edit.list.title")
    )
  }

  func test_title_isTheConfirmations_whenCreatingOrEditing() async throws {
    let confirmation: DisplayableString = .localized(key: "resource.permission.confirm.title")

    XCTAssertEqual(ConfirmPermissionsMode.create(editable: true).title, confirmation)
    XCTAssertEqual(ConfirmPermissionsMode.edit(editable: true).title, confirmation)
  }
}

// MARK: - Scenario fixtures

// swift-format-ignore: AlwaysUseLowerCamelCase, NeverForceUnwrap
extension PermissionSnapshot {

  /// A folder holding three recipients at three different levels - what a create confirmation is seeded from.
  fileprivate static var mock_folderWithThreeRecipients: Self {
    .mock(
      permissions: [
        .user(id: .mock_ada, permission: .owner, permissionID: .mock_1),
        .user(id: .mock_1, permission: .write, permissionID: .mock_2),
        .user(id: .mock_2, permission: .read, permissionID: .mock_3),
      ]
    )
  }

  /// Shared with a second direct owner - what the revoke-and-restore scenarios start from.
  fileprivate static var mock_sharedWithSecondOwner: Self {
    .mock(
      permissions: [
        .user(id: .mock_ada, permission: .owner, permissionID: .mock_1),
        .user(id: .mock_1, permission: .owner, permissionID: .mock_2),
      ]
    )
  }

  /// ``mock_shared`` expanded with a group the operator belongs to, as picking that group in the recipient
  /// search returns it.
  fileprivate static var mock_sharedWithAddedOperatorsGroup: Self {
    var snapshot: Self = .mock_shared
    snapshot.groups[.mock_2] = .init(id: .mock_2, name: "Owners", members: [.mock_ada, .mock_1])
    return snapshot
  }
}

// MARK: - Scenarios: creating in a shared folder

/// Creating in a shared folder asks the operator to vouch for the recipients the folder passes on, so the list
/// starts as a faithful copy of that folder's permissions.
// swift-format-ignore: AlwaysUseLowerCamelCase, NeverForceUnwrap
extension ConfirmPermissionsControllerTests {

  /// Inheritance is the question being asked, so every recipient carries over at exactly the level the folder
  /// grants them - not flattened to a default, and not raised along with the operator's own row.
  func test_create_seedsEveryFolderRecipient_atTheLevelTheFolderGrants() async throws {
    let tested: ConfirmPermissionsController = try self.tested(
      mode: .create(editable: true),
      snapshot: .mock_folderWithThreeRecipients
    )

    let operatorLevel: Permission? = await self.level(of: "user-\(User.ID.mock_ada)", in: tested)
    let updaterLevel: Permission? = await self.level(of: "user-\(User.ID.mock_1)", in: tested)
    let readerLevel: Permission? = await self.level(of: "user-\(User.ID.mock_2)", in: tested)

    XCTAssertEqual(operatorLevel, .owner, "The creator owns what they create")
    XCTAssertEqual(updaterLevel, .write)
    XCTAssertEqual(readerLevel, .read)
  }

  /// The operator owns the folder, so they may drop an inherited recipient before the resource exists at all.
  func test_create_dropsAnInheritedRecipient_whenTheOperatorRemovesTheirRow() async throws {
    let tested: ConfirmPermissionsController = try self.tested(
      mode: .create(editable: true),
      snapshot: .mock_folderWithThreeRecipients
    )

    tested.removeUser(.mock_1)
    await tested.confirm()

    XCTAssertEqual(
      self.confirmedPermissions.get().last?.compactMap(\ResourcePermission.userID),
      [.mock_ada, .mock_2],
      "The dropped recipient never receives the secret; the rest inherit unchanged"
    )
  }
}

// MARK: - Scenarios: editing a shared resource

/// Editing applies the list as an end state rather than as a log of what the operator did to it, which is what
/// makes a change and its undo cancel out within one review.
// swift-format-ignore: AlwaysUseLowerCamelCase, NeverForceUnwrap
extension ConfirmPermissionsControllerTests {

  /// The ordinary case: the operator is asked to vouch for the recipients, not to change them, so exactly what
  /// the server holds is what gets applied.
  func test_edit_handsBackTheUnchangedRecipients_whenNothingWasEdited() async throws {
    let tested: ConfirmPermissionsController = try self.tested()

    await tested.confirm()

    XCTAssertEqual(self.confirmedPermissions.get().last, PermissionSnapshot.mock_shared.permissions)
  }

  /// A recipient added by hand joins at `read`; raising them before confirming is what grants ownership, and the
  /// raise has to survive to the flow rather than the default the row was created with.
  func test_edit_grantsAnAddedRecipient_theLevelTheOperatorRaisesThemTo() async throws {
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

    tested.setUserPermission(.mock_2, to: .owner)
    await tested.confirm()

    XCTAssertTrue(
      self.confirmedPermissions.get().last?
        .contains(.user(id: .mock_2, permission: .owner, permissionID: .none)) ?? false,
      "The added recipient is granted at the level the operator confirmed, as a new permission"
    )
  }

  /// Adding a recipient and dropping them again within the same review is a no-op - the round trip leaves the
  /// server exactly as it was, with no grant sent and nothing revoked.
  func test_edit_leavesTheRecipientsUntouched_whenAnAddedRecipientIsRemovedAgain() async throws {
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

    tested.removeUser(.mock_2)
    await tested.confirm()

    XCTAssertEqual(
      self.confirmedPermissions.get().last,
      PermissionSnapshot.mock_shared.permissions,
      "The recipients are applied as an end state, so an addition and its removal cancel out"
    )
  }

  /// There is no "restore": a revoked recipient returns only through the picker, at `read` and with no
  /// permission identifier, so the grant is applied beside the one that still exists.
  func test_edit_reAddingARevokedRecipient_doesNotRestoreTheLevelTheServerHeld() async throws {
    patch(
      \PermissionSnapshotService.expanding,
      with: { @Sendable (_: PermissionSnapshot, _: Array<User.ID>, _: Array<UserGroup.ID>) -> PermissionSnapshot in
        .mock_sharedWithSecondOwner
      }
    )
    patch(
      \NavigationToConfirmAddRecipients.mockPerform,
      with: { (_: Bool, context: ConfirmAddRecipientsController.Context) in
        await context.onSelect([.mock_1], .init())
      }
    )
    let tested: ConfirmPermissionsController = try self.tested(snapshot: .mock_sharedWithSecondOwner)
    tested.removeUser(.mock_1)

    await tested.addRecipients()

    let level: Permission? = await self.level(of: "user-\(User.ID.mock_1)", in: tested)
    XCTAssertEqual(level, .read, "The recipient comes back at the picker's default, not at the owner level held")

    await tested.confirm()

    XCTAssertNil(
      self.confirmedPermissions.get().last?.first(where: { $0.userID == .mock_1 })?.permissionID,
      "Carrying no identifier, the restored row is applied as a new grant rather than the one it replaced"
    )
  }

  /// Taking over from the group that owned on the operator's behalf. The rule is about the end state, so
  /// restoring ownership by a different route clears the block and lets the change through.
  func test_edit_clearsTheOwnershipWarning_whenTheOperatorTakesOverFromTheGroupThatOwnedForThem() async throws {
    let tested: ConfirmPermissionsController = try self.tested(snapshot: .mock_ownedByOperatorsGroup)

    tested.removeUserGroup(.mock_1)
    var currentWarning: DisplayableString? = await tested.viewState.current.ownershipWarning
    XCTAssertNotNil(
      currentWarning,
      "Dropping the group leaves the operator with update access only"
    )

    tested.setUserPermission(.mock_ada, to: .owner)

    currentWarning = await tested.viewState.current.ownershipWarning
    XCTAssertNil(currentWarning)
    await tested.confirm()
    XCTAssertEqual(self.confirmedPermissions.get().count, 1, "The swap is allowed to proceed")
  }

  /// The reverse swap: the operator drops their own row and takes ownership through a group they belong to and
  /// add during the same review. The group has to actually *own* for the block to lift - joining at `read` is
  /// still a lockout.
  func test_edit_clearsTheOwnershipWarning_whenTheOperatorHandsOwnershipToAGroupTheyBelongTo() async throws {
    patch(
      \PermissionSnapshotService.expanding,
      with: { @Sendable (_: PermissionSnapshot, _: Array<User.ID>, _: Array<UserGroup.ID>) -> PermissionSnapshot in
        .mock_sharedWithAddedOperatorsGroup
      }
    )
    patch(
      \NavigationToConfirmAddRecipients.mockPerform,
      with: { (_: Bool, context: ConfirmAddRecipientsController.Context) in
        await context.onSelect(.init(), [.mock_2])
      }
    )
    let tested: ConfirmPermissionsController = try self.tested()
    tested.removeUser(.mock_ada)
    var currentWarning: DisplayableString? = await tested.viewState.current.ownershipWarning
    XCTAssertNotNil(currentWarning)

    await tested.addRecipients()
    currentWarning = await tested.viewState.current.ownershipWarning
    XCTAssertNotNil(
      currentWarning,
      "The group joins at read, which owns nothing on the operator's behalf"
    )

    tested.setUserGroupPermission(.mock_2, to: .owner)

    currentWarning = await tested.viewState.current.ownershipWarning
    XCTAssertNil(currentWarning)
  }
}

// MARK: - Scenarios: sharing a resource

// swift-format-ignore: AlwaysUseLowerCamelCase, NeverForceUnwrap
extension ConfirmPermissionsControllerTests {

  /// Sharing may hand the resource away entirely, but not strand it - the screen states the rule before the
  /// operator spends a confirmation on what `applyToSharedResource` would refuse anyway.
  func test_share_refusesASetLeavingTheResourceWithoutAnyOwner() async throws {
    let tested: ConfirmPermissionsController = try self.tested(
      mode: .share,
      snapshot: .mock_ownedByOperatorsGroup
    )

    tested.setUserGroupPermission(.mock_1, to: .write)
    tested.setUserPermission(.mock_ada, to: .write)

    let currentWarning: DisplayableString? = await tested.viewState.current.ownershipWarning
    XCTAssertEqual(
      currentWarning,
      .localized(key: "resource.permission.confirm.owner.any.required.message")
    )
    await tested.confirm()
    XCTAssertTrue(self.confirmedPermissions.get().isEmpty, "A resource nobody owns may not be applied")
  }

  /// The rule is about ownership, not about who holds it: a hand-over to a group of owners leaves the operator
  /// with nothing and is still a set the server accepts.
  func test_share_allowsHandingOwnershipToAGroupTheOperatorLeaves() async throws {
    let tested: ConfirmPermissionsController = try self.tested(
      mode: .share,
      snapshot: .mock_ownedByForeignGroup
    )

    tested.removeUser(.mock_ada)

    let currentWarning: DisplayableString? = await tested.viewState.current.ownershipWarning
    XCTAssertNil(currentWarning)
    await tested.confirm()
    XCTAssertEqual(self.confirmedPermissions.get().count, 1, "The hand-over is allowed to proceed")
  }
}
