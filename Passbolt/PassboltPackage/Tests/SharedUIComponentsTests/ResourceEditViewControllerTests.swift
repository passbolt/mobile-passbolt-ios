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

import Metadata
import OSFeatures
import Shared
import TestExtensions

@testable import Display
@testable import Resources
@testable import SharedUIComponents

// swift-format-ignore: AlwaysUseLowerCamelCase, NeverForceUnwrap
final class ResourceEditViewControllerTests: FeaturesTestCase {

  private let editedResource: Variable<Resource> = .init(initial: .mock_1)
  private var successCalledWithResource: Resource?
  private var formSendCalled: Bool = false

  override func commonPrepare() {
    super.commonPrepare()
    successCalledWithResource = nil
    formSendCalled = false

    set(
      ResourceEditScope.self,
      context: .init(
        editedResource: editedResource.value,
        availableTypes: [editedResource.value.type, Resource.mock_2.type]
      )
    )

    patch(
      \PasswordService.entropy,
      with: always(.fairPassword)
    )
    patch(
      \PasswordService.generate,
      with: always("GeneratedPassword123!")
    )
    patch(
      \PasswordService.validate,
      with: always(.valid)
    )

    patch(
      \NavigationToResourceEdit.mockRevert,
      with: always(Void())
    )
    patch(
      \ResourceEditForm.state,
      with: editedResource.asAnyUpdatable()
    )
    patch(
      \ResourceEditForm.updateField,
      with: { @Sendable field, value in
        self.editedResource.mutate { $0.update(field, to: value) }
      }
    )
    patch(
      \ResourceEditForm.updateExpiryDateIfNeeded,
      with: always(())
    )
    patch(
      \ResourceEditForm.validateForm,
      with: always(())
    )
    patch(
      \MetadataSettingsService.typesSettings,
      with: always(
        .init(
          defaultResourceTypes: .v4,
          allowV4ToV5Upgrade: false
        )
      )
    )
  }

  private func makeContext() -> ResourceEditViewController.Context {
    .init(
      editingContext: .init(
        editedResource: editedResource.value,
        availableTypes: [editedResource.value.type, Resource.mock_2.type]
      ),
      success: { _ in
        /** no-op **/
      }
    )
  }

  // MARK: - Form send tests

  func test_sendForm_submitsDirectly_whenPasswordFieldWasNotEdited() async throws {
    patch(
      \ResourceEditForm.sendForm,
      with: { @MainActor in
        self.mockExecuted()
        let resource: Resource = self.editedResource.value
        XCTAssertEqual(resource.meta.name, "updated name")
        return resource
      }
    )

    let tested: ResourceEditViewController = try self.testedInstance(context: makeContext())
    tested.set("updated name", for: \.meta.name)

    try await tested.sendForm()

    await verify(self.mockWasExecuted)
  }

  func test_sendForm_validatesPassword_whenPasswordFieldWasEdited() async throws {
    let passwordValidationExpectation: XCTestExpectation =
      self.expectation(description: "Password validation should be called")
    let formSubmittedExpectation: XCTestExpectation =
      self.expectation(description: "Form should be submitted")
    patch(
      \PasswordService.validate,
      with: { newPassword in
        passwordValidationExpectation.fulfill()
        XCTAssertEqual(newPassword, "updated password")
        return .valid
      }
    )
    patch(
      \ResourceEditForm.sendForm,
      with: { @MainActor in
        formSubmittedExpectation.fulfill()
        let resource: Resource = self.editedResource.value
        XCTAssertEqual(resource.firstPasswordString, "updated password")
        return resource
      }
    )
    let tested: ResourceEditViewController = try self.testedInstance(context: makeContext())
    tested.set("updated password", for: editedResource.value.firstPasswordPath!)

    try await tested.sendForm()

    await fulfillment(of: [passwordValidationExpectation, formSubmittedExpectation], timeout: 1.0)
  }

  func test_sendForm_showsWeakPasswordAlert_whenPasswordIsWeak() async throws {
    let passwordValidationExpectation: XCTestExpectation =
      self.expectation(description: "Password validation should be called")

    patch(
      \PasswordService.validate,
      with: { newPassword in
        passwordValidationExpectation.fulfill()
        XCTAssertEqual(newPassword, "updated password")
        return .weak
      }
    )

    let tested: ResourceEditViewController = try self.testedInstance(context: makeContext())
    tested.set("updated password", for: editedResource.value.firstPasswordPath!)
    var currentState: ResourceEditViewController.ViewState = await tested.viewState.current
    XCTAssertNil(currentState.alert)
    try await tested.sendForm()

    await fulfillment(of: [passwordValidationExpectation], timeout: 1.0)
    currentState = await tested.viewState.current
    XCTAssertNotNil(currentState.alert)
  }

