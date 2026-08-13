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

import Accounts
import FeatureScopes
import Metadata
import OSFeatures
import Resources
import SessionData
import SharedUIComponents
import TestExtensions

@testable import Display
@testable import PassboltApp

/// Removing the TOTP from a resource that carries more than it changes the resource type, which reshapes the secret
/// and re-encrypts it for every recipient - so a shared resource has to go through the same permission confirmation
/// as any other edit. Deleting a standalone TOTP deletes the resource instead and encrypts nothing, so it must not
/// ask for a confirmation at all.
// swift-format-ignore: AlwaysUseLowerCamelCase, NeverForceUnwrap
final class OTPResourcesListViewControllerTests: FeaturesTestCase {

  private let editedResource: Variable<Resource> = .init(
    initial: Resource.mock_sharedWithTOTP
  )
  /// The resource as the form was opened with - the baseline `isSecretEdited` is computed against.
  private let initialResource: CriticalState<Resource> = .init(
    Resource.mock_sharedWithTOTP
  )

  /// Points both the form state and the edit baseline at `resource`, as opening the form for it would.
  private func editing(
    _ resource: Resource
  ) {
    self.initialResource.set(resource)
    self.editedResource.mutate { (state: inout Resource) in
      state = resource
    }
  }

  override func commonPrepare() async throws {
    try await super.commonPrepare()

    set(
      SessionScope.self,
      context: .init(
        account: .mock_ada,
        configuration: .mock_default
      )
    )
    set(
      ResourceScope.self,
      context: .mock_1
    )
    set(
      ResourceEditScope.self,
      context: .init(
        editedResource: Resource.mock_sharedWithTOTP,
        availableTypes: [.mock_attachedOTP, .mock_detachedOTP]
      )
    )

    // The list itself - none of it is under test here, but the screen resolves it while being built.
    patch(
      \AccountDetails.avatarImage,
      with: always(Data?.none)
    )
    patch(
      \SessionData.lastUpdate,
      with: Variable<Timestamp>(initial: .init(rawValue: 0)).asAnyUpdatable()
    )
    patch(
      \SessionData.refreshProgress,
      with: Variable<Double?>(initial: .none).asAnyUpdatable()
    )
    patch(
      \ResourcesController.filteredResourcesList,
      with: always(Array<ResourceListItemDSV>())
    )
    patch(
      \ResourcesOTPController.hideOTP,
      with: always(Void())
    )
    patch(
      \NavigationToResourceOTPContextualMenu.mockPerform,
      with: always(Void())
    )
    patch(
      \NavigationToAccountMenu.mockPerform,
      with: always(Void())
    )
    usePlaceholder(for: OSPasteboard.self)

    // The removal itself.
    patch(
      \ResourceController.state,
      with: editedResource.asAnyUpdatable()
    )
    patch(
      \ResourceEditPreparation.prepareExisting,
      with: { @Sendable (_: Resource.ID) -> ResourceEditingContext in
        .init(
          editedResource: self.editedResource.value,
          availableTypes: [.mock_attachedOTP, .mock_detachedOTP]
        )
      }
    )
    patch(
      \ResourceEditForm.state,
      with: editedResource.asAnyUpdatable()
    )
    // The form mock mirrors the real one closely enough for the decision under test: detaching has to reach the
    // form as a type change, and `isSecretEdited` is computed from that rather than stubbed to `true` - a stub
    // would hide the detach failing to reach the form at all.
    patch(
      \ResourceEditForm.updateType,
      with: { @Sendable(type: ResourceType) in
        try self.editedResource.mutate { (resource: inout Resource) in
          try resource.updateType(to: type)
        }
      }
    )
    patch(
      \ResourceEditForm.validateForm,
      with: always(())
    )
    patch(
      \ResourceEditForm.isSecretEdited,
      with: { @Sendable in
        let current: Resource = self.editedResource.value
        let initial: Resource = self.initialResource.get()
        return current.isLocal
          || current.type.id != initial.type.id
          || current.secret != initial.secret
      }
    )
    // Nothing of the confirmation is on the navigation stack yet, so it can be presented.
    patch(
      \NavigationToConfirmPermissions.canPerformCheck,
      with: { (_: StaticString, _: UInt) -> Bool in true }
    )
  }

