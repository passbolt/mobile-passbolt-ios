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
import SessionData
import Users

// MARK: - Implementation

extension ResourceShareForm {

  fileprivate struct FormState: Hashable {

    fileprivate let resourceID: Resource.ID
    fileprivate var editedPermissions: OrderedSet<ResourcePermission>
    fileprivate var deletedPermissions: OrderedSet<ResourcePermission>
  }

  @MainActor fileprivate static func load(
    features: Features
  ) throws -> Self {
    let resourceID: Resource.ID = try features.resourceContext()

    let sessionData: SessionData = try features.instance()
    let resourceController: ResourceController = try features.instance()
    let usersPGPMessages: UsersPGPMessages = try features.instance()
    let userGroups: UserGroups = try features.instance()
    let resourceShareNetworkOperation: ResourceShareNetworkOperation = try features.instance()
    let resourceSharePreparation: ResourceSharePreparation = try features.instance()

    let formState: Variable<FormState> = .init(
      initial: .init(
        resourceID: resourceID,
        editedPermissions: .init(),
        deletedPermissions: .init()
      )
    )

    @Sendable func existingPermissions() async -> OrderedSet<ResourcePermission> {
      do {
        return try await resourceController.state.value.permissions
      }
      catch {
        error.logged()
        return .init()
      }
    }

    nonisolated func permissionsSequence() -> AnyAsyncSequence<OrderedSet<ResourcePermission>> {
      formState
        .asAnyAsyncSequence()
        .compactMap { try? $0.value }
        .map { (formState: FormState) -> OrderedSet<ResourcePermission> in
          let existingPermissions: Array<ResourcePermission> = await existingPermissions()
            .filter { (permission: ResourcePermission) -> Bool in
              !formState.deletedPermissions
                .contains(where: { $0.permissionID == permission.permissionID })
                && !formState.editedPermissions.contains(where: { $0.permissionID == permission.permissionID })
            }

          return
            OrderedSet(
              (existingPermissions
                + formState.editedPermissions)
                .sorted {
                  (lPermission: ResourcePermission, rPermission: ResourcePermission) -> Bool in
                  switch (lPermission, rPermission) {
                  case (.userGroup, .user):
                    return true

                  case (.userGroup(_, _, .some), .userGroup(_, _, .none)):
                    return true

                  case (.user(_, _, .some), .user(_, _, .none)):
                    return true

                  case _:
                    return false
                  }
                }
            )
        }
        .asAnyAsyncSequence()
    }

    @Sendable nonisolated func currentPermissions() async -> OrderedSet<ResourcePermission> {
      let formState: FormState = formState.value
      let existingPermissions: Array<ResourcePermission> = await existingPermissions()
        .filter { (permission: ResourcePermission) -> Bool in
          !formState.deletedPermissions
            .contains(where: { $0.permissionID == permission.permissionID })
            && !formState.editedPermissions.contains(where: { $0.permissionID == permission.permissionID })
        }

      return
        OrderedSet(
          (existingPermissions
            + formState.editedPermissions)
            .sorted {
              (lPermission: ResourcePermission, rPermission: ResourcePermission) -> Bool in
              switch (lPermission, rPermission) {
              case (.userGroup, .user):
                return true

              case (.userGroup(_, _, .some), .userGroup(_, _, .none)):
                return true

              case (.user(_, _, .some), .user(_, _, .none)):
                return true

              case _:
                return false
              }
            }
        )
    }

    @Sendable nonisolated func setUserPermission(
      _ userID: User.ID,
      permission: Permission
    ) async {
      let existingPermissions: OrderedSet<ResourcePermission> = await existingPermissions()
      let editedPermission: ResourcePermission?
      if let curentPermission: ResourcePermission = existingPermissions.first(where: {
        (permission: ResourcePermission) in
        permission.userID == userID
      }) {
        if curentPermission.permission == permission {
          editedPermission = .none  // existing permission is the same
        }
        else {
          editedPermission = .user(
            id: userID,
            permission: permission,
            permissionID: curentPermission.permissionID
          )
        }
      }
      else {
        editedPermission = .user(
          id: userID,
          permission: permission,
          permissionID: .none
        )
      }

      formState
        .mutate { (state: inout FormState) in
          state
            .editedPermissions
            .removeAll { (permission: ResourcePermission) in
              permission.userID == userID
            }
          state
            .deletedPermissions
            .removeAll { (permission: ResourcePermission) in
              permission.userID == userID
            }

          if let editedPermission {
            state.editedPermissions.append(editedPermission)
          }  // else existing permission is used
        }
    }

    @Sendable nonisolated func deleteUserPermission(
      _ userID: User.ID
    ) async {
      let existingPermissions: OrderedSet<ResourcePermission> = await existingPermissions()

      formState
        .mutate { (state: inout FormState) in
          state
            .editedPermissions
            .removeAll { (permission: ResourcePermission) in
              permission.userID == userID
            }
          if let deletedPermission: ResourcePermission = existingPermissions.first(where: {
            (permission: ResourcePermission) in
            permission.userID == userID
          }) {
            state
              .deletedPermissions
              .append(deletedPermission)
          }  // else NOP
        }
    }

    @Sendable nonisolated func setUserGroupPermission(
      _ userGroupID: UserGroup.ID,
      permission: Permission
    ) async {
      let existingPermissions: OrderedSet<ResourcePermission> = await existingPermissions()
      let editedPermission: ResourcePermission?
      if let curentPermission: ResourcePermission = existingPermissions.first(where: {
        (permission: ResourcePermission) in
        permission.userGroupID == userGroupID
      }) {
        if curentPermission.permission == permission {
          editedPermission = .none  // existing permission is the same
        }
        else {
          editedPermission = .userGroup(
            id: userGroupID,
            permission: permission,
            permissionID: curentPermission.permissionID
          )
        }
      }
      else {
        editedPermission = .userGroup(
          id: userGroupID,
          permission: permission,
          permissionID: .none
        )
      }

      formState
        .mutate { (state: inout FormState) in
          state
            .editedPermissions
            .removeAll { (permission: ResourcePermission) in
              permission.userGroupID == userGroupID
            }
          state
            .deletedPermissions
            .removeAll { (permission: ResourcePermission) in
              permission.userGroupID == userGroupID
            }

          if let editedPermission {
            state.editedPermissions.append(editedPermission)
          }  // else existing permission is used
        }
    }

    @Sendable nonisolated func deleteUserGroupPermission(
      _ userGroupID: UserGroup.ID
    ) async {
      let existingPermissions: OrderedSet<ResourcePermission> = await existingPermissions()

      formState
        .mutate { (state: inout FormState) in
          state
            .editedPermissions
            .removeAll { (permission: ResourcePermission) in
              permission.userGroupID == userGroupID
            }
          if let deletedPermission: ResourcePermission = existingPermissions.first(where: {
            (permission: ResourcePermission) in
            permission.userGroupID == userGroupID
          }) {
            state
              .deletedPermissions
              .append(deletedPermission)
          }  // else NOP
        }
    }

    @Sendable nonisolated func validate(
      formState: FormState
    ) async throws {
      let existingPermissions: Array<ResourcePermission> = await existingPermissions()
        .filter { (permission: ResourcePermission) -> Bool in
          !formState.deletedPermissions
            .contains(where: { $0.permissionID == permission.permissionID })
            && !formState.editedPermissions.contains(where: { $0.permissionID == permission.permissionID })
        }

      if existingPermissions.contains(where: \.permission.isOwner)
        || formState.editedPermissions.contains(where: \.permission.isOwner)
      {
        return  // valid
      }
      else {
        throw
          MissingResourceOwner
          .error()
      }
    }

    @Sendable nonisolated func encryptSecret(
      for newPermissions: Array<ResourcePermission>
    ) async throws -> OrderedSet<EncryptedMessage> {
      let newUsers: OrderedSet<User.ID> = .init(
        newPermissions
          .compactMap(\.userID)
      )
      let newUserGroups: OrderedSet<UserGroup.ID> = .init(
        newPermissions
          .compactMap(\.userGroupID)
      )

      let uniqueNewUsers: OrderedSet<User.ID> =
        try await withThrowingTaskGroup(
          of: Array<User.ID>.self,
          returning: OrderedSet<User.ID>.self
        ) { group in
          for userGroup in newUserGroups {
            group.addTask {
              try await userGroups
                .groupMembers(userGroup)
                .map(\.id)
            }
          }

          var mergedUsers: OrderedSet<User.ID> = newUsers
          for try await groupMembers in group {
            mergedUsers.formUnion(groupMembers)
          }

          return mergedUsers
        }

      guard !uniqueNewUsers.isEmpty
      else { return .init() }

      guard
        let resourceSecret: String = try await resourceController.fetchSecretIfNeeded(force: true).resourceSecretString
      else {
        throw
          InvalidInputData
          .error(message: "Invalid or missing resource secret")
      }

      return
        try await usersPGPMessages
        .encryptMessageForUsers(
          uniqueNewUsers,
          resourceSecret
        )
    }

    @Sendable nonisolated func sendForm() async throws {
      let formState: FormState = formState.value

      try await validate(formState: formState)

      let newPermissions: Array<ResourcePermission> = formState.editedPermissions.filter { $0.permissionID == .none }
      let newSecrets: OrderedSet<EncryptedMessage> = try await encryptSecret(for: newPermissions)
      let updatedPermissions: Array<ResourcePermission> = formState.editedPermissions.filter {
        $0.permissionID != .none
      }
      
      if newPermissions.isEmpty == false {
        try await resourceSharePreparation.prepareResourceForSharing(resourceID)
      }

      try await resourceShareNetworkOperation(
        .init(
          resourceID: resourceID,
          body: .init(
            newPermissions: newPermissions.compactMap { (permission: ResourcePermission) -> NewGenericPermissionDTO? in
              switch permission {
              case let .user(id, permission, .none):
                return .userToResource(
                  userID: id,
                  resourceID: resourceID,
                  permission: permission
                )

              case let .userGroup(id, permission, .none):
                return .userGroupToResource(
                  userGroupID: id,
                  resourceID: resourceID,
                  permission: permission
                )

              case _:
                assertionFailure("New permission can't have ID!")
                return .none
              }
            },
            updatedPermissions: updatedPermissions.compactMap {
              (permission: ResourcePermission) -> GenericPermissionDTO? in
              switch permission {
              case let .user(id, permission, .some(permissionID)):
                return .userToResource(
                  id: permissionID,
                  userID: id,
                  resourceID: resourceID,
                  permission: permission
                )

              case let .userGroup(id, permission, .some(permissionID)):
                return .userGroupToResource(
                  id: permissionID,
                  userGroupID: id,
                  resourceID: resourceID,
                  permission: permission
                )

              case _:
                assertionFailure("Edited permission has to have ID!")
                return .none
              }
            },
            deletedPermissions: formState.deletedPermissions.compactMap {
              (permission: ResourcePermission) -> GenericPermissionDTO? in
              switch permission {
              case let .user(id, permission, .some(permissionID)):
                return .userToResource(
                  id: permissionID,
                  userID: id,
                  resourceID: resourceID,
                  permission: permission
                )

              case let .userGroup(id, permission, .some(permissionID)):
                return .userGroupToResource(
                  id: permissionID,
                  userGroupID: id,
                  resourceID: resourceID,
                  permission: permission
                )

              case _:
                assertionFailure("Edited permission has to have ID!")
                return .none
              }
            },
            newSecrets: newSecrets
          )
        )
      )

      try await sessionData.refreshIfNeeded()
    }

    return Self(
      permissionsSequence: permissionsSequence,
      currentPermissions: currentPermissions,
      setUserPermission: setUserPermission(_:permission:),
      deleteUserPermission: deleteUserPermission(_:),
      setUserGroupPermission: setUserGroupPermission(_:permission:),
      deleteUserGroupPermission: deleteUserGroupPermission(_:),
      sendForm: sendForm
    )
  }
}

extension FeaturesRegistry {

  internal mutating func usePassboltResourceShareForm() {
    self.use(
      .lazyLoaded(
        ResourceShareForm.self,
        load: ResourceShareForm.load(features:)
      ),
      in: ResourceShareScope.self
    )
  }
}
