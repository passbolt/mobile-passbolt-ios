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
import NetworkOperations
import Resources
import Session
import SessionData

// MARK: - Implementation

extension ResourceFolderEditForm {

  @MainActor fileprivate static func load(
    features: Features
  ) throws -> Self {
    let currentAccount: Account = try features.sessionAccount()
    let editedResourceFolder: ResourceFolder = try features.resourceFolderEditingContext().editedResourceFolder

    let sessionData: SessionData = try features.instance()

    let resourceFolderCreateNetworkOperation: ResourceFolderCreateNetworkOperation = try features.instance()
    let resourceFolderShareNetworkOperation: ResourceFolderShareNetworkOperation = try features.instance()

    let state: Variable<ResourceFolder> = .init(
      initial: editedResourceFolder
    )

    @Sendable func setFolder(
      name: String
    ) -> Validated<String> {
      state.mutate { (folder: inout ResourceFolder) -> Validated<String> in
        folder.name = name
        return folder.nameValidator.validate(name)
      }
    }

    @Sendable func validateForm() throws {
      try state.value.validate()
    }

    @Sendable func sendForm() async throws {
      var editedResourceFolder: ResourceFolder = state.value
      try editedResourceFolder.validate()

      let newPermissions: OrderedSet<NewGenericPermissionDTO>
      let updatedPermissions: OrderedSet<GenericPermissionDTO>
      let deletedPermissions: OrderedSet<GenericPermissionDTO>

      if editedResourceFolder.isLocal {
        let createdFolderResult: ResourceFolderCreateNetworkOperationResult =
          try await resourceFolderCreateNetworkOperation
          .execute(
            .init(
              name: editedResourceFolder.name,
              parentFolderID: editedResourceFolder.parentFolderID
            )
          )
        editedResourceFolder.id = createdFolderResult.resourceFolderID

        newPermissions = editedResourceFolder.permissions
          .compactMap { (permission: ResourceFolderPermission) -> NewGenericPermissionDTO? in
            switch permission {
            case .user(let id, let permission, permissionID: .none):
              // current user permission is never new after creating
              guard id != currentAccount.userID else { return .none }
              return .userToFolder(
                userID: id,
                folderID: createdFolderResult.resourceFolderID,
                permission: permission
              )

            case .userGroup(let id, let permission, permissionID: .none):
              return .userGroupToFolder(
                userGroupID: id,
                folderID: createdFolderResult.resourceFolderID,
                permission: permission
              )

            case _:
              assertionFailure("New resource folder can't contain existing permissions!")
              return .none
            }
          }
          .asOrderedSet()
        // only current user permission could be updated
        // when creating new resource folder
        updatedPermissions =
          editedResourceFolder.permissions
          .first { $0.userID == currentAccount.userID && !$0.permission.isOwner }
          .map { (permission: ResourceFolderPermission) -> GenericPermissionDTO in
            .userToFolder(
              id: createdFolderResult.ownerPermissionID,
              userID: currentAccount.userID,
              folderID: createdFolderResult.resourceFolderID,
              permission: permission.permission  // use the updated value
            )
          }
          .map { [$0] }
          ?? .init()
        // only current user permission could be deleted
        // when creating new resource folder
        deletedPermissions =
          editedResourceFolder.permissions
            .contains { $0.userID == currentAccount.userID }
          ? []
          : [
            .userToFolder(
              id: createdFolderResult.ownerPermissionID,
              userID: currentAccount.userID,
              folderID: createdFolderResult.resourceFolderID,
              permission: .owner
            )
          ]
      }
      else {
        throw
          Unimplemented
          .error("Attempting to edit a resource folder which is not supported yet.")
      }

      guard let editedResourceFolderID: ResourceFolder.ID = editedResourceFolder.id
      else { throw InternalInconsistency.error("Recently edited resource folder has no ID!") }

      // if permissions have changed or created new in shared folder
      // then perform share
      if !newPermissions.isEmpty || !updatedPermissions.isEmpty || !deletedPermissions.isEmpty {
        try await resourceFolderShareNetworkOperation.execute(
          .init(
            resourceFolderID: editedResourceFolderID,
            body: .init(
              newPermissions: newPermissions,
              updatedPermissions: updatedPermissions,
              deletedPermissions: deletedPermissions
            )
          )
        )
      }  // else no permission changes required

      try await sessionData.refreshIfNeeded()
    }

    return .init(
      state: state.asAnyUpdatable(),
      setFolderName: setFolder(name:),
      validateForm: validateForm,
      sendForm: sendForm
    )
  }
}

extension FeaturesRegistry {

  internal mutating func usePassboltResourceFolderEditForm() {
    self.use(
      .lazyLoaded(
        ResourceFolderEditForm.self,
        load: ResourceFolderEditForm.load(features:)
      ),
      in: ResourceFolderEditScope.self
    )
  }
}