  /// Opens the contextual menu and hands back the removal action it was given - the only way into the removal from
  /// outside, and the same one the delete alert invokes.
  private func deleteOTPAction(
    of tested: OTPResourcesListViewController,
    for resourceID: Resource.ID = .mock_1
  ) async throws -> (@MainActor @Sendable () async -> Void) {
    let captured: CriticalState<(@MainActor @Sendable () async -> Void)?> = .init(.none)
    patch(
      \NavigationToResourceOTPContextualMenu.mockPerform,
      with: { (_: Bool, context: ResourceOTPContextualMenuViewController.Context) async throws -> Void in
        captured.set(context.deleteOTP)
      }
    )

    await tested.showContextualMenu(for: resourceID)

    guard let action: (@MainActor @Sendable () async -> Void) = captured.get()
    else { throw MockIssue.error() }
    return action
  }

  /// Mocks the permission confirmation as a screen that stays up once pushed, the way the real one does until the
  /// operator leaves it. Hands back how many times it was pushed - the destination is unique, so a second push
  /// throws and would report a failed deletion for a screen that is displayed and ready to be confirmed.
  private func displayedConfirmationPushCount() -> CriticalState<Int> {
    let pushCount: CriticalState<Int> = .init(0)
    let confirmationDisplayed: CriticalState<Bool> = .init(false)
    patch(
      \PermissionSnapshotService.forResource,
      with: always(.mock_shared)
    )
    patch(
      \NavigationToConfirmPermissions.canPerformCheck,
      with: { (_: StaticString, _: UInt) -> Bool in
        confirmationDisplayed.get() == false
      }
    )
    patch(
      \NavigationToConfirmPermissions.mockPerform,
      with: { (_: Bool, _: ConfirmPermissionsContext) in
        pushCount.access { (count: inout Int) in count += 1 }
        confirmationDisplayed.set(true)
      }
    )
    return pushCount
  }

  func test_deleteOTP_presentsConfirmation_whenDetachingFromSharedResource() async throws {
    let confirmationPresented: XCTestExpectation =
      self.expectation(description: "Permission confirmation should be presented")
    patch(
      \PermissionSnapshotService.forResource,
      with: always(.mock_shared)
    )
    patch(
      \NavigationToConfirmPermissions.mockPerform,
      with: { (_: Bool, context: ConfirmPermissionsContext) in
        XCTAssertEqual(context.mode, .edit(editable: true))
        XCTAssertEqual(context.operatorID, .mock_ada)
        confirmationPresented.fulfill()
      }
    )
    patch(
      \ResourceEditForm.sendForm,
      with: { @MainActor in
        XCTFail("Secret must not be re-encrypted before the recipients are confirmed")
        return self.editedResource.value
      }
    )

    let tested: OTPResourcesListViewController = try self.testedInstance(context: .init(pageSize: 10))

    let deleteOTP: (@MainActor @Sendable () async -> Void) = try await self.deleteOTPAction(of: tested)

    await deleteOTP()

    await fulfillment(of: [confirmationPresented], timeout: 1.0)
  }

  func test_deleteOTP_submitsDirectly_whenResourceIsPrivate() async throws {
    let formSubmitted: XCTestExpectation = self.expectation(description: "Form should be submitted")
    self.editing(Resource.mock_privateWithTOTP)
    patch(
      \NavigationToConfirmPermissions.mockPerform,
      with: { (_: Bool, _: ConfirmPermissionsContext) in
        XCTFail("A private resource has no recipients to confirm")
      }
    )
    patch(
      \ResourceEditForm.sendForm,
      with: { @MainActor in
        formSubmitted.fulfill()
        return self.editedResource.value
      }
    )

    let tested: OTPResourcesListViewController = try self.testedInstance(context: .init(pageSize: 10))

    let deleteOTP: (@MainActor @Sendable () async -> Void) = try await self.deleteOTPAction(of: tested)

    await deleteOTP()

    await fulfillment(of: [formSubmitted], timeout: 1.0)
  }

