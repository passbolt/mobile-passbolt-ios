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

import TestExtensions

@testable import PassboltResources

// swift-format-ignore: AlwaysUseLowerCamelCase, NeverUseImplicitlyUnwrappedOptionals
final class ResourceFolderEditFormTests: LoadableFeatureTestCase<ResourceFolderEditForm> {

  override class var testedImplementationRegister: (FeatureFactory) -> @MainActor () -> Void {
    FeatureFactory.usePassboltResourceFolderEditForm
  }

  override func prepare() throws {
    patch(
      \Session.currentAccount,
      with: always(.mock_ada)
    )
    use(SessionData.placeholder)
    use(ResourceFolderCreateNetworkOperation.placeholder)
    use(ResourceFolderShareNetworkOperation.placeholder)
  }

  func test_formState_isDefault_initiallyWhenCreatingInRoot() {
    withTestedInstanceReturnsEqual(
      ResourceFolderEditFormState(
        name: .valid(""),
        location: .valid(.init()),
        permissions: .valid([
          .user(
            id: .mock_ada,
            type: .owner,
            permissionID: .none
          )
        ])
      ),
      context: .create(containingFolderID: .none)
    ) { (tested: ResourceFolderEditForm) in
      try await tested.formState.value
    }
  }

  func test_formState_isDefault_initiallyWhenCreatingInFolder() {
    let containingFolderID: ResourceFolder.ID = .mock_1
    patch(
      \ResourceFolderDetails.details,
      context: containingFolderID,
      with: .always(
        ResourceFolderDetailsDSV(
          id: containingFolderID,
          name: "folder",
          permissionType: .owner,
          shared: false,
          parentFolderID: .none,
          location: .init(),
          permissions: [
            .user(
              id: .mock_ada,
              type: .owner,
              permissionID: .mock_1
            )
          ]
        )
      )
    )
    withTestedInstanceReturnsEqual(
      ResourceFolderEditFormState(
        name: .valid(""),
        location: .valid([
          ResourceFolderLocationItem(
            folderID: containingFolderID,
            folderName: "folder"
          )
        ]),
        permissions: .valid([
          .user(
            id: .mock_ada,
            type: .owner,
            permissionID: .none
          )
        ])
      ),
      context: .create(containingFolderID: containingFolderID)
    ) { (tested: ResourceFolderEditForm) in
      try await tested.formState.value
    }
  }

  func test_formState_isDefault_initiallyWhenCreatingInSharedFolder() {
    let containingFolderID: ResourceFolder.ID = .mock_1
    patch(
      \ResourceFolderDetails.details,
      context: containingFolderID,
      with: .always(
        ResourceFolderDetailsDSV(
          id: containingFolderID,
          name: "folder",
          permissionType: .owner,
          shared: true,
          parentFolderID: .none,
          location: .init(),
          permissions: [
            .user(
              id: .mock_ada,
              type: .owner,
              permissionID: .mock_1
            ),
            .user(
              id: .mock_frances,
              type: .read,
              permissionID: .mock_2
            ),
          ]
        )
      )
    )
    withTestedInstanceReturnsEqual(
      ResourceFolderEditFormState(
        name: .valid(""),
        location: .valid([
          ResourceFolderLocationItem(
            folderID: containingFolderID,
            folderName: "folder"
          )
        ]),
        permissions: .valid([
          .user(
            id: .mock_ada,
            type: .owner,
            permissionID: .none
          ),
          .user(
            id: .mock_frances,
            type: .read,
            permissionID: .none
          ),
        ])
      ),
      context: .create(containingFolderID: containingFolderID)
    ) { (tested: ResourceFolderEditForm) in
      try await tested.formState.value
    }
  }

  func test_formState_isDefault_initiallyWhenCreatingInSharedFolderWithLowerExplicitPermission() {
    let containingFolderID: ResourceFolder.ID = .mock_1
    patch(
      \ResourceFolderDetails.details,
      context: containingFolderID,
      with: .always(
        ResourceFolderDetailsDSV(
          id: containingFolderID,
          name: "folder",
          permissionType: .owner,
          shared: true,
          parentFolderID: .none,
          location: .init(),
          permissions: [
            .user(
              id: .mock_ada,
              type: .write,
              permissionID: .mock_1
            ),
            .user(
              id: .mock_frances,
              type: .read,
              permissionID: .mock_2
            ),
          ]
        )
      )
    )
    withTestedInstanceReturnsEqual(
      ResourceFolderEditFormState(
        name: .valid(""),
        location: .valid([
          ResourceFolderLocationItem(
            folderID: containingFolderID,
            folderName: "folder"
          )
        ]),
        permissions: .valid([
          .user(
            id: .mock_ada,
            type: .write,
            permissionID: .none
          ),
          .user(
            id: .mock_frances,
            type: .read,
            permissionID: .none
          ),
        ])
      ),
      context: .create(containingFolderID: containingFolderID)
    ) { (tested: ResourceFolderEditForm) in
      try await tested.formState.value
    }
  }

