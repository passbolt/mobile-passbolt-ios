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

// swift-format-ignore: AlwaysUseLowerCamelCase, NeverForceUnwrap
final class ResourceSharePermissionConfirmationTests: FeaturesTestCase {

  /// Contexts the confirmation screen was presented with, in order.
  private let presentedContexts: CriticalState<Array<ConfirmPermissionsContext>> = .init(.init())
  /// Navigation performed by the flow, in order.
  private let navigationEvents: CriticalState<Array<String>> = .init(.init())
  /// Recipient sets that reached the server, in order - one entry per applied share.
  private let appliedShares: CriticalState<Array<OrderedSet<ResourcePermission>>> = .init(.init())
  /// Whether the confirmation is currently in the navigation stack, which is what decides both whether it can be
  /// pushed and whether it still needs reverting.
  private let confirmationOnStack: CriticalState<Bool> = .init(false)

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
      \PermissionSnapshotService.forResource,
      with: always(.mock_shared)
    )
    patch(
      \ResourceShareConfirmation.applyToSharedResource,
      with: { (_: Resource.ID, confirmed: OrderedSet<ResourcePermission>, _: PermissionSnapshot) in
        self.appliedShares.access { (shares: inout Array<OrderedSet<ResourcePermission>>) in
          shares.append(confirmed)
        }
      }
    )
    patch(
      \NavigationToConfirmPermissions.mockPerform,
      with: { (_: Bool, context: ConfirmPermissionsContext) in
        self.presentedContexts.access { (contexts: inout Array<ConfirmPermissionsContext>) in
          contexts.append(context)
        }
        self.navigationEvents.access { (events: inout Array<String>) in
          events.append("present-confirmation")
        }
        self.confirmationOnStack.set(true)
      }
    )
    patch(
      \NavigationToConfirmPermissions.mockRevert,
      with: { (_: Bool) in
        self.navigationEvents.access { (events: inout Array<String>) in
          events.append("revert-confirmation")
        }
        self.confirmationOnStack.set(false)
      }
    )
    // The destination is unique: it can be pushed only while it is not already displayed.
    patch(
      \NavigationToConfirmPermissions.canPerformCheck,
      with: { (_: StaticString, _: UInt) -> Bool in self.confirmationOnStack.get() == false }
    )
  }
}

// MARK: - Presenting

// swift-format-ignore: AlwaysUseLowerCamelCase, NeverForceUnwrap
extension ResourceSharePermissionConfirmationTests {

  /// Share mode is always editable - the screen is only reachable for a resource the operator may share - and it
  /// is the only mode where the operator's own row may be changed.
  func test_present_opensTheScreenInShareMode() async throws {
    let confirmation: ResourceSharePermissionConfirmation = try self.tested()

    try await confirmation.present()

    let context: ConfirmPermissionsContext = try self.lastPresentedContext()
    XCTAssertEqual(context.mode, .share)
    XCTAssertTrue(context.mode.isEditable)
    XCTAssertEqual(self.navigationEvents.get(), ["present-confirmation"])
  }

  /// There is no separate share screen composing a set beforehand: the confirmation opens on the resource's
  /// recipients as the server holds them, which is also the baseline drift is measured against.
  func test_present_opensOnTheResourcesCurrentRecipients() async throws {
    let confirmation: ResourceSharePermissionConfirmation = try self.tested()

    try await confirmation.present()

    let context: ConfirmPermissionsContext = try self.lastPresentedContext()
    XCTAssertEqual(context.snapshot.permissions, PermissionSnapshot.mock_shared.permissions)
    XCTAssertEqual(context.operatorID, .mock_ada)
  }

  /// The destination is unique, so pushing it twice throws. The screen already up is the one to confirm from.
  func test_present_pushesNothing_whenTheScreenIsAlreadyDisplayed() async throws {
    let confirmation: ResourceSharePermissionConfirmation = try self.tested()
    try await confirmation.present()

    try await confirmation.present()

    XCTAssertEqual(self.navigationEvents.get(), ["present-confirmation"])
  }
}

// MARK: - Confirming

