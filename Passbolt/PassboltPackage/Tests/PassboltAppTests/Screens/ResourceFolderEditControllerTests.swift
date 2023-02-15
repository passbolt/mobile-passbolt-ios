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
import Resources
import TestExtensions
import Users

@testable import Commons
@testable import PassboltApp

// swift-format-ignore: AlwaysUseLowerCamelCase, NeverUseImplicitlyUnwrappedOptionals
final class ResourceFolderEditControllerTests: LoadableFeatureTestCase<ResourceFolderEditController> {

  override class var testedImplementationScope: any FeaturesScope.Type { SessionScope.self }

  override class func testedImplementationRegister(
    _ registry: inout FeaturesRegistry
  ) {
    registry.usePassboltResourceFolderEditController()
  }

  var executionMockControl: AsyncExecutor.MockExecutionControl!

  override func prepare() throws {
    set(
      SessionScope.self,
      context: .init(
        account: .mock_ada,
        configuration: .mock_1
      )
    )
    executionMockControl = .init()
    use(AsyncExecutor.mock(executionMockControl))
    use(DisplayNavigation.placeholder)
    use(Users.placeholder)
    use(
      ResourceFolderEditForm.placeholder,
      context: .create(containingFolderID: .none)
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

  override func cleanup() throws {
    executionMockControl = .none
  }

  func test_setFolderName_setsNameInForm() {
    patch(
      \ResourceFolderEditForm.setFolderName,
      context: .create(containingFolderID: .none),
      with: always(self.executed())
    )
    withTestedInstanceExecuted(
      context: .create(containingFolderID: .none),
      test: { (tested: ResourceFolderEditController) in
        tested.setFolderName("folder name")
        await self.executionMockControl.executeAll()
      }
    )
  }

  func test_saveChanges_sendsForm() {
    patch(
      \ResourceFolderEditForm.sendForm,
      context: .create(containingFolderID: .none),
      with: always(self.executed())
    )
    withTestedInstanceExecuted(
      context: .create(containingFolderID: .none),
      test: { (tested: ResourceFolderEditController) in
        tested.saveChanges()
        await self.executionMockControl.executeAll()
      }
    )
  }

  func test_saveChanges_presentsError_whenSendingFormThrows() {
    patch(
      \ResourceFolderEditForm.sendForm,
      context: .create(containingFolderID: .none),
      with: alwaysThrow(MockIssue.error())
    )
    withTestedInstanceReturnsEqual(
      SnackBarMessage.error(MockIssue.error()),
      context: .create(containingFolderID: .none),
      test: { (tested: ResourceFolderEditController) in
        tested.saveChanges()
        await self.executionMockControl.executeAll()
        return await tested.viewState.value.snackBarMessage
      }
    )
  }

  func test_viewState_updates_whenFormUpdates() {
    let updatesSource: UpdatesSequenceSource = .init()
    patch(
      \ResourceFolderEditForm.formUpdates,
      context: .create(containingFolderID: .none),
      with: updatesSource.updatesSequence
    )
    self.formState = ResourceFolderEditFormState(
      name: .valid("initial"),
      location: .valid(.init()),
      permissions: .valid(.init())
    )
    patch(
      \ResourceFolderEditForm.formState,
      context: .create(containingFolderID: .none),
      with: always(self.formState)
    )

    withTestedInstance(
      context: .create(containingFolderID: .none),
      test: { (tested: ResourceFolderEditController) in
        Task { await self.executionMockControl.executeAll() }

        // wait for detached task to execute
        try await Task.sleep(nanoseconds: NSEC_PER_MSEC)
        let initialFolderName: Validated<String> = await tested.viewState.value.folderName

        self.formState = ResourceFolderEditFormState(
          name: .valid("edited"),
          location: .valid(.init()),
          permissions: .valid(.init())
        )
        updatesSource.sendUpdate()

        // wait for detached task to execute
        try await Task.sleep(nanoseconds: NSEC_PER_MSEC)

        let updatedFolderName: Validated<String> = await tested.viewState.value.folderName

        updatesSource.endUpdates()

        XCTAssertNotEqual(
          initialFolderName,
          updatedFolderName
        )
      }
    )
  }
}
