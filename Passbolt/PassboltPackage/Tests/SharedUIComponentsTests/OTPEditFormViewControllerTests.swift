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

/// Saving a standalone TOTP from the dedicated OTP form submits the whole resource, so changing the secret of a
/// shared one has to go through the permission confirmation like any other edit.
// swift-format-ignore: AlwaysUseLowerCamelCase, NeverForceUnwrap
final class OTPEditFormViewControllerTests: FeaturesTestCase {

  private let editedResource: Variable<Resource> = .init(
    initial: Resource.mock_sharedTOTP
  )

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
      ResourceEditScope.self,
      context: .init(
        editedResource: Resource.mock_sharedTOTP,
        availableTypes: [ResourceType.mock_totp]
      )
    )

    patch(
      \ResourceEditForm.state,
      with: editedResource.asAnyUpdatable()
    )
    patch(
      \ResourceEditForm.validateForm,
      with: always(())
    )
    patch(
      \ResourceEditForm.isSecretEdited,
      with: always(true)
    )
    // Nothing of the confirmation is on the navigation stack yet, so it can be presented.
    patch(
      \NavigationToConfirmPermissions.canPerformCheck,
      with: { (_: StaticString, _: UInt) -> Bool in true }
    )
    patch(
      \NavigationToOTPEditForm.mockRevert,
      with: always(Void())
    )
    // Submitting a secret edit asks the server who holds the resource before deciding whether to confirm, so
    // every test reaches this - defaulted to "nobody else holds it" and overridden where sharing is the point.
    patch(
      \PermissionSnapshotService.forResource,
      with: always(.mock_private)
    )
    patch(
      \PermissionSnapshotService.forFolder,
      with: always(.mock_private)
    )
  }

  func test_createOrUpdateOTP_presentsConfirmation_whenResourceIsShared() async throws {
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

    let tested: OTPEditFormViewController = try self.testedInstance(context: .mock)

    await tested.createOrUpdateOTP()

    await fulfillment(of: [confirmationPresented], timeout: 1.0)
  }

  /// The server's capture decides, not the cached resource - and a resource it reports as private is applied
  /// against that capture rather than through the plain submission, which draws its recipients from the cache.
  func test_createOrUpdateOTP_submitsDirectly_whenResourceIsPrivate() async throws {
    let formSubmitted: XCTestExpectation = self.expectation(description: "Form should be submitted")
    patch(
      \PermissionSnapshotService.forResource,
      with: always(.mock_private)
    )
    patch(
      \NavigationToConfirmPermissions.mockPerform,
      with: { (_: Bool, _: ConfirmPermissionsContext) in
        XCTFail("A private resource has no recipients to confirm")
      }
    )
    patch(
      \ResourceEditForm.sendForm,
      with: { @MainActor in
        XCTFail("The cached recipient set must not decide who the secret is encrypted for")
        return self.editedResource.value
      }
    )
    patch(
      \ResourceEditForm.applyConfirmedPermissions,
      with: { (permissions: OrderedSet<ResourcePermission>, _: PermissionSnapshot) in
        XCTAssertEqual(permissions, PermissionSnapshot.mock_private.permissions)
        formSubmitted.fulfill()
        return self.editedResource.value
      }
    )

    let tested: OTPEditFormViewController = try self.testedInstance(context: .mock)

    await tested.createOrUpdateOTP()

    await fulfillment(of: [formSubmitted], timeout: 1.0)
  }

  /// A confirmation the operator left leaves the resource created, so the form it comes back to no longer looks
  /// local and already carries the code. The screen still created that code rather than replacing one, and saying
  /// otherwise would describe an edit that never happened.
  func test_createOrUpdateOTP_reportsTheCodeAsCreated_whenTheConfirmationSavesIt() async throws {
    set(
      ResourceEditScope.self,
      context: .init(
        editedResource: Resource.mock_newTOTPInFolder,
        availableTypes: [ResourceType.mock_totp]
      )
    )
    self.editedResource.mutate { (resource: inout Resource) in
      resource = Resource.mock_newTOTPInFolder
    }
    let presentedContext: CriticalState<ConfirmPermissionsContext?> = .init(.none)
    patch(
      \PermissionSnapshotService.forFolder,
      with: always(.mock_shared)
    )
    patch(
      \NavigationToConfirmPermissions.mockPerform,
      with: { (_: Bool, context: ConfirmPermissionsContext) in
        presentedContext.set(context)
      }
    )
    patch(
      \ResourceEditForm.createResourcePrivate,
      with: { @MainActor in
        // The form is pointed at the created resource, as the live form does - it stops looking local here.
        self.editedResource.mutate { (resource: inout Resource) in
          resource = Resource.mock_createdTOTPInFolder
        }
        return Resource.mock_createdTOTPInFolder
      }
    )
    // The first share drifts, leaving the resource created and awaiting its share.
    let driftedOnce: CriticalState<Bool> = .init(false)
    patch(
      \ResourceShareConfirmation.applyToCreatedResource,
      with: {
        @Sendable (_, _, _, _) throws in
        guard driftedOnce.get()
        else {
          driftedOnce.set(true)
          throw PermissionDriftDetected.error()
        }
      }
    )

    let snapshot: PermissionSnapshot = .mock_shared
    let tested: OTPEditFormViewController = try self.testedInstance(context: .mock)
    await tested.createOrUpdateOTP()
    let driftedContext: ConfirmPermissionsContext = try XCTUnwrap(presentedContext.get())
    _ = await driftedContext.onConfirm(snapshot.permissions, snapshot)

    // Saved again, on a form that points at the created resource by now.
    await tested.createOrUpdateOTP()
    let messagesSubscription: EventSubscription<SnackBarMessageEvent> = SnackBarMessageEvent.subscribe()
    let resumedContext: ConfirmPermissionsContext = try XCTUnwrap(presentedContext.get())
    _ = await resumedContext.onConfirm(snapshot.permissions, snapshot)

    let expectedMessage: SnackBarMessageEvent.Payload = .show("otp.edit.otp.created.message")
    let message: SnackBarMessageEvent.Payload = try await messagesSubscription.nextEvent()
    XCTAssertEqual(message, expectedMessage)
  }
}