// swift-format-ignore: AlwaysUseLowerCamelCase, NeverForceUnwrap
extension ResourceSharePermissionConfirmationTests {

  func test_confirm_appliesTheReviewedSet_andLeavesTheScreen() async throws {
    let confirmation: ResourceSharePermissionConfirmation = try self.tested()
    try await confirmation.present()

    let outcome: ConfirmPermissionsOutcome = await self.confirm(.mock_shared)

    guard case .applied = outcome
    else { return XCTFail("A share that reached the server is applied") }
    XCTAssertEqual(self.appliedShares.get().count, 1, "the share is applied exactly once")
    XCTAssertEqual(
      self.navigationEvents.get(),
      ["present-confirmation", "revert-confirmation"],
      "the operator is left on the screen they shared from"
    )
  }

  /// Drift means the recipients moved since the operator reviewed them. Nothing is applied and the list reopens
  /// with what the server now holds, so the next confirmation is made against the real thing.
  func test_confirm_onDrift_appliesNothing_andReopensWithRefreshedPermissions() async throws {
    patch(
      \ResourceShareConfirmation.applyToSharedResource,
      with: { (_: Resource.ID, _: OrderedSet<ResourcePermission>, _: PermissionSnapshot) in
        throw PermissionDriftDetected.error()
      }
    )
    let refreshed: PermissionSnapshot = .mock_ownedBySomeoneElse
    patch(
      \PermissionSnapshotService.forResource,
      with: always(refreshed)
    )

    let confirmation: ResourceSharePermissionConfirmation = try self.tested()
    try await confirmation.present()

    let outcome: ConfirmPermissionsOutcome = await self.confirm(.mock_shared)

    guard case .retryWithRefreshed(let snapshot, _) = outcome
    else { return XCTFail("Drift reopens the screen with fresh data") }
    XCTAssertEqual(snapshot.permissions, refreshed.permissions)
    XCTAssertTrue(self.appliedShares.get().isEmpty, "nothing may reach the server")
    XCTAssertFalse(self.navigationEvents.get().contains("revert-confirmation"))
  }

  /// A group the operator added holds no permission on the resource, so the refreshed capture does not list it.
  /// It has to come back with the reopen and be re-captured, or the operator is asked to review a changed group
  /// that is no longer on the list - which is exactly the drift they were just told about.
  func test_confirm_onDrift_restoresTheAddedGrant_reCapturedFromTheServer() async throws {
    patch(
      \ResourceShareConfirmation.applyToSharedResource,
      with: { (_: Resource.ID, _: OrderedSet<ResourcePermission>, _: PermissionSnapshot) in
        throw PermissionDriftDetected.error()
      }
    )
    patch(
      \PermissionSnapshotService.forResource,
      with: always(.mock_shared)
    )
    let widened: XCTestExpectation = .init(description: "the added group is re-captured for the reopen")
    patch(
      \PermissionSnapshotService.expanding,
      with: { (current: PermissionSnapshot, _: Array<User.ID>, addedGroups: Array<UserGroup.ID>) in
        XCTAssertEqual(addedGroups, [.mock_1], "the grant the server does not hold must be re-captured")
        widened.fulfill()
        var described: PermissionSnapshot = current
        described.groups[.mock_1] = .mock_owners(members: [.mock_1, .mock_2])
        return described
      }
    )
    let addedGroup: ResourcePermission = .userGroup(id: .mock_1, permission: .read, permissionID: .none)

    let confirmation: ResourceSharePermissionConfirmation = try self.tested()
    try await confirmation.present()
    let context: ConfirmPermissionsContext = try self.lastPresentedContext()

    let outcome: ConfirmPermissionsOutcome = await context.onConfirm(
      context.snapshot.permissions.union([addedGroup]),
      context.snapshot
    )

    await fulfillment(of: [widened], timeout: 1.0)
    guard case .retryWithRefreshed(let snapshot, let restored) = outcome
    else { return XCTFail("Drift reopens the screen with fresh data") }
    XCTAssertEqual(restored, [addedGroup], "the operator's pending grant survives the reopen")
    XCTAssertEqual(
      snapshot.group(.mock_1)?.members,
      [.mock_1, .mock_2],
      "and is described as it now stands, which is what there is to review"
    )
  }

