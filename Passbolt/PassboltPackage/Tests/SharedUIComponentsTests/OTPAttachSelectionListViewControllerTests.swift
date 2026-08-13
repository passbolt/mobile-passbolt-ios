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

import FeatureScopes
import Metadata
import OSFeatures
import Shared
import TestExtensions

@testable import Display
@testable import Resources
@testable import SharedUIComponents

/// Linking a scanned code to an existing resource rewrites its secret, so a shared resource has to go through the
/// same permission confirmation as any other edit before the new secret is encrypted for its recipients.
// swift-format-ignore: AlwaysUseLowerCamelCase, NeverForceUnwrap
final class OTPAttachSelectionListViewControllerTests: FeaturesTestCase {

  private let selectedResource: Variable<Resource> = .init(
    initial: Resource.mock_sharedPassword
  )
  /// The resource as the form was opened with - the baseline `isSecretEdited` is computed against.
  private let initialResource: CriticalState<Resource> = .init(
    Resource.mock_sharedPassword
  )

  /// Points both the form state and the edit baseline at `resource`, as opening the form for it would.
  private func editing(
    _ resource: Resource
  ) {
    self.initialResource.set(resource)
    self.selectedResource.mutate { (state: inout Resource) in
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

    patch(
      \ResourceSearchController.state,
      with: Variable<ResourceSearchState>(
        initial: .init(
          filter: .init(text: ""),
          result: .init()
        )
      )
      .asAnyUpdatable()
    )
    patch(
      \ResourceEditPreparation.prepareExisting,
      with: { @Sendable (_: Resource.ID) -> ResourceEditingContext in
        .init(
          editedResource: self.selectedResource.value,
          availableTypes: [.mock_attachedOTP]
        )
      }
    )
    patch(
      \ResourceEditForm.state,
      with: selectedResource.asAnyUpdatable()
    )
    // The form mock mirrors the real one closely enough for the decision under test: attaching has to reach the
    // form as a type change plus a secret write, and `isSecretEdited` is computed from that rather than stubbed
    // to `true` - a stub would hide the attach failing to reach the form at all.
    patch(
      \ResourceEditForm.updateType,
      with: { @Sendable(type: ResourceType) in
        try self.selectedResource.mutate { (resource: inout Resource) in
          try resource.updateType(to: type)
        }
      }
    )
    patch(
      \ResourceEditForm.updateField,
      with: { @Sendable(field: Resource.FieldPath, value: JSON) in
        self.selectedResource.mutate { $0.update(field, to: value) }
      }
    )
    patch(
      \ResourceEditForm.validateForm,
      with: always(())
    )
    patch(
      \ResourceEditForm.isSecretEdited,
      with: { @Sendable in
        let current: Resource = self.selectedResource.value
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
    patch(
      \NavigationToOTPScanning.mockRevert,
      with: always(Void())
    )
  }

  func test_sendForm_presentsConfirmation_whenResourceIsShared() async throws {
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
        return self.selectedResource.value
      }
    )

    let tested: OTPAttachSelectionListViewController = try self.testedInstance(context: .mock)
    tested.select(.mock_sharedPassword)

    await tested.sendForm()

    await fulfillment(of: [confirmationPresented], timeout: 1.0)
  }

  /// Replacing a code the resource already carries changes no type - only the secret - so the confirmation rides
  /// entirely on the secret comparison here. It is still a new secret encrypted for every current recipient, which
  /// is exactly what the confirmation exists to gate.
  func test_sendForm_presentsConfirmation_whenReplacingTOTPOfSharedResource() async throws {
    let confirmationPresented: XCTestExpectation =
      self.expectation(description: "Permission confirmation should be presented")
    self.editing(Resource.mock_sharedWithTOTP)
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
        XCTFail("Replaced secret must not be re-encrypted before the recipients are confirmed")
        return self.selectedResource.value
      }
    )

    let tested: OTPAttachSelectionListViewController = try self.testedInstance(context: .mock)
    tested.select(.mock_sharedWithTOTP)

    await tested.sendForm()

