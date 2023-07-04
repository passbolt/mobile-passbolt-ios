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

// swift-format-ignore: AlwaysUseLowerCamelCase, NeverUseImplicitlyUnwrappedOptionals
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
    patch(
      \ResourceFolderEditForm.formState,
      context: .create(containingFolderID: .none),
      with: always(
        .init(
          name: .valid("name"),
          location: .valid(.init()),
          permissions: .valid(.init())
        )
      )
    )
  }

  func test_setFolderName_setsNameInForm() async throws {
    patch(
      \ResourceFolderEditForm.setFolderName,
      context: .create(containingFolderID: .none),
      with: always(self.dynamicVariables.set(\.executed, to: true))
    )

    let tested: ResourceFolderEditController = try self.testedInstance(context: .create(containingFolderID: .none))

    tested.setFolderName("folder name")
    await self.asyncExecutionControl.executeAll()
    XCTAssertTrue(self.dynamicVariables.get(\.executed, of: Bool.self))
  }

  func test_saveChanges_sendsForm() async throws {
    patch(
      \ResourceFolderEditForm.sendForm,
      context: .create(containingFolderID: .none),
      with: always(self.dynamicVariables.set(\.executed, to: true))
    )

    let tested: ResourceFolderEditController = try self.testedInstance(context: .create(containingFolderID: .none))

    tested.saveChanges()
    await self.asyncExecutionControl.executeAll()
  }

  func test_saveChanges_presentsError_whenSendingFormThrows() async throws {
    patch(
      \ResourceFolderEditForm.sendForm,
      context: .create(containingFolderID: .none),
      with: alwaysThrow(MockIssue.error())
    )

    let tested: ResourceFolderEditController = try self.testedInstance(context: .create(containingFolderID: .none))

    tested.saveChanges()
    await self.asyncExecutionControl.executeAll()

    await XCTAssertValue(
      equal: SnackBarMessage.error(MockIssue.error())
    ) {
      await tested.viewState.current.snackBarMessage
    }
  }

  func test_viewState_updates_whenFormUpdates() async throws {
    let updatesSource: UpdatesSource = .init()
    patch(
      \ResourceFolderEditForm.updates,
      context: .create(containingFolderID: .none),
      with: updatesSource.updates
    )
    self.dynamicVariables.formState = ResourceFolderEditFormState(
      name: .valid("initial"),
      location: .valid(.init()),
      permissions: .valid(.init())
    )
    patch(
      \ResourceFolderEditForm.formState,
      context: .create(containingFolderID: .none),
      with: always(self.dynamicVariables.formState)
    )

    let tested: ResourceFolderEditController = try self.testedInstance(context: .create(containingFolderID: .none))

    await self.asyncExecutionControl.executeNext()
    let initialFolderName: Validated<String> = await tested.viewState.current.folderName

    self.dynamicVariables.formState = ResourceFolderEditFormState(
      name: .valid("edited"),
      location: .valid(.init()),
      permissions: .valid(.init())
    )
    updatesSource.sendUpdate()
    await self.asyncExecutionControl.executeNext()

    let updatedFolderName: Validated<String> = await tested.viewState.current.folderName

    XCTAssertNotEqual(
      initialFolderName,
      updatedFolderName
    )

    updatesSource.terminate()
    await self.asyncExecutionControl.executeAll()
  }
}