  func test_sendForm_showsPwnedPasswordAlert_whenPasswordIsLeaked() async throws {
    let passwordValidationExpectation: XCTestExpectation =
      self.expectation(description: "Password validation should be called")

    patch(
      \PasswordService.validate,
      with: { newPassword in
        passwordValidationExpectation.fulfill()
        XCTAssertEqual(newPassword, "updated password")
        return .pwned
      }
    )

    let tested: ResourceEditViewController = try self.testedInstance(context: makeContext())
    tested.set("updated password", for: editedResource.value.firstPasswordPath!)
    var currentState: ResourceEditViewController.ViewState = await tested.viewState.current
    XCTAssertNil(currentState.alert)
    try await tested.sendForm()

    await fulfillment(of: [passwordValidationExpectation], timeout: 1.0)
    currentState = await tested.viewState.current
    XCTAssertNotNil(currentState.alert)
  }

  func test_sendForm_showsAlert_whenPasswordCheckIsNotAvailable() async throws {
    let passwordValidationExpectation: XCTestExpectation =
      self.expectation(description: "Password validation should be called")

    patch(
      \PasswordService.validate,
      with: { newPassword in
        passwordValidationExpectation.fulfill()
        XCTAssertEqual(newPassword, "updated password")
        throw PasswordService.PasswordExternalCheckFailure.error()
      }
    )

    let tested: ResourceEditViewController = try self.testedInstance(context: makeContext())
    tested.set("updated password", for: editedResource.value.firstPasswordPath!)
    var currentState: ResourceEditViewController.ViewState = await tested.viewState.current
    XCTAssertNil(currentState.alert)
    try await tested.sendForm()

    await fulfillment(of: [passwordValidationExpectation], timeout: 1.0)
    currentState = await tested.viewState.current
    XCTAssertNotNil(currentState.alert)
  }

  func test_sendForm_callsSuccessCallback_whenSubmissionSucceeds() async throws {
    let callbackCalledExpectation: XCTestExpectation =
      self.expectation(description: "Success callback should be called")
    let formSubmittedExpectation: XCTestExpectation =
      self.expectation(description: "Form should be submitted")
    patch(
      \ResourceEditForm.sendForm,
      with: { @MainActor in
        formSubmittedExpectation.fulfill()
        return self.editedResource.value
      }
    )

    let tested: ResourceEditViewController = try self.testedInstance(
      context: .init(
        editingContext: .init(
          editedResource: editedResource.value,
          availableTypes: [editedResource.value.type]
        ),
        success: { _ in
          callbackCalledExpectation.fulfill()
        }
      )
    )

    try await tested.sendForm()

    await fulfillment(of: [callbackCalledExpectation, formSubmittedExpectation], timeout: 1.0)
  }

  func test_sendForm_throwsInvalidForm_whenValidationFails() async throws {
    patch(
      \ResourceEditForm.validateForm,
      with: {
        throw InvalidForm.error(
          displayable: "validation.failed"
        )
      }
    )

    let tested: ResourceEditViewController = try self.testedInstance(
      context: makeContext()
    )

    tested.set("", for: \.meta.name)

    do {
      try await tested.sendForm()
      XCTFail("Expected InvalidForm error to be thrown")
    }
    catch is InvalidForm {
      // expected
    }
    catch {
      XCTFail("Unexpected error type: \(error)")
    }
  }

  // MARK: - V4 to V5 upgrade banner tests

  private func patchV4ResourceWithAvailableTypes(
    _ resource: Resource,
    availableTypes: Array<ResourceType>
  ) -> ResourceEditViewController.Context {
    patch(
      \ResourceEditForm.state,
      with: Variable<Resource>(initial: resource).asAnyUpdatable()
    )
    set(
      ResourceEditScope.self,
      context: .init(
        editedResource: resource,
        availableTypes: availableTypes
      )
    )
    return .init(
      editingContext: .init(
        editedResource: resource,
        availableTypes: availableTypes
      ),
      success: { _ in }
    )
  }

  func test_showsV4UpgradeBanner_isFalse_whenFlagIsDisabled() async throws {
    patch(
      \MetadataSettingsService.typesSettings,
      with: always(.init(defaultResourceTypes: .v4, allowV4ToV5Upgrade: false))
    )
    let v5Type: ResourceType = .init(id: .mock_4, slug: .v5StandaloneTOTP)
    let context: ResourceEditViewController.Context = patchV4ResourceWithAvailableTypes(
      .mock_totp,
      availableTypes: [.mock_totp, v5Type]
    )

    let tested: ResourceEditViewController = try self.testedInstance(context: context)
    let state: ResourceEditViewController.ViewState = await tested.viewState.current

    XCTAssertFalse(state.showsV4UpgradeBanner)
  }