  func test_formState_isDefault_initiallyWhenCreatingInSharedFolderWithoutExplicitPermission() {
    let containingFolderID: ResourceFolder.ID = .mock_1
    patch(
      \ResourceFolderDetails.details,
      context: containingFolderID,
      with: .always(
        ResourceFolderDetailsDSV(
          id: containingFolderID,
          name: "folder",
          permissionType: .owner,
          shared: true,
          parentFolderID: .none,
          location: .init(),
          permissions: [
            .userGroup(
              id: .mock_1,
              type: .owner,
              permissionID: .mock_1
            ),
            .user(
              id: .mock_frances,
              type: .read,
              permissionID: .mock_2
            ),
          ]
        )
      )
    )
    withTestedInstanceReturnsEqual(
      ResourceFolderEditFormState(
        name: .valid(""),
        location: .valid([
          ResourceFolderLocationItem(
            folderID: containingFolderID,
            folderName: "folder"
          )
        ]),
        permissions: .valid([
          .userGroup(
            id: .mock_1,
            type: .owner,
            permissionID: .none
          ),
          .user(
            id: .mock_frances,
            type: .read,
            permissionID: .none
          ),
        ])
      ),
      context: .create(containingFolderID: containingFolderID)
    ) { (tested: ResourceFolderEditForm) in
      try await tested.formState.value
    }
  }

  func test_setFolderName_updatesFormState() {
    withTestedInstanceReturnsEqual(
      "updated",
      context: .create(containingFolderID: .none)
    ) { (tested: ResourceFolderEditForm) in
      tested.setFolderName("updated")
      return try await tested.formState.value.name.value
    }
  }

  func test_setFolderName_makesValidValueIfValidationPasses() {
    withTestedInstanceReturnsEqual(
      Validated<String>.valid("valid"),
      context: .create(containingFolderID: .none)
    ) { (tested: ResourceFolderEditForm) in
      tested.setFolderName("valid")
      return try await tested.formState.value.name
    }
  }

  func test_setFolderName_makesInvalidValueIfEmpty() {
    withTestedInstanceReturnsEqual(
      Validated<String>
        .invalid(
          "",
          errors: .empty(
            value: "",
            displayable: .localized(
              key: "error.validation.folder.name.empty"
            )
          )
        ),
      context: .create(containingFolderID: .none)
    ) { (tested: ResourceFolderEditForm) in
      tested.setFolderName("")
      return try await tested.formState.value.name
    }
  }

  func test_setFolderName_makesInvalidValueIfTooLong() {
    let name: String = .init(repeating: "a", count: 257)
    withTestedInstanceReturnsEqual(
      Validated<String>
        .invalid(
          name,
          errors: .tooLong(
            value: "",
            displayable: .localized(
              key: "error.validation.folder.name.too.long"
            )
          )
        ),
      context: .create(containingFolderID: .none)
    ) { (tested: ResourceFolderEditForm) in
      tested.setFolderName(name)
      return try await tested.formState.value.name
    }
  }

  func test_sendForm_throws_whenFormIsInvalid() {
    withTestedInstanceThrows(
      InvalidForm.self,
      context: .create(containingFolderID: .none)
    ) { (tested: ResourceFolderEditForm) in
      try await tested.sendForm()
    }
  }

  func test_sendForm_throws_whenCreateRequestThrows() {
    patch(
      \ResourceFolderCreateNetworkOperation.execute,
      with: alwaysThrow(MockIssue.error())
    )
    withTestedInstanceThrows(
      MockIssue.self,
      context: .create(containingFolderID: .none)
    ) { (tested: ResourceFolderEditForm) in
      tested.setFolderName("valid")
      try await tested.sendForm()
    }
  }

  func test_sendForm_throws_whenSessionDataRefreshThrows() {
    patch(
      \ResourceFolderCreateNetworkOperation.execute,
       with: always(.init(resourceFolderID: .mock_1, ownerPermissionID: .mock_1))
    )
    patch(
      \SessionData.refreshIfNeeded,
      with: alwaysThrow(MockIssue.error())
    )
    withTestedInstanceThrows(
      MockIssue.self,
      context: .create(containingFolderID: .none)
    ) { (tested: ResourceFolderEditForm) in
      tested.setFolderName("valid")
      try await tested.sendForm()
    }
  }

  func test_sendForm_throws_whenShareRequestThrowsForSharedFolder() {
    let containingFolderID: ResourceFolder.ID = .mock_1
    patch(
      \ResourceFolderDetails.details,
      context: containingFolderID,
      with: .always(
        ResourceFolderDetailsDSV(
          id: containingFolderID,
          name: "folder",
          permissionType: .owner,
          shared: true,
          parentFolderID: .none,
          location: .init(),
          permissions: [
            .user(
              id: .mock_ada,
              type: .owner,
              permissionID: .mock_1
            ),
            .user(
              id: .mock_frances,
              type: .read,
              permissionID: .mock_2
            ),
          ]
        )
      )
    )
    patch(
      \ResourceFolderCreateNetworkOperation.execute,
      with: always(.init(resourceFolderID: .mock_1, ownerPermissionID: .mock_1))
    )
    patch(
      \ResourceFolderShareNetworkOperation.execute,
      with: alwaysThrow(MockIssue.error())
    )
    withTestedInstanceThrows(
      MockIssue.self,
      context: .create(containingFolderID: containingFolderID)
    ) { (tested: ResourceFolderEditForm) in
      tested.setFolderName("valid")
      try await tested.sendForm()
    }
  }
}
