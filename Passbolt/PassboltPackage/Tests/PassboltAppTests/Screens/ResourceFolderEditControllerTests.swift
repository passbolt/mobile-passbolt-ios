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

import Display
import FeatureScopes
import Resources
import TestExtensions
import Users

@testable import Commons
@testable import PassboltApp

// swift-format-ignore: AlwaysUseLowerCamelCase, NeverUseImplicitlyUnwrappedOptionals, NeverForceUnwrap
final class ResourceFolderEditControllerTests: FeaturesTestCase {

  override func commonPrepare() {
    super.commonPrepare()
    set(
      SessionScope.self,
      context: .init(
        account: .mock_ada,
        configuration: .mock_1
      )
    )
    set(
      ResourceFolderEditScope.self,
      context: .init(
        editedResourceFolder: .init(
          id: .none,
          name: "",
          path: [],
          permission: .owner,
          permissions: []
        )
      )
    )
  }

  func test_setFolderName_setsNameInForm() async throws {
    patch(
      \ResourceFolderEditForm.setFolderName,
      with: {
        self.mockExecuted()
        return .valid($0)
      }
    )

    await withInstance(mockExecuted: 1) { (tested: ResourceFolderEditController) in
      tested.setFolderName("folder name")
    }
  }

  func test_saveChanges_sendsForm() async throws {
    let formState: Variable<ResourceFolder> = Variable(
      initial: ResourceFolder(
        id: .none,
        name: "",
        path: [],
        permission: .owner,
        permissions: []
      )
    )

    patch(
      \ResourceFolderEditForm.state,
      with: formState.asAnyUpdatable()
    )

    patch(
      \ResourceFolderEditForm.sendForm,
      with: always(self.mockExecuted())
    )

    await withInstance(mockExecuted: 1) { (tested: ResourceFolderEditController) in
      await tested.saveChanges()
    }
  }

  func test_saveChanges_presentsSuccessMessage() async throws {
    let newFolderName = "New Folder"
    let formState: Variable<ResourceFolder> = Variable(
      initial: ResourceFolder(
        id: .none,
        name: newFolderName,
        path: [],
        permission: .owner,
        permissions: []
      )
    )

    patch(
      \ResourceFolderEditForm.sendForm,
      with: always(self.mockExecuted())
    )

    patch(
      \ResourceFolderEditForm.state,
      with: formState.asAnyUpdatable()
    )

    let messagesSubscription = SnackBarMessageEvent.subscribe()
    let expectedMessage = SnackBarMessageEvent.Payload.show(
      .info(
        .localized(
          key: "folder.edit.form.created",
          arguments: [
            newFolderName
          ]
        )
      )
    )

    await withInstance(
      returns: expectedMessage
    ) { (tested: ResourceFolderEditController) in
      await tested.saveChanges()
      return try await messagesSubscription.nextEvent()
    }
  }

  func test_saveChanges_presentsError_whenSendingFormThrows() async throws {
    patch(
      \ResourceFolderEditForm.sendForm,
      with: alwaysThrow(MockIssue.error())
    )
    let messagesSubscription = SnackBarMessageEvent.subscribe()

    await withInstance(
      returns: SnackBarMessageEvent.Payload.show(.error(MockIssue.error())!)
    ) { (tested: ResourceFolderEditController) in
      await tested.saveChanges()
      return try await messagesSubscription.nextEvent()
    }
  }

  func test_viewState_updates_whenFormUpdates() async throws {
    let formState: Variable<ResourceFolder> = Variable(
      initial: ResourceFolder(
        id: .none,
        name: "",
        path: [],
        permission: .owner,
        permissions: []
      )
    )

    patch(
      \ResourceFolderEditForm.state,
      with: formState.asAnyUpdatable()
    )

    await withInstance(
      returns: Validated.valid("edited")
    ) { (tested: ResourceFolderEditController) in
      formState.assign("edited", to: \.name)
      return await tested.viewState.current.folderName
    }
  }
}