  /// A standalone TOTP is the resource, so removing the code deletes it. Nothing is re-encrypted for anyone and
  /// there is no recipient list to review.
  func test_deleteOTP_deletesTheResource_whenItIsAStandaloneTOTP() async throws {
    let resourceDeleted: XCTestExpectation = self.expectation(description: "Resource should be deleted")
    self.editing(Resource.mock_standaloneTOTP)
    patch(
      \NavigationToConfirmPermissions.mockPerform,
      with: { (_: Bool, _: ConfirmPermissionsContext) in
        XCTFail("Deleting a resource encrypts nothing - there is nothing to confirm")
      }
    )
    patch(
      \ResourceController.delete,
      with: { @Sendable in
        resourceDeleted.fulfill()
      }
    )
    patch(
      \ResourceEditForm.sendForm,
      with: { @MainActor in
        XCTFail("A standalone TOTP is deleted, not edited")
        return self.editedResource.value
      }
    )

    let tested: OTPResourcesListViewController = try self.testedInstance(context: .init(pageSize: 10))

    let deleteOTP: (@MainActor @Sendable () async -> Void) = try await self.deleteOTPAction(of: tested)

    await deleteOTP()

    await fulfillment(of: [resourceDeleted], timeout: 1.0)
  }

  /// Backing out of the confirmation leaves the resource as it was - the code is still there and nothing was
  /// encrypted for anyone.
  func test_deleteOTP_appliesNothing_whenConfirmationIsCancelled() async throws {
    let confirmationCancelled: XCTestExpectation =
      self.expectation(description: "Confirmation should be cancelled")
    patch(
      \PermissionSnapshotService.forResource,
      with: always(.mock_shared)
    )
    patch(
      \NavigationToConfirmPermissions.mockPerform,
      with: { (_: Bool, context: ConfirmPermissionsContext) in
        await context.onCancel()
        confirmationCancelled.fulfill()
      }
    )
    patch(
      \ResourceEditForm.sendForm,
      with: { @MainActor in
        XCTFail("Backing out must apply nothing")
        return self.editedResource.value
      }
    )
    patch(
      \ResourceEditForm.applyConfirmedPermissions,
      with: { @Sendable (_: OrderedSet<ResourcePermission>, _: PermissionSnapshot) -> Resource in
        XCTFail("Backing out must apply nothing")
        return self.editedResource.value
      }
    )

    let tested: OTPResourcesListViewController = try self.testedInstance(context: .init(pageSize: 10))

    let deleteOTP: (@MainActor @Sendable () async -> Void) = try await self.deleteOTPAction(of: tested)

    await deleteOTP()

    await fulfillment(of: [confirmationCancelled], timeout: 1.0)
  }

  /// Confirming applies the removal with the reviewed recipients. The flow driving it is retained by the list for
  /// exactly this reason - the alert that started the removal is long gone by the time the operator confirms.
  func test_confirmedDeletion_appliesTheConfirmedPermissions() async throws {
    let permissionsApplied: XCTestExpectation =
      self.expectation(description: "Confirmed permissions should be applied")
    let snapshot: PermissionSnapshot = .mock_shared
    patch(
      \PermissionSnapshotService.forResource,
      with: always(snapshot)
    )
    patch(
      \PermissionSnapshotService.drift,
      with: { @Sendable (_: PermissionSnapshot, _: PermissionSnapshot) -> PermissionDrift in .none }
    )
    patch(
      \NavigationToConfirmPermissions.mockRevert,
      with: always(Void())
    )
    patch(
      \ResourceEditForm.applyConfirmedPermissions,
      with: { @Sendable (_: OrderedSet<ResourcePermission>, _: PermissionSnapshot) -> Resource in
        permissionsApplied.fulfill()
        return self.editedResource.value
      }
    )

    let confirmApplied: CriticalState<Bool> = .init(false)
    patch(
      \NavigationToConfirmPermissions.mockPerform,
      with: { (_: Bool, context: ConfirmPermissionsContext) in
        let outcome: ConfirmPermissionsOutcome = await context.onConfirm(snapshot.permissions, snapshot)
        if case .applied = outcome {
          confirmApplied.set(true)
        }  // else NOP
      }
    )

    let tested: OTPResourcesListViewController = try self.testedInstance(context: .init(pageSize: 10))
    let deleteOTP: (@MainActor @Sendable () async -> Void) = try await self.deleteOTPAction(of: tested)

    await deleteOTP()

    await fulfillment(of: [permissionsApplied], timeout: 1.0)
    XCTAssertTrue(confirmApplied.get(), "The confirmed removal should report success to the confirmation screen")
  }