  func test_showsV4UpgradeBanner_isFalse_whenV5TypeMissingFromAvailableTypes() async throws {
    patch(
      \MetadataSettingsService.typesSettings,
      with: always(.init(defaultResourceTypes: .v4, allowV4ToV5Upgrade: true))
    )
    let context: ResourceEditViewController.Context = patchV4ResourceWithAvailableTypes(
      .mock_totp,
      availableTypes: [.mock_totp]
    )

    let tested: ResourceEditViewController = try self.testedInstance(context: context)
    let state: ResourceEditViewController.ViewState = await tested.viewState.current

    XCTAssertFalse(state.showsV4UpgradeBanner)
  }

  func test_showsV4UpgradeBanner_isFalse_whenResourceIsV5() async throws {
    patch(
      \MetadataSettingsService.typesSettings,
      with: always(.init(defaultResourceTypes: .v5, allowV4ToV5Upgrade: true))
    )
    let v5Type: ResourceType = .init(id: .mock_4, slug: .v5DefaultWithTOTP)
    let v5Resource: Resource = .init(
      id: .mock_1,
      type: v5Type,
      modified: .init(rawValue: 0)
    )
    let context: ResourceEditViewController.Context = patchV4ResourceWithAvailableTypes(
      v5Resource,
      availableTypes: [v5Type]
    )

    let tested: ResourceEditViewController = try self.testedInstance(context: context)
    let state: ResourceEditViewController.ViewState = await tested.viewState.current

    XCTAssertFalse(state.showsV4UpgradeBanner)
  }

  func test_showsV4UpgradeBanner_isTrue_whenAllConditionsMet() async throws {
    patch(
      \MetadataSettingsService.typesSettings,
      with: always(.init(defaultResourceTypes: .v4, allowV4ToV5Upgrade: true))
    )
    let v5Type: ResourceType = .init(id: .mock_4, slug: .v5StandaloneTOTP)
    let context: ResourceEditViewController.Context = patchV4ResourceWithAvailableTypes(
      .mock_totp,
      availableTypes: [.mock_totp, v5Type]
    )

    let tested: ResourceEditViewController = try self.testedInstance(context: context)
    let state: ResourceEditViewController.ViewState = await tested.viewState.current

    XCTAssertTrue(state.showsV4UpgradeBanner)
  }

  func test_upgradeResourceToV5_callsUpdateType_withV5Equivalent() async throws {
    patch(
      \MetadataSettingsService.typesSettings,
      with: always(.init(defaultResourceTypes: .v4, allowV4ToV5Upgrade: true))
    )
    let v5Type: ResourceType = .init(id: .mock_4, slug: .v5StandaloneTOTP)
    let context: ResourceEditViewController.Context = patchV4ResourceWithAvailableTypes(
      .mock_totp,
      availableTypes: [.mock_totp, v5Type]
    )
    let receivedSlug: CriticalState<ResourceSpecification.Slug?> = .init(.none)
    patch(
      \ResourceEditForm.updateType,
      with: { @Sendable type in
        receivedSlug.set(type.specification.slug)
      }
    )

    let tested: ResourceEditViewController = try self.testedInstance(context: context)
    await tested.upgradeResourceToV5()

    XCTAssertEqual(receivedSlug.get(), .v5StandaloneTOTP)
  }

  func test_upgradeResourceToV5_doesNotCallUpdateType_whenV5EquivalentMissing() async throws {
    patch(
      \MetadataSettingsService.typesSettings,
      with: always(.init(defaultResourceTypes: .v4, allowV4ToV5Upgrade: true))
    )
    let v5Type: ResourceType = .init(id: .mock_4, slug: .v5Default)
    let context: ResourceEditViewController.Context = patchV4ResourceWithAvailableTypes(
      .mock_totp,
      availableTypes: [.mock_totp, v5Type]
    )
    let updateCalled: CriticalState<Bool> = .init(false)
    patch(
      \ResourceEditForm.updateType,
      with: { @Sendable _ in
        updateCalled.set(true)
      }
    )

    let tested: ResourceEditViewController = try self.testedInstance(context: context)
    await tested.upgradeResourceToV5()

    XCTAssertFalse(updateCalled.get())
  }

  func test_openV4UpgradeLearnMore_opensBlogURL() async throws {
    let receivedURL: CriticalState<URLString?> = .init(.none)
    patch(
      \OSLinkOpener.openURL,
      with: { @Sendable url in
        receivedURL.set(url)
      }
    )
    let context: ResourceEditViewController.Context = patchV4ResourceWithAvailableTypes(
      .mock_totp,
      availableTypes: [.mock_totp]
    )

    let tested: ResourceEditViewController = try self.testedInstance(context: context)
    await tested.openV4UpgradeLearnMore()

    XCTAssertEqual(
      receivedURL.get(),
      .blogPostV4toV5Upgrade
    )
  }
}