// MARK: - Fixtures
// swift-format-ignore: AlwaysUseLowerCamelCase, NeverForceUnwrap
extension OTPEditFormViewController.Context {

  fileprivate static var mock: Self {
    .init(totpPath: Resource.mock_totp.firstTOTPPath!)
  }
}

// swift-format-ignore: AlwaysUseLowerCamelCase, NeverForceUnwrap
extension Resource {

  /// An existing standalone TOTP shared with someone else, owned by the operator.
  fileprivate static var mock_sharedTOTP: Resource {
    Resource.mock_totp.with { (resource: inout Resource) in
      resource.permission = .owner
      resource.permissions = [
        .user(id: .mock_ada, permission: .owner, permissionID: .mock_1),
        .user(id: .mock_1, permission: .read, permissionID: .mock_2),
      ]
    }
  }

  /// A standalone TOTP that does not exist on the server yet, being created inside a folder.
  fileprivate static var mock_newTOTPInFolder: Resource {
    Resource.mock_totp.with { (resource: inout Resource) in
      resource.id = .none
      resource.path = [.mock_1]
      resource.permission = .owner
      resource.permissions = .init()
    }
  }

  /// The same resource as `createResourcePrivate` returns it - on the server, owned by the operator alone.
  fileprivate static var mock_createdTOTPInFolder: Resource {
    Resource.mock_newTOTPInFolder.with { (resource: inout Resource) in
      resource.id = .mock_3
      resource.permissions = [
        .user(id: .mock_ada, permission: .owner, permissionID: .mock_1)
      ]
    }
  }
}
