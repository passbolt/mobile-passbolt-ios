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

/// Creating a standalone TOTP from a scanned code is a resource creation like any other - landing it in a shared
/// folder has to go through the permission confirmation instead of silently inheriting the folder's recipients.
// swift-format-ignore: AlwaysUseLowerCamelCase, NeverForceUnwrap
final class OTPScanningSuccessViewControllerTests: FeaturesTestCase {

  private let editedResource: Variable<Resource> = .init(
    initial: Resource.mock_scannedTOTPInFolder
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
        editedResource: Resource.mock_scannedTOTPInFolder,
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
    // Nothing of the confirmation is on the navigation stack: it can be presented, and once the flow reverted
    // itself there is nothing left for the applied path to pop.
    patch(
      \NavigationToConfirmPermissions.canPerformCheck,
      with: { (_: StaticString, _: UInt) -> Bool in true }
    )
    patch(
      \NavigationToOTPScanning.mockRevert,
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

  func test_createStandaloneOTP_presentsConfirmation_whenCreatedInSharedFolder() async throws {
    let confirmationPresented: XCTestExpectation =
      self.expectation(description: "Permission confirmation should be presented")
    patch(
      \PermissionSnapshotService.forFolder,
      with: always(.mock_shared)
    )
    patch(
      \NavigationToConfirmPermissions.mockPerform,
      with: { (_: Bool, context: ConfirmPermissionsContext) in
        XCTAssertEqual(context.mode, .create(editable: true))
        XCTAssertEqual(context.operatorID, .mock_ada)
        confirmationPresented.fulfill()
      }
    )
    patch(
      \ResourceEditForm.sendForm,
      with: { @MainActor in
        XCTFail("Resource must not be created before the permissions are confirmed")
        return self.editedResource.value
      }
    )

    let tested: OTPScanningSuccessViewController = try self.testedInstance(context: .mock)

    await tested.createStandaloneOTP()

    await fulfillment(of: [confirmationPresented], timeout: 1.0)
  }

  /// Leaving the scanning flow has to be a single navigation change. Popping the confirmation on its own first
  /// and the flow second leaves the operator on this screen - the second change is applied mid-transition and
  /// dropped - so reverting the scanning flow (which removes everything above it, confirmation included) is the
  /// only navigation the applied path performs.
  func test_confirmedCreate_revertsScanningFlow_withoutPoppingConfirmationSeparately() async throws {
    let navigationEvents: CriticalState<Array<String>> = .init(.init())
    let confirmationContext: CriticalState<ConfirmPermissionsContext?> = .init(.none)
    patch(
      \PermissionSnapshotService.forFolder,
      with: always(.mock_shared)
    )
    patch(
      \NavigationToConfirmPermissions.mockPerform,
      with: { (_: Bool, context: ConfirmPermissionsContext) in
        confirmationContext.access { $0 = context }
      }
    )
    patch(
      \NavigationToConfirmPermissions.mockRevert,
      with: { (_: Bool) in
        navigationEvents.access { $0.append("revert-confirmation") }
      }
    )
    patch(
      \NavigationToOTPScanning.mockRevert,
      with: { (_: Bool) in
        navigationEvents.access { $0.append("revert-scanning") }
      }
    )
    patch(
      \ResourceEditForm.createResourcePrivate,
      with: { @MainActor in Resource.mock_createdTOTPInFolder }
    )
    patch(
      \ResourceShareConfirmation.applyToCreatedResource,
      with: always(Void())
    )

    let snapshot: PermissionSnapshot = .mock_shared
    let tested: OTPScanningSuccessViewController = try self.testedInstance(context: .mock)
    await tested.createStandaloneOTP()

    let context: ConfirmPermissionsContext = try XCTUnwrap(confirmationContext.get())
    let outcome: ConfirmPermissionsOutcome = await context.onConfirm(snapshot.permissions, snapshot)

    guard case .applied = outcome
    else { return XCTFail("Confirmed create should report the permissions as applied") }
    XCTAssertEqual(navigationEvents.get(), ["revert-scanning"])
  }

  func test_createStandaloneOTP_submitsDirectly_whenFolderIsPrivate() async throws {
    let formSubmitted: XCTestExpectation = self.expectation(description: "Form should be submitted")
    patch(
      \PermissionSnapshotService.forFolder,
      with: always(.mock_private)
    )
    patch(
      \NavigationToConfirmPermissions.mockPerform,
      with: { (_: Bool, _: ConfirmPermissionsContext) in
        XCTFail("Creating in a private folder implies no sharing - nothing to confirm")
      }
    )
    patch(
      \ResourceEditForm.sendForm,
      with: { @MainActor in
        formSubmitted.fulfill()
        return self.editedResource.value
      }
    )

    let tested: OTPScanningSuccessViewController = try self.testedInstance(context: .mock)

    await tested.createStandaloneOTP()

    await fulfillment(of: [formSubmitted], timeout: 1.0)
  }

  func test_createStandaloneOTP_submitsDirectly_whenCreatedOutsideOfAnyFolder() async throws {
    let formSubmitted: XCTestExpectation = self.expectation(description: "Form should be submitted")
    self.editedResource.mutate { (resource: inout Resource) in
      resource.path = .init()
    }
    patch(
      \NavigationToConfirmPermissions.mockPerform,
      with: { (_: Bool, _: ConfirmPermissionsContext) in
        XCTFail("A resource without a parent folder inherits nothing - nothing to confirm")
      }
    )
    patch(
      \ResourceEditForm.sendForm,
      with: { @MainActor in
        formSubmitted.fulfill()
        return self.editedResource.value
      }
    )

    let tested: OTPScanningSuccessViewController = try self.testedInstance(context: .mock)

    await tested.createStandaloneOTP()

    await fulfillment(of: [formSubmitted], timeout: 1.0)
  }
}

// MARK: - Fixtures
// swift-format-ignore: AlwaysUseLowerCamelCase, NeverForceUnwrap
extension OTPScanningSuccessViewController.Context {

  fileprivate static var mock: Self {
    .init(
      totpConfiguration: .init(
        issuer: "passbolt.com",
        account: "ada@passbolt.com",
        secret: .init(
          sharedSecret: "SECRET",
          algorithm: .sha1,
          digits: 6,
          period: 30
        )
      )
    )
  }
}

// swift-format-ignore: AlwaysUseLowerCamelCase, NeverForceUnwrap
extension Resource {

  /// A standalone TOTP that does not exist on the server yet, scanned into a folder.
  fileprivate static var mock_scannedTOTPInFolder: Resource {
    Resource.mock_totp.with { (resource: inout Resource) in
      resource.id = .none
      resource.path = [.mock_1]
    }
  }

  /// The resource as `createResourcePrivate` returns it - existing on the server, owned by the operator alone.
  fileprivate static var mock_createdTOTPInFolder: Resource {
    Resource.mock_scannedTOTPInFolder.with { (resource: inout Resource) in
      resource.id = .mock_1
      resource.permission = .owner
      resource.permissions = [
        .user(id: .mock_ada, permission: .owner, permissionID: .mock_1)
      ]
    }
  }
}