  /// Trusting a rotated metadata key runs this deletion again from the start while the confirmation it was
  /// rejected from is still displayed. That screen is the one to confirm from, so nothing is pushed a second time
  /// and the secret is not re-encrypted behind it.
  func test_deleteOTP_doesNotPresentConfirmationAgain_whileItIsStillDisplayed() async throws {
    let pushCount: CriticalState<Int> = self.displayedConfirmationPushCount()
    patch(
      \ResourceEditForm.sendForm,
      with: { @MainActor in
        XCTFail("Secret must not be re-encrypted while the recipients are still being confirmed")
        return self.editedResource.value
      }
    )

    let tested: OTPResourcesListViewController = try self.testedInstance(context: .init(pageSize: 10))

    let deleteOTP: (@MainActor @Sendable () async -> Void) = try await self.deleteOTPAction(of: tested)

    await deleteOTP()
    await deleteOTP()  // as trusting a rotated metadata key does

    XCTAssertEqual(pushCount.get(), 1)
  }

  /// Leaving the list releases a flow the operator abandoned - it owns the editing scope holding the decrypted
  /// secret - but never one whose confirmation is still displayed. The confirmation is what covers the list in the
  /// first place, and the deletion it drives confirms into that flow.
  func test_hidingOTPCodes_keepsTheFlow_whileItsConfirmationIsDisplayed() async throws {
    let pushCount: CriticalState<Int> = self.displayedConfirmationPushCount()
    patch(
      \ResourceEditForm.sendForm,
      with: { @MainActor in
        XCTFail("Secret must not be re-encrypted while the recipients are still being confirmed")
        return self.editedResource.value
      }
    )

    let tested: OTPResourcesListViewController = try self.testedInstance(context: .init(pageSize: 10))

    let deleteOTP: (@MainActor @Sendable () async -> Void) = try await self.deleteOTPAction(of: tested)

    await deleteOTP()
    tested.hideOTPCodes()  // as the confirmation covering the list does
    await deleteOTP()  // as trusting a rotated metadata key does

    XCTAssertEqual(pushCount.get(), 1)
  }

  /// Once the operator left the confirmation - cancelling it, or going back - they are free to open the contextual
  /// menu of another resource. The confirmation the next deletion puts up describes the resource that deletion is
  /// for, never the one it was opened for before.
  func test_deleteOTP_presentsConfirmationForTheOtherResource_afterTheOperatorLeftTheConfirmation() async throws {
    let confirmedResourceIDs: CriticalState<Array<Resource.ID>> = .init(.init())
    let snapshot: PermissionSnapshot = .mock_shared
    patch(
      \PermissionSnapshotService.forResource,
      with: { @Sendable (resourceID: Resource.ID) -> PermissionSnapshot in
        confirmedResourceIDs.access { (ids: inout Array<Resource.ID>) in ids.append(resourceID) }
        return snapshot
      }
    )
    patch(
      \NavigationToConfirmPermissions.mockPerform,
      with: { (_: Bool, _: ConfirmPermissionsContext) in }
    )
    patch(
      \ResourceEditForm.sendForm,
      with: { @MainActor in
        XCTFail("Secret must not be re-encrypted before the recipients are confirmed")
        return self.editedResource.value
      }
    )

    let tested: OTPResourcesListViewController = try self.testedInstance(context: .init(pageSize: 10))

    let deleteOTP: (@MainActor @Sendable () async -> Void) = try await self.deleteOTPAction(of: tested)
    await deleteOTP()

    // The confirmation was left (`canPerformCheck` reports it is no longer displayed) and the menu of another
    // resource opened.
    self.editing(Resource.mock_otherSharedWithTOTP)
    let deleteOtherOTP: (@MainActor @Sendable () async -> Void) =
      try await self.deleteOTPAction(of: tested, for: .mock_2)
    await deleteOtherOTP()

    let expectedResourceIDs: Array<Resource.ID> = [.mock_1, .mock_2]
    XCTAssertEqual(confirmedResourceIDs.get(), expectedResourceIDs)
  }
}

