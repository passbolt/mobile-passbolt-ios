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

/// Sharing, editing a shared resource and creating one in a shared folder all route through the
/// "Confirm permissions" checkpoint; sharing can never skip it.
///
/// Requires an automation backend providing this feature's endpoints - `filter[has-id]` on users and groups, and
/// single-item fetch with `contain[permissions]`.
@MainActor
final internal class PermissionConfirmationTests: UITestCase {

  /// Sharing composes the recipients on the confirmation screen itself, so it can never be skipped.
  func test_shareRoutesThroughConfirmationScreen() async throws {
    let resourceName: ResourceName = "ConfirmShare".withDateSuffix().withRandomSuffix()

    await executeSteps {
      SelectAllItemsFilter()
      CreateResource(resourceName: resourceName)
      VerifySnackBarMessage(expectedMessage: "New password has been created")
      OpenResourceDetails(resourceName: resourceName)
      On(ResourceDetailsScreen.self) { details in
        ScrollUntilVisible(details.permissionsContent, "Permissions section")
        Tap(details.permissionsContent, "Open permissions")
      }
      On(PermissionsListScreen.self) { permissions in
        Tap(permissions.editButton, "Edit permissions")
      }
      On(ConfirmPermissionsScreen.self, timeout: .longNetworkCall) { confirm in
        // Sharing keeps the dedicated share screen's title - the operator asked to share, not to confirm a form.
        WaitFor(confirm.shareTitle, timeout: .longNetworkCall, "Sharing is titled as the share screen")
        AddPermissionForGroup(groupName: "Only Betty Group")
        WaitFor(
          confirm.recipientRow("Only Betty Group"),
          timeout: .longNetworkCall,
          "The recipient the secret would be encrypted for is listed"
        )
        Tap(confirm.confirmButton, "Confirm the recipients")
      }
      On(PermissionsListScreen.self, timeout: .longNetworkCall) { permissions in
        WaitFor(
          permissions.collectionView.staticTexts["Only Betty Group"],
          timeout: .longNetworkCall,
          "The confirmed recipient holds the permission"
        )
      }
    }
  }

  /// Backing out of the share confirmation leaves the resource shared with nobody new.
  func test_backingOutOfShareConfirmationChangesNothing() async throws {
    let resourceName: ResourceName = "ConfirmShareCancel".withDateSuffix().withRandomSuffix()

    await executeSteps {
      SelectAllItemsFilter()
      CreateResource(resourceName: resourceName)
      VerifySnackBarMessage(expectedMessage: "New password has been created")
      OpenResourceDetails(resourceName: resourceName)
      On(ResourceDetailsScreen.self) { details in
        ScrollUntilVisible(details.permissionsContent, "Permissions section")
        Tap(details.permissionsContent, "Open permissions")
      }
      On(PermissionsListScreen.self) { permissions in
        Tap(permissions.editButton, "Edit permissions")
      }
      On(ConfirmPermissionsScreen.self, timeout: .longNetworkCall) { confirm in
        AddPermissionForGroup(groupName: "Only Betty Group")
        Tap(confirm.cancelButton, "Back out of confirmation")
      }
      // nothing reached the server, so the resource is still shared with nobody but the operator
      On(PermissionsListScreen.self, timeout: .networkCall) { permissions in
        VerifyPermissionCellCount(collectionView: permissions.collectionView, expectedCount: 1)
      }
    }
  }

  /// Editing only metadata of a shared resource does not re-encrypt the secret, so there is nothing to confirm -
  /// the save goes straight through.
  func test_metadataOnlyEditOfSharedResourceSkipsConfirmation() async throws {
    let resourceName: ResourceName = "ConfirmMetaEdit".withDateSuffix().withRandomSuffix()
    let updatedName: String = "ConfirmMetaEdited".withDateSuffix().withRandomSuffix()
    let application: XCUIApplication = await self.application

    await executeSteps {
      ShareResourceWithGroup(resourceName: resourceName, groupName: "Only Betty Group")
      OpenResourceDetailsActionMenu(resourceName: resourceName)
      On(ResourceDetailsActionMenuScreen.self) { menu in
        Tap(menu.editButton, "Edit")
      }
      On(ResourceEditScreen.self) { edit in
        ReplaceText(updatedName, in: edit.nameField, "Edit name only")
          .dismissKeyboardIfNeeded()
        Tap(edit.saveButton, "Save")
      }
      // reaching the list at all proves the confirmation screen did not interpose
      WaitFor(application.staticTexts[updatedName], timeout: .slowNetworkCall, "Resource name updated")
      Verify(
        application.buttons["permissions.confirm.button"].exists == false,
        "Confirmation screen is not shown for a metadata-only edit"
      )
    }
  }

