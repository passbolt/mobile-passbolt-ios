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

/// E2EE Permission Confirmation (MOB-4731). Editing the secret of a shared resource routes through the
/// "Confirm permissions" checkpoint before the secret is re-encrypted for its recipients.
///
/// Sharing itself is unaffected: the explicit share flow keeps using the dedicated share screen, which
/// `ShareResourceTests` covers. The confirmation is a checkpoint on create and edit only.
///
/// NOTE: these flows rely on the server endpoints introduced for this feature (`filter[has-id]` on users/groups,
/// single-item fetch with `contain[permissions]`). They require an automation backend that provides them.
@MainActor
final internal class PermissionConfirmationTests: UITestCase {

  /// Sharing goes through the legacy share screen - the confirmation checkpoint must not interpose there.
  func test_shareDoesNotRouteThroughConfirmationScreen() async throws {
    let resourceName: ResourceName = "ConfirmNoShare".withDateSuffix().withRandomSuffix()
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
      // the dedicated share screen opens directly, with no confirmation in between
      On(PermissionsEditScreen.self) { edit in
        WaitFor(edit.addUsersButton, timeout: .longNetworkCall, "Share screen is shown")
        Verify(
          application.buttons["permissions.confirm.button"].exists == false,
          "Confirmation screen is not shown for an explicit share"
        )
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
        WaitFor(
          confirm.recipientRow("Only Betty Group"),
          timeout: .longNetworkCall,
          "The recipient the secret would be re-encrypted for is listed"
        )
        Tap(confirm.cancelButton, "Back out of confirmation")
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
}

/// Creates a resource, shares it with a group through the dedicated share screen and returns to the resources list.
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
    On(PermissionsEditScreen.self) { edit in
      Tap(edit.addUsersButton, "Add users")
      AddPermissionForGroup(groupName: self.groupName)
      Tap(edit.applyButton, "Apply changes")
    }
    On(PermissionsListScreen.self) { permissions in
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