    await fulfillment(of: [confirmationPresented], timeout: 1.0)
  }

  func test_sendForm_submitsDirectly_whenResourceIsPrivate() async throws {
    let formSubmitted: XCTestExpectation = self.expectation(description: "Form should be submitted")
    self.selectedResource.mutate { (resource: inout Resource) in
      resource.permissions = [
        .user(id: .mock_ada, permission: .owner, permissionID: .mock_1)
      ]
    }
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
        return self.selectedResource.value
      }
    )

    let tested: OTPAttachSelectionListViewController = try self.testedInstance(context: .mock)
    tested.select(.mock_sharedPassword)

    await tested.sendForm()

    await fulfillment(of: [formSubmitted], timeout: 1.0)
  }

  /// Trusting a rotated metadata key runs this submission again from the start while the confirmation it was
  /// rejected from is still displayed. That screen is the one to confirm from, so nothing is pushed a second time
  /// and the secret is not submitted behind it.
  func test_sendForm_doesNotPresentConfirmationAgain_whileItIsStillDisplayed() async throws {
    let presentedCount: CriticalState<Int> = .init(0)
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
        presentedCount.access { (count: inout Int) in count += 1 }
        confirmationDisplayed.set(true)
      }
    )
    patch(
      \ResourceEditForm.sendForm,
      with: { @MainActor in
        XCTFail("Secret must not be re-encrypted while the recipients are still being confirmed")
        return self.selectedResource.value
      }
    )

    let tested: OTPAttachSelectionListViewController = try self.testedInstance(context: .mock)
    tested.select(.mock_sharedPassword)

    await tested.sendForm()
    await tested.sendForm()  // as trusting a rotated metadata key does

    XCTAssertEqual(presentedCount.get(), 1)
  }

  /// Once the operator left the confirmation - cancelling it, or going back - they are free to select another
  /// resource before submitting again. The confirmation the next submission puts up describes the resource that
  /// submission is for, never the one selected before.
  func test_sendForm_presentsConfirmationForTheNewSelection_afterTheOperatorLeftTheConfirmation() async throws {
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
        return self.selectedResource.value
      }
    )

    let tested: OTPAttachSelectionListViewController = try self.testedInstance(context: .mock)
    tested.select(.mock_sharedPassword)
    await tested.sendForm()

    // The confirmation was left (`canPerformCheck` reports it is no longer displayed) and another resource picked.
    self.editing(Resource.mock_otherSharedPassword)
    tested.select(.mock_otherSharedPassword)
    await tested.sendForm()

    let expectedResourceIDs: Array<Resource.ID> = [.mock_1, .mock_2]
    XCTAssertEqual(confirmedResourceIDs.get(), expectedResourceIDs)
  }
}

// MARK: - Fixtures
// swift-format-ignore: AlwaysUseLowerCamelCase, NeverForceUnwrap
extension OTPAttachSelectionListViewController.Context {

  fileprivate static var mock: Self {
    .init(
      totpSecret: .init(
        sharedSecret: "SECRET",
        algorithm: .sha1,
        digits: 6,
        period: 30
      )
    )
  }
}

// swift-format-ignore: AlwaysUseLowerCamelCase, NeverForceUnwrap
extension Resource {

  /// An existing password resource shared with someone else, owned by the operator.
  fileprivate static var mock_sharedPassword: Resource {
    var resource: Resource = .init(
      id: .mock_1,
      type: .mock_default,
      permission: .owner,
      permissions: [
        .user(id: .mock_ada, permission: .owner, permissionID: .mock_1),
        .user(id: .mock_1, permission: .read, permissionID: .mock_2),
      ],
      modified: .init(rawValue: 0)
    )
    resource.meta.name = .string("Mock_shared")
    resource.secret.password = .string("R@nD0m")
    return resource
  }

  /// The same shared resource, already carrying a code - what the "replace" confirmation applies to. Its secret
  /// differs from the scanned one, so attaching rewrites it.
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
    resource.secret.totp.secret_key = .string("PREVIOUSSECRET")
    resource.secret.totp.algorithm = .string(HOTPAlgorithm.sha1.rawValue)
    resource.secret.totp.digits = .integer(6)
    resource.secret.totp.period = .integer(30)
    return resource
  }

  /// Another shared password resource - what the operator may select after leaving a confirmation.
  fileprivate static var mock_otherSharedPassword: Resource {
    var resource: Resource = .init(
      id: .mock_2,
      type: .mock_default,
      permission: .owner,
      permissions: [
        .user(id: .mock_ada, permission: .owner, permissionID: .mock_1),
        .user(id: .mock_1, permission: .read, permissionID: .mock_2),
      ],
      modified: .init(rawValue: 0)
    )
    resource.meta.name = .string("Mock_other_shared")
    resource.secret.password = .string("0th3R")
    return resource
  }
}

// swift-format-ignore: AlwaysUseLowerCamelCase, NeverForceUnwrap
extension TOTPAttachSelectionListItemViewModel {

  /// The row for ``Resource/mock_sharedPassword`` as the list renders it.
  fileprivate static var mock_sharedPassword: Self {
    .init(
      id: .mock_1,
      typeInfo: ResourceType.mock_default.info,
      icon: .none,
      name: "Mock_shared",
      state: .deselected
    )
  }

  /// The row for ``Resource/mock_sharedWithTOTP`` - selecting it asks to replace the code it carries.
  fileprivate static var mock_sharedWithTOTP: Self {
    .init(
      id: .mock_1,
      typeInfo: ResourceType.mock_attachedOTP.info,
      icon: .none,
      name: "Mock_shared_with_totp",
      state: .deselected
    )
  }

  /// The row for ``Resource/mock_otherSharedPassword``.
  fileprivate static var mock_otherSharedPassword: Self {
    .init(
      id: .mock_2,
      typeInfo: ResourceType.mock_default.info,
      icon: .none,
      name: "Mock_other_shared",
      state: .deselected
    )
  }
}

// swift-format-ignore: AlwaysUseLowerCamelCase, NeverForceUnwrap
extension ResourceType {

  /// The type a password resource is changed to when a code is attached to it.
  fileprivate static var mock_attachedOTP: Self {
    .init(id: .mock_2, slug: .passwordWithTOTP)
  }
}
