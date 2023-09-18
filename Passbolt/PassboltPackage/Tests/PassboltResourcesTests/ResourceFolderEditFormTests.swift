////
//// Passbolt - Open source password manager for teams
//// Copyright (c) 2021 Passbolt SA
////
//// This program is free software: you can redistribute it and/or modify it under the terms of the GNU Affero General
//// Public License (AGPL) as published by the Free Software Foundation version 3.
////
//// The name "Passbolt" is a registered trademark of Passbolt SA, and Passbolt SA hereby declines to grant a trademark
//// license to "Passbolt" pursuant to the GNU Affero General Public License version 3 Section 7(e), without a separate
//// agreement with Passbolt SA.
////
//// This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied
//// warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See GNU Affero General Public License for more details.
////
//// You should have received a copy of the GNU Affero General Public License along with this program. If not,
//// see GNU Affero General Public License v3 (http://www.gnu.org/licenses/agpl-3.0.html).
////
//// @copyright     Copyright (c) Passbolt SA (https://www.passbolt.com)
//// @license       https://opensource.org/licenses/AGPL-3.0 AGPL License
//// @link          https://www.passbolt.com Passbolt (tm)
//// @since         v1.0
////
//
//import SessionData
//import TestExtensions
//
//@testable import PassboltResources
//
//// swift-format-ignore: AlwaysUseLowerCamelCase, NeverUseImplicitlyUnwrappedOptionals
//final class ResourceFolderEditFormTests: LoadableFeatureTestCase<ResourceFolderEditForm> {
//
//  override class var testedImplementationScope: any FeaturesScope.Type { ResourceFolderEditScope.self }
//
//  override class func testedImplementationRegister(
//    _ registry: inout FeaturesRegistry
//  ) {
//    registry.usePassboltResourceFolderEditForm()
//  }
//
//  override func prepare() throws {
//    set(
//      SessionScope.self,
//      context: .init(
//        account: .mock_ada,
//        configuration: .mock_1
//      )
//    )
//    set(
//      ResourceFolderEditScope.self,
//      context: .mock_1
//    )
//
//    set(ResourceFolderEditScope.self, context: .mock_1)
//    set(SessionScope.self, context: .init(account: .mock_ada, configuration: .mock_1))
//    patch(
//      \Session.currentAccount,
//      with: always(.mock_ada)
//    )
//    use(SessionData.placeholder)
//    use(ResourceFolderCreateNetworkOperation.placeholder)
//    use(ResourceFolderShareNetworkOperation.placeholder)
//  }
//
//  func test_formState_isDefault_initiallyWhenCreatingInRoot() {
//    withTestedInstanceReturnsEqual(
//      ResourceFolderEditFormState(
//        name: .valid(""),
//        location: .valid(.init()),
//        permissions: .valid([
//          .user(
//            id: .mock_ada,
//            permission: .owner,
//            permissionID: .none
//          )
//        ])
//      ),
//      context: .create(containingFolderID: .none)
//    ) { (tested: ResourceFolderEditForm) in
//      await self.mockExecutionControl.executeAll()
//      return tested.formState()
//    }
//  }
//
//  func test_formState_isDefault_initiallyWhenCreatingInFolder() {
//    let containingFolderID: ResourceFolder.ID = .mock_1
//    patch(
//      \ResourceFolderController.details,
//      context: containingFolderID,
//      with: always(
//        ResourceFolder(
//          id: containingFolderID,
//          name: "folder",
//					path: .init(),
//          shared: false,
//					permission: .owner,
//          permissions: [
//            .user(
//              id: .mock_ada,
//              permission: .owner,
//              permissionID: .mock_1
//            )
//          ]
//        )
//      )
//    )
//    withTestedInstanceReturnsEqual(
//      ResourceFolderEditFormState(
//        name: .valid(""),
//        location: .valid([
//          ResourceFolderLocationItem(
//            folderID: containingFolderID,
//            folderName: "folder"
//          )
//        ]),
//        permissions: .valid([
//          .user(
//            id: .mock_ada,
//            permission: .owner,
//            permissionID: .none
//          )
//        ])
//      ),
//      context: .create(containingFolderID: containingFolderID)
//    ) { (tested: ResourceFolderEditForm) in
//      await self.mockExecutionControl.executeAll()
//      return tested.formState()
//    }
//  }
//
//  func test_formState_isDefault_initiallyWhenCreatingInSharedFolder() {
//    let containingFolderID: ResourceFolder.ID = .mock_1
//    patch(
//      \ResourceFolderController.details,
//      context: containingFolderID,
//      with: always(
//        ResourceFolder(
//          id: containingFolderID,
//          name: "folder",
//					path: .init(),
//          shared: true,
//					permission: .owner,
//          permissions: [
//            .user(
//              id: .mock_ada,
//              permission: .owner,
//              permissionID: .mock_1
//            ),
//            .user(
//              id: .mock_frances,
//              permission: .read,
//              permissionID: .mock_2
//            ),
//          ]
//        )
//      )
//    )
//    withTestedInstanceReturnsEqual(
//      ResourceFolderEditFormState(
//        name: .valid(""),
//        location: .valid([
//          ResourceFolderLocationItem(
//            folderID: containingFolderID,
//            folderName: "folder"
//          )
//        ]),
//        permissions: .valid([
//          .user(
//            id: .mock_ada,
//            permission: .owner,
//            permissionID: .none
//          ),
//          .user(
//            id: .mock_frances,
//            permission: .read,
//            permissionID: .none
//          ),
//        ])
//      ),
//      context: .create(containingFolderID: containingFolderID)
//    ) { (tested: ResourceFolderEditForm) in
//      await self.mockExecutionControl.executeAll()
//      return tested.formState()
//    }
//  }
//
//  func test_formState_isDefault_initiallyWhenCreatingInSharedFolderWithLowerExplicitPermission() {
//    let containingFolderID: ResourceFolder.ID = .mock_1
//    patch(
//      \ResourceFolderController.details,
//      context: containingFolderID,
//      with: always(
//        ResourceFolder(
//          id: containingFolderID,
//          name: "folder",
//					path: .init(),
//          shared: true,
//					permission: .owner,
//          permissions: [
//            .user(
//              id: .mock_ada,
//              permission: .write,
//              permissionID: .mock_1
//            ),
//            .user(
//              id: .mock_frances,
//              permission: .read,
//              permissionID: .mock_2
//            ),
//          ]
//        )
//      )
//    )
//    withTestedInstanceReturnsEqual(
//      ResourceFolderEditFormState(
//        name: .valid(""),
//        location: .valid([
//          ResourceFolderLocationItem(
//            folderID: containingFolderID,
//            folderName: "folder"
//          )
//        ]),
//        permissions: .valid([
//          .user(
//            id: .mock_ada,
//            permission: .write,
//            permissionID: .none
//          ),
//          .user(
//            id: .mock_frances,
//            permission: .read,
//            permissionID: .none
//          ),
//        ])
//      ),
//      context: .create(containingFolderID: containingFolderID)
//    ) { (tested: ResourceFolderEditForm) in
//      await self.mockExecutionControl.executeAll()
//      return tested.formState()
//    }
//  }
//
//  func test_formState_isDefault_initiallyWhenCreatingInSharedFolderWithoutExplicitPermission() {
//    let containingFolderID: ResourceFolder.ID = .mock_1
//    patch(
//      \ResourceFolderController.details,
//      context: containingFolderID,
//      with: always(
//        ResourceFolder(
//          id: containingFolderID,
//          name: "folder",
//					path: .init(),
//          shared: true,
//					permission: .owner,
//          permissions: [
//            .userGroup(
//              id: .mock_1,
//              permission: .owner,
//              permissionID: .mock_1
//            ),
//            .user(
//              id: .mock_frances,
//              permission: .read,
//              permissionID: .mock_2
//            ),
//          ]
//        )
//      )
//    )
//    withTestedInstanceReturnsEqual(
//      ResourceFolderEditFormState(
//        name: .valid(""),
//        location: .valid([
//          ResourceFolderLocationItem(
//            folderID: containingFolderID,
//            folderName: "folder"
//          )
//        ]),
//        permissions: .valid([
//          .userGroup(
//            id: .mock_1,
//            permission: .owner,
//            permissionID: .none
//          ),
//          .user(
//            id: .mock_frances,
//            permission: .read,
//            permissionID: .none
//          ),
//        ])
//      ),
//      context: .create(containingFolderID: containingFolderID)
//    ) { (tested: ResourceFolderEditForm) in
//      await self.mockExecutionControl.executeAll()
//      return tested.formState()
//    }
//  }
//
//  func test_setFolderName_updatesFormState() {
//    withTestedInstanceReturnsEqual(
//      "updated",
//      context: .create(containingFolderID: .none)
//    ) { (tested: ResourceFolderEditForm) in
//      tested.setFolderName("updated")
//      return tested.formState().name.value
//    }
//  }
//
//  func test_setFolderName_makesValidValueIfValidationPasses() {
//    withTestedInstanceReturnsEqual(
//      Validated<String>.valid("valid"),
//      context: .create(containingFolderID: .none)
//    ) { (tested: ResourceFolderEditForm) in
//      tested.setFolderName("valid")
//      return tested.formState().name
//    }
//  }
//
//  func test_setFolderName_makesInvalidValueIfEmpty() {
//    withTestedInstanceReturnsEqual(
//      Validated<String>
//        .invalid(
//          "",
//          error: InvalidValue.empty(
//            value: "",
//            displayable: .localized(
//              key: "error.validation.folder.name.empty"
//            )
//          )
//        ),
//      context: .create(containingFolderID: .none)
//    ) { (tested: ResourceFolderEditForm) in
//      tested.setFolderName("")
//      return tested.formState().name
//    }
//  }
//
//  func test_setFolderName_makesInvalidValueIfTooLong() {
//    let name: String = .init(repeating: "a", count: 257)
//    withTestedInstanceReturnsEqual(
//      Validated<String>
//        .invalid(
//          name,
//          error: InvalidValue.tooLong(
//            value: "",
//            displayable: .localized(
//              key: "error.validation.folder.name.too.long"
//            )
//          )
//        ),
//      context: .create(containingFolderID: .none)
//    ) { (tested: ResourceFolderEditForm) in
//      tested.setFolderName(name)
//      return try await tested.formState().name
//    }
//  }
//
//  func test_sendForm_throws_whenFormIsInvalid() {
//    withTestedInstanceThrows(
//      InvalidForm.self,
//      context: .create(containingFolderID: .none)
//    ) { (tested: ResourceFolderEditForm) in
//      try await tested.sendForm()
//    }
//  }
//
//  func test_sendForm_throws_whenCreateRequestThrows() {
//    patch(
//      \ResourceFolderCreateNetworkOperation.execute,
//      with: alwaysThrow(MockIssue.error())
//    )
//    withTestedInstanceThrows(
//      MockIssue.self,
//      context: .create(containingFolderID: .none)
//    ) { (tested: ResourceFolderEditForm) in
//      await self.mockExecutionControl.executeAll()
//      tested.setFolderName("valid")
//      return try await tested.sendForm()
//    }
//  }
//
//  func test_sendForm_throws_whenSessionDataRefreshThrows() {
//    patch(
//      \ResourceFolderCreateNetworkOperation.execute,
//      with: always(.init(resourceFolderID: .mock_1, ownerPermissionID: .mock_1))
//    )
//    patch(
//      \SessionData.refreshIfNeeded,
//      with: alwaysThrow(MockIssue.error())
//    )
//    withTestedInstanceThrows(
//      MockIssue.self,
//      context: .create(containingFolderID: .none)
//    ) { (tested: ResourceFolderEditForm) in
//      await self.mockExecutionControl.executeAll()
//      tested.setFolderName("valid")
//      try await tested.sendForm()
//    }
//  }
//
//  func test_sendForm_throws_whenShareRequestThrowsForSharedFolder() {
//    let containingFolderID: ResourceFolder.ID = .mock_1
//    patch(
//      \ResourceFolderController.details,
//      context: containingFolderID,
//      with: always(
//        ResourceFolder(
//          id: containingFolderID,
//          name: "folder",
//					path: .init(),
//          shared: true,
//					permission: .owner,
//          permissions: [
//            .user(
//              id: .mock_ada,
//              permission: .owner,
//              permissionID: .mock_1
//            ),
//            .user(
//              id: .mock_frances,
//              permission: .read,
//              permissionID: .mock_2
//            ),
//          ]
//        )
//      )
//    )
//    patch(
//      \ResourceFolderCreateNetworkOperation.execute,
//      with: always(.init(resourceFolderID: .mock_1, ownerPermissionID: .mock_1))
//    )
//    patch(
//      \ResourceFolderShareNetworkOperation.execute,
//      with: alwaysThrow(MockIssue.error())
//    )
//    withTestedInstanceThrows(
//      MockIssue.self,
//      context: .create(containingFolderID: containingFolderID)
//    ) { (tested: ResourceFolderEditForm) in
//      await self.mockExecutionControl.executeAll()
//      tested.setFolderName("valid")
//      try await tested.sendForm()
//    }
//  }
//}