  /// Nobody else holds it, so there is nothing to confirm. Also covers that asking the server whether it is
  /// shared - rather than the local copy - does not turn an ordinary edit into a failure.
  func test_secretEditOfPrivateResourceSkipsConfirmation() async throws {
    let resourceName: ResourceName = "ConfirmPrivateEdit".withDateSuffix().withRandomSuffix()
    let updatedName: String = "ConfirmPrivateEdited".withDateSuffix().withRandomSuffix()
    let application: XCUIApplication = await self.application

    await executeSteps {
      SelectAllItemsFilter()
      CreateResource(resourceName: resourceName)
      VerifySnackBarMessage(expectedMessage: "New password has been created")
      OpenResourceDetailsActionMenu(resourceName: resourceName)
      On(ResourceDetailsActionMenuScreen.self) { menu in
        Tap(menu.editButton, "Edit")
      }
      On(ResourceEditScreen.self) { edit in
        ReplaceText(updatedName, in: edit.nameField, "Rename")
          .dismissKeyboardIfNeeded()
        ReplaceText(ResourceTestData.testResource.password, in: edit.passwordField, "Edit password")
          .dismissKeyboardIfNeeded()
        Tap(edit.saveButton, "Save")
      }
      // Reaching the list with the new name proves the edit was applied and no confirmation interposed.
      WaitFor(
        application.staticTexts[updatedName],
        timeout: .longNetworkCall,
        "The edited resource is listed under its new name"
      )
      Verify(
        application.buttons["permissions.confirm.button"].exists == false,
        "A private resource has no recipients to confirm"
      )
    }
  }

  /// Editing the secret of a shared resource re-encrypts it for every recipient, so the confirmation is shown
  /// and lists the recipients the secret would be encrypted for.
  func test_secretEditOfSharedResourceShowsConfirmation() async throws {
    let resourceName: ResourceName = "ConfirmSecretEdit".withDateSuffix().withRandomSuffix()

    await executeSteps {
      ShareResourceWithGroup(resourceName: resourceName, groupName: "Only Betty Group")
      OpenResourceDetailsActionMenu(resourceName: resourceName)
      On(ResourceDetailsActionMenuScreen.self) { menu in
        Tap(menu.editButton, "Edit")
      }
      On(ResourceEditScreen.self) { edit in
        ReplaceText(ResourceTestData.testResource.password, in: edit.passwordField, "Edit password")
          .dismissKeyboardIfNeeded()
        Tap(edit.saveButton, "Save")
      }
      On(ConfirmPermissionsScreen.self) { confirm in
        WaitFor(confirm.confirmButton, timeout: .longNetworkCall, "Confirmation is required for a secret edit")
        // An edit reaches the screen as a checkpoint, so it keeps the confirmation title.
        WaitFor(confirm.confirmTitle, timeout: .networkCall, "Editing is titled as a confirmation")
        WaitFor(
          confirm.recipientRow("Only Betty Group"),
          timeout: .longNetworkCall,
          "The recipient the secret would be re-encrypted for is listed"
        )
        Tap(confirm.cancelButton, "Back out of confirmation")
      }
    }
  }