  /// Stale by our own doing - reopening with the real state stops the next attempt blaming someone else.
  func test_confirm_onPartialApplication_reopensWithRefreshedPermissions() async throws {
    patch(
      \ResourceShareConfirmation.applyToSharedResource,
      with: { (_: Resource.ID, _: OrderedSet<ResourcePermission>, _: PermissionSnapshot) in
        throw PermissionsPartiallyApplied.error(underlyingError: MockIssue.error())
      }
    )

    let confirmation: ResourceSharePermissionConfirmation = try self.tested()
    try await confirmation.present()

    let outcome: ConfirmPermissionsOutcome = await self.confirm(.mock_shared)

    guard case .retryWithRefreshed = outcome
    else { return XCTFail("A partial application reopens with the real state") }
    XCTAssertFalse(self.navigationEvents.get().contains("revert-confirmation"))
  }

  /// Any other failure leaves the screen exactly as it is, for another attempt - it must never read as applied.
  func test_confirm_onFailure_leavesTheScreenForAnotherAttempt() async throws {
    patch(
      \ResourceShareConfirmation.applyToSharedResource,
      with: { (_: Resource.ID, _: OrderedSet<ResourcePermission>, _: PermissionSnapshot) in
        throw MockIssue.error()
      }
    )

    let confirmation: ResourceSharePermissionConfirmation = try self.tested()
    try await confirmation.present()

    let outcome: ConfirmPermissionsOutcome = await self.confirm(.mock_shared)

    guard case .failed = outcome
    else { return XCTFail("A failed share is not applied") }
    XCTAssertFalse(self.navigationEvents.get().contains("revert-confirmation"))
  }

  /// An untrusted metadata key is offered for trusting rather than reported as a plain failure.
  func test_confirm_onInvalidMetadataKey_offersTrustingIt_withoutApplying() async throws {
    patch(
      \ResourceShareConfirmation.applyToSharedResource,
      with: { (_: Resource.ID, _: OrderedSet<ResourcePermission>, _: PermissionSnapshot) in
        throw MetadataPinnedKeyValidationError.error(reason: .deleted, context: .context(.message("Mock")))
      }
    )
    let offered: XCTestExpectation = .init(description: "trusting the rotated key is offered")
    patch(
      \NavigationToMetadataPinnedKeyValidationDialog.mockPerform,
      with: { (_: Bool, _: MetadataPinnedKeyValidationDialogViewController.Context) in
        offered.fulfill()
      }
    )

    let confirmation: ResourceSharePermissionConfirmation = try self.tested()
    try await confirmation.present()

    let outcome: ConfirmPermissionsOutcome = await self.confirm(.mock_shared)

    await fulfillment(of: [offered], timeout: 1.0)
    guard case .failed = outcome
    else { return XCTFail("Nothing was shared, so nothing may read as applied") }
    XCTAssertTrue(self.appliedShares.get().isEmpty)
  }

  /// Backing out leaves the operator where they opened the confirmation from, with nothing changed.
  func test_cancel_appliesNothing() async throws {
    let confirmation: ResourceSharePermissionConfirmation = try self.tested()
    try await confirmation.present()

    await self.cancel()

    XCTAssertTrue(self.appliedShares.get().isEmpty, "nothing may reach the server")
  }
}

// MARK: - Test helpers

// swift-format-ignore: AlwaysUseLowerCamelCase, NeverForceUnwrap
extension ResourceSharePermissionConfirmationTests {

  private func tested() throws -> ResourceSharePermissionConfirmation {
    try .init(features: self.testedFeatures, resourceID: .mock_1)
  }

  /// Confirms the recipients on the last presented screen, as its confirm button does.
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

  /// Leaves the last presented screen, as its cancel button does.
  private func cancel() async {
    guard let context: ConfirmPermissionsContext = self.presentedContexts.get().last
    else { return XCTFail("Confirmation was never presented") }
    await context.onCancel()
  }

  private func lastPresentedContext() throws -> ConfirmPermissionsContext {
    try XCTUnwrap(self.presentedContexts.get().last)
  }
}