// MARK: - Fixtures

// swift-format-ignore: AlwaysUseLowerCamelCase, NeverForceUnwrap
extension Resource {

  /// An existing resource shared with someone else and carrying a code - removing the code detaches it, changing
  /// the type and re-encrypting the whole secret for both recipients.
  fileprivate static var mock_sharedWithTOTP: Resource {
    var resource: Resource = .init(
      id: .mock_1,
      type: .mock_attachedOTP,
      permission: .owner,
      permissions: [
        .user(id: .mock_ada, permission: .owner, permissionID: .mock_1),
        .user(id: .mock_1, permission: .read, permissionID: .mock_2),
      ],
      modified: .init(rawValue: 0)
    )
    resource.meta.name = .string("Mock_shared_with_totp")
    resource.secret.password = .string("R@nD0m")
    resource.secret.totp.secret_key = .string("SECRET")
    resource.secret.totp.algorithm = .string(HOTPAlgorithm.sha1.rawValue)
    resource.secret.totp.digits = .integer(6)
    resource.secret.totp.period = .integer(30)
    return resource
  }

  /// Another shared resource carrying a code - what the operator may open the menu of after leaving a
  /// confirmation.
  fileprivate static var mock_otherSharedWithTOTP: Resource {
    var resource: Resource = .init(
      id: .mock_2,
      type: .mock_attachedOTP,
      permission: .owner,
      permissions: [
        .user(id: .mock_ada, permission: .owner, permissionID: .mock_1),
        .user(id: .mock_1, permission: .read, permissionID: .mock_2),
      ],
      modified: .init(rawValue: 0)
    )
    resource.meta.name = .string("Mock_other_shared_with_totp")
    resource.secret.password = .string("0th3R")
    resource.secret.totp.secret_key = .string("OTHERSECRET")
    resource.secret.totp.algorithm = .string(HOTPAlgorithm.sha1.rawValue)
    resource.secret.totp.digits = .integer(6)
    resource.secret.totp.period = .integer(30)
    return resource
  }

  /// The same resource owned by the operator alone - no one else holds the secret, so there is nothing to confirm.
  fileprivate static var mock_privateWithTOTP: Resource {
    var resource: Resource = .mock_sharedWithTOTP
    resource.permissions = [
      .user(id: .mock_ada, permission: .owner, permissionID: .mock_1)
    ]
    return resource
  }

  /// A resource that is nothing but the code - removing it deletes the resource.
  fileprivate static var mock_standaloneTOTP: Resource {
    var resource: Resource = .init(
      id: .mock_1,
      type: .mock_standaloneTOTP,
      permission: .owner,
      permissions: [
        .user(id: .mock_ada, permission: .owner, permissionID: .mock_1),
        .user(id: .mock_1, permission: .read, permissionID: .mock_2),
      ],
      modified: .init(rawValue: 0)
    )
    resource.meta.name = .string("Mock_standalone_totp")
    resource.secret.totp.secret_key = .string("SECRET")
    resource.secret.totp.algorithm = .string(HOTPAlgorithm.sha1.rawValue)
    resource.secret.totp.digits = .integer(6)
    resource.secret.totp.period = .integer(30)
    return resource
  }
}

// swift-format-ignore: AlwaysUseLowerCamelCase, NeverForceUnwrap
extension ResourceType {

  /// A password resource carrying a code - what the removal detaches from.
  fileprivate static var mock_attachedOTP: Self {
    .init(id: .mock_2, slug: .passwordWithTOTP)
  }

  /// What it becomes once the code is gone.
  fileprivate static var mock_detachedOTP: Self {
    .init(id: .mock_3, slug: .passwordWithDescription)
  }

  /// A resource that is nothing but the code.
  fileprivate static var mock_standaloneTOTP: Self {
    .init(id: .mock_1, slug: .totp)
  }
}