  /// The operator may change their own row while editing - handing a resource over is legitimate - but not leave
  /// themselves without ownership. The list is validated on its end state, so the block lands on Confirm.
  func test_removingOwnOwnershipBlocksConfirmation() async throws {
    let resourceName: ResourceName = "ConfirmOwnRow".withDateSuffix().withRandomSuffix()
    let account: MockAccount = .automation

    await executeSteps {
      ShareResourceWithGroup(resourceName: resourceName, groupName: "Only Betty Group")
      OpenResourceDetailsActionMenu(resourceName: resourceName)
      On(ResourceDetailsActionMenuScreen.self) { menu in
        Tap(menu.editButton, "Edit")
      }
      On(ResourceEditScreen.self) { edit in
        ReplaceText(ResourceTestData.testResource.password, in: edit.passwordField, "Edit password")
          .dismissKeyboardIfNeeded()
        Tap(edit.saveButton, "Save")
      }
      On(ConfirmPermissionsScreen.self) { confirm in
        WaitFor(confirm.confirmButton, timeout: .longNetworkCall, "Confirmation is required for a secret edit")
        // The own row is editable while editing - the extension behaves the same way.
        Tap(confirm.recipientRow(account.username), "Open the operator's own permission")
      }
      On(ConfirmPermissionDetailsScreen.self) { details in
        WaitFor(details.removeButton, timeout: .networkCall, "The operator may remove their own permission")
        Tap(details.removeButton, "Remove own permission")
      }
      On(ConfirmPermissionsScreen.self) { confirm in
        WaitFor(
          confirm.ownershipWarning,
          timeout: .networkCall,
          "Leaving no ownership behind is refused"
        )
        Tap(confirm.confirmButton, "Confirm is blocked")
        // Still on the confirmation: a blocked confirm applies nothing and goes nowhere.
        WaitFor(confirm.ownershipWarning, timeout: .standardUI, "The confirmation did not proceed")
      }
    }
  }

  /// Backing out of the confirmation leaves the secret untouched - the edit is not applied.
  func test_backingOutOfConfirmationDoesNotApplyTheEdit() async throws {
    let resourceName: ResourceName = "ConfirmSecretCancel".withDateSuffix().withRandomSuffix()
    let updatedName: String = "ConfirmSecretCancelled".withDateSuffix().withRandomSuffix()
    let application: XCUIApplication = await self.application

    await executeSteps {
      ShareResourceWithGroup(resourceName: resourceName, groupName: "Only Betty Group")
      OpenResourceDetailsActionMenu(resourceName: resourceName)
      On(ResourceDetailsActionMenuScreen.self) { menu in
        Tap(menu.editButton, "Edit")
      }
      On(ResourceEditScreen.self) { edit in
        ReplaceText(updatedName, in: edit.nameField, "Rename")
          .dismissKeyboardIfNeeded()
        ReplaceText(ResourceTestData.testResource.password, in: edit.passwordField, "Edit password")
          .dismissKeyboardIfNeeded()
        Tap(edit.saveButton, "Save")
      }
      On(ConfirmPermissionsScreen.self) { confirm in
        WaitFor(confirm.confirmButton, timeout: .longNetworkCall, "Confirmation is required for a secret edit")
        Tap(confirm.cancelButton, "Back out of confirmation")
      }
      // the form is left as it was, so nothing reached the server under the new name
      On(ResourceEditScreen.self) { edit in
        WaitFor(edit.saveButton, timeout: .networkCall, "Back on the edit form")
      }
      Verify(
        application.staticTexts[updatedName].exists == false,
        "A cancelled confirmation must not apply the edit"
      )
    }
  }

  /// A recipient added and dropped again within the same review is applied as nothing at all - the list is
  /// confirmed as an end state, not replayed as the sequence of edits that produced it.
  func test_addingAndRemovingARecipientInOneSessionAppliesNothing() async throws {
    let resourceName: ResourceName = "ConfirmAddUndo".withDateSuffix().withRandomSuffix()
    let application: XCUIApplication = await self.application

    await executeSteps {
      SelectAllItemsFilter()
      CreateResource(resourceName: resourceName)
      VerifySnackBarMessage(expectedMessage: "New password has been created")
      OpenResourceDetails(resourceName: resourceName)
      On(ResourceDetailsScreen.self) { details in
        ScrollUntilVisible(details.permissionsContent, "Permissions section")
        Tap(details.permissionsContent, "Open permissions")
      }
      On(PermissionsListScreen.self) { permissions in
        Tap(permissions.editButton, "Edit permissions")
      }
      On(ConfirmPermissionsScreen.self, timeout: .longNetworkCall) { confirm in
        AddPermissionForGroup(groupName: "Only Betty Group")
        RemovePermissionForGroup(groupName: "Only Betty Group")
        Tap(confirm.confirmButton, "Confirm the recipients as they were")
      }
      On(PermissionsListScreen.self, timeout: .longNetworkCall) { permissions in
        VerifyPermissionCellCount(collectionView: permissions.collectionView, expectedCount: 1)
      }
      Verify(
        application.staticTexts["Only Betty Group"].exists == false,
        "A recipient dropped before confirming was never granted anything"
      )
    }
  }

  /// The ownership block is on the end state, not on the act of touching the own row: putting the ownership back
  /// - by any route - has to release it and let the edit through, or handing a resource over would be a one-way
  /// door the operator could not back out of.
  func test_restoringOwnershipReleasesTheConfirmation() async throws {
    let resourceName: ResourceName = "ConfirmOwnRestore".withDateSuffix().withRandomSuffix()
    let updatedName: String = "ConfirmOwnRestored".withDateSuffix().withRandomSuffix()
    let account: MockAccount = .automation
    let application: XCUIApplication = await self.application

    await executeSteps {
      ShareResourceWithGroup(resourceName: resourceName, groupName: "Only Betty Group")
      OpenResourceDetailsActionMenu(resourceName: resourceName)
      On(ResourceDetailsActionMenuScreen.self) { menu in
        Tap(menu.editButton, "Edit")
      }
      On(ResourceEditScreen.self) { edit in
        ReplaceText(updatedName, in: edit.nameField, "Rename")
          .dismissKeyboardIfNeeded()
        ReplaceText(ResourceTestData.testResource.password, in: edit.passwordField, "Edit password")
          .dismissKeyboardIfNeeded()
        Tap(edit.saveButton, "Save")
      }
      On(ConfirmPermissionsScreen.self) { confirm in
        WaitFor(confirm.confirmButton, timeout: .longNetworkCall, "Confirmation is required for a secret edit")
        Tap(confirm.recipientRow(account.username), "Open the operator's own permission")
      }
      // Downgrading the only ownership the operator holds is what the block exists for.
      On(ConfirmPermissionDetailsScreen.self) { details in
        Tap(details.level("read"), "Downgrade own permission to read")
        Tap(details.applyButton, "Apply the downgrade")
      }
      On(ConfirmPermissionsScreen.self) { confirm in
        WaitFor(confirm.ownershipWarning, timeout: .networkCall, "Losing ownership is refused")
        Tap(confirm.recipientRow(account.username), "Reopen the operator's own permission")
      }
      On(ConfirmPermissionDetailsScreen.self) { details in
        Tap(details.level("owner"), "Restore ownership")
        Tap(details.applyButton, "Apply the restored level")
      }
      On(ConfirmPermissionsScreen.self) { confirm in
        WaitForDisappearance(confirm.ownershipWarning, timeout: .networkCall, "The block is released")
        Tap(confirm.confirmButton, "Confirm the recipients")
      }
      // Reaching the list under the new name proves the confirmation went through and the edit was applied.
      WaitFor(
        application.staticTexts[updatedName],
        timeout: .slowNetworkCall,
        "The edit is applied once ownership is back"
      )
    }
  }
}

/// Creates a resource, shares it with a group through the confirmation screen and returns to the resources list.
internal struct ShareResourceWithGroup: CombinedUITestStep {

  internal var name: String { "Share \(self.resourceName) with \(self.groupName)" }

  private let resourceName: ResourceName
  private let groupName: String

  internal init(
    resourceName: ResourceName,
    groupName: String
  ) {
    self.resourceName = resourceName
    self.groupName = groupName
  }

  @UITestStepsBuilder
  @MainActor
  internal var steps: Array<UITestStep> {
    SelectAllItemsFilter()
    CreateResource(resourceName: self.resourceName)
    VerifySnackBarMessage(expectedMessage: "New password has been created")
    OpenResourceDetails(resourceName: self.resourceName)
    On(ResourceDetailsScreen.self) { details in
      ScrollUntilVisible(details.permissionsContent, "Permissions section")
      Tap(details.permissionsContent, "Open permissions")
    }
    On(PermissionsListScreen.self) { permissions in
      Tap(permissions.editButton, "Edit permissions")
    }
    // Sharing is composed and confirmed on the same screen - it can never be skipped.
    On(ConfirmPermissionsScreen.self, timeout: .longNetworkCall) { confirm in
      AddPermissionForGroup(groupName: self.groupName)
      Tap(confirm.confirmButton, "Confirm the recipients")
    }
    On(PermissionsListScreen.self, timeout: .longNetworkCall) { permissions in
      WaitFor(
        permissions.collectionView.staticTexts[self.groupName],
        timeout: .longNetworkCall,
        "Resource is shared with the group"
      )
      Tap(permissions.backButton, "Back to resource details")
    }
    On(ResourceDetailsScreen.self) { details in
      Tap(details.backButton, "Back to resources list")
    }
  }
}
