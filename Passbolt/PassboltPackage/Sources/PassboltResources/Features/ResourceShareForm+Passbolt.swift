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

import NetworkOperations
import Resources
import SessionData
import Users

// MARK: - Implementation

extension ResourceShareForm {

  fileprivate struct FormState: Hashable {

    fileprivate var newPermissions: OrderedSet<NewPermissionDTO>
    fileprivate var updatedPermissions: OrderedSet<PermissionDTO>
    fileprivate var deletedPermissions: OrderedSet<PermissionDTO>
  }

  @MainActor fileprivate static func load(
    features: Features,
    context resourceID: Context,
    cancellables: Cancellables
  ) throws -> Self {
    try features.ensureScope(SessionScope.self)
    try features.ensureScope(ResourceShareScope.self)

    let diagnostics: OSDiagnostics = features.instance()
    let sessionData: SessionData = try features.instance()
    let resourceDetails: ResourceDetails = try features.instance(context: resourceID)
    let usersPGPMessages: UsersPGPMessages = try features.instance()
    let userGroups: UserGroups = try features.instance()
    let resourceShareNetworkOperation: ResourceShareNetworkOperation = try features.instance()

    let formState: AsyncVariable<FormState> = .init(
      initial: .init(
        newPermissions: .init(),
        updatedPermissions: .init(),
        deletedPermissions: .init()
      )
    )

    func existingPermissions() async -> OrderedSet<PermissionDTO> {
      do {
        return try await resourceDetails.details().permissions
      }
      catch {
        diagnostics.log(error: error)
        return .init()
      }
    }

    nonisolated func permissionsSequence() -> AnyAsyncSequence<OrderedSet<ResourceShareFormPermission>> {
      formState
        .removeDuplicates()
        .map { (formState: FormState) -> OrderedSet<ResourceShareFormPermission> in
          let existingPermissions: OrderedSet<PermissionDTO> = await existingPermissions()
          let existingPermissionsList: Array<ResourceShareFormPermission> =
            existingPermissions
            .compactMap { (permission: PermissionDSV) -> ResourceShareFormPermission? in
              guard
                !formState.deletedPermissions.contains(where: { $0.id == permission.id }),
                !formState.updatedPermissions.contains(where: { $0.id == permission.id })
              else { return .none }
              switch permission {
              case let .userToResource(_, userID, _, type):
                return .user(userID, type: type)
              case let .userGroupToResource(_, userGroupID, _, type):
                return .userGroup(userGroupID, type: type)
              case .userToFolder, .userGroupToFolder:
                return .none
              }
            }

          let updatedPermissionsList: OrderedSet<ResourceShareFormPermission> = .init(
            formState
              .updatedPermissions
              .compactMap { (permission: PermissionDSV) -> ResourceShareFormPermission? in
                switch permission {
                case let .userToResource(_, userID, _, type):
                  return .user(userID, type: type)
                case let .userGroupToResource(_, userGroupID, _, type):
                  return .userGroup(userGroupID, type: type)
                case .userToFolder, .userGroupToFolder:
                  return .none
                }
              }
          )

          let newPermissionsList: OrderedSet<ResourceShareFormPermission> = .init(
            formState
              .newPermissions
              .compactMap { (permission: NewPermissionDTO) -> ResourceShareFormPermission? in
                switch permission {
                case let .userToResource(userID, _, type):
                  return .user(userID, type: type)
                case let .userGroupToResource(userGroupID, _, type):
                  return .userGroup(userGroupID, type: type)
                case .userToFolder, .userGroupToFolder:
                  return .none
                }
              }
          )

          return
            OrderedSet(
              (existingPermissionsList
                + updatedPermissionsList
                + newPermissionsList)
                .sorted {
                  (lPermission: ResourceShareFormPermission, rPermission: ResourceShareFormPermission) -> Bool in
                  switch (lPermission, rPermission) {
                  case let (.user(lUserID, _), .user(rUserID, _)):
                    return lUserID != rUserID
                      && (existingPermissions.contains(where: { $0.userID == lUserID })
                        && !existingPermissions.contains(where: { $0.userID == rUserID }))
                  case let (.userGroup(lUserGroupID, _), .userGroup(rUserGroupID, _)):
                    return lUserGroupID != rUserGroupID
                      && (existingPermissions.contains(where: { $0.userGroupID == lUserGroupID })
                        && !existingPermissions.contains(where: { $0.userGroupID == rUserGroupID }))
                  case (.userGroup, .user):
                    return true
                  case (.user, .userGroup):
                    return false
                  }
                }
            )
        }
        .asAnyAsyncSequence()
    }

    @Sendable nonisolated func currentPermissions() async -> OrderedSet<ResourceShareFormPermission> {
      let formState: FormState = formState.value
      let existingPermissions: OrderedSet<PermissionDTO> = await existingPermissions()
      let existingPermissionsList: Array<ResourceShareFormPermission> =
        existingPermissions
        .compactMap { (permission: PermissionDSV) -> ResourceShareFormPermission? in
          guard
            !formState.deletedPermissions.contains(where: { $0.id == permission.id }),
            !formState.updatedPermissions.contains(where: { $0.id == permission.id })
          else { return .none }
          switch permission {
          case let .userToResource(_, userID, _, type):
            return .user(userID, type: type)
          case let .userGroupToResource(_, userGroupID, _, type):
            return .userGroup(userGroupID, type: type)
          case .userToFolder, .userGroupToFolder:
            return .none
          }
        }

      let updatedPermissionsList: OrderedSet<ResourceShareFormPermission> = .init(
        formState
          .updatedPermissions
          .compactMap { (permission: PermissionDSV) -> ResourceShareFormPermission? in
            switch permission {
            case let .userToResource(_, userID, _, type):
              return .user(userID, type: type)
            case let .userGroupToResource(_, userGroupID, _, type):
              return .userGroup(userGroupID, type: type)
            case .userToFolder, .userGroupToFolder:
              return .none
            }
          }
      )

      let newPermissionsList: OrderedSet<ResourceShareFormPermission> = .init(
        formState
          .newPermissions
          .compactMap { (permission: NewPermissionDTO) -> ResourceShareFormPermission? in
            switch permission {
            case let .userToResource(userID, _, type):
              return .user(userID, type: type)
            case let .userGroupToResource(userGroupID, _, type):
              return .userGroup(userGroupID, type: type)
            case .userToFolder, .userGroupToFolder:
              return .none
            }
          }
      )

      return
        OrderedSet(
          (existingPermissionsList
            + updatedPermissionsList
            + newPermissionsList)
            .sorted {
              (lPermission: ResourceShareFormPermission, rPermission: ResourceShareFormPermission) -> Bool in
              switch (lPermission, rPermission) {
              case let (.user(lUserID, _), .user(rUserID, _)):
                return lUserID != rUserID
                  && (existingPermissions.contains(where: { $0.userID == lUserID })
                    && !existingPermissions.contains(where: { $0.userID == rUserID }))
              case let (.userGroup(lUserGroupID, _), .userGroup(rUserGroupID, _)):
                return lUserGroupID != rUserGroupID
                  && (existingPermissions.contains(where: { $0.userGroupID == lUserGroupID })
                    && !existingPermissions.contains(where: { $0.userGroupID == rUserGroupID }))
              case (.userGroup, .user):
                return true
              case (.user, .userGroup):
                return false
              }
            }
        )
    }

    @Sendable nonisolated func setUserPermission(
      _ userID: User.ID,
      permissionType: PermissionType
    ) async {
      let existingPermissions: OrderedSet<PermissionDTO> = await existingPermissions()
      let curentPermission: PermissionDTO? = existingPermissions.first { (permission: PermissionDTO) in
        permission.userID == userID
      }

      return
        formState
        .withValue { (state: inout FormState) in
          state
            .newPermissions
            .removeAll { (permission: NewPermissionDTO) in
              permission.userID == userID
            }
          state
            .updatedPermissions
            .removeAll { (permission: PermissionDTO) in
              permission.userID == userID
            }
          state
            .deletedPermissions
            .removeAll { (permission: PermissionDTO) in
              permission.userID == userID
            }

          if let curentPermission: PermissionDTO = curentPermission {
            guard curentPermission.type != permissionType
            else { return /* NOP */ }
            state
              .updatedPermissions
              .append(
                .userToResource(
                  id: curentPermission.id,
                  userID: userID,
                  resourceID: resourceID,
                  type: permissionType
                )
              )
          }
          else {
            state
              .newPermissions
              .append(
                .userToResource(
                  userID: userID,
                  resourceID: resourceID,
                  type: permissionType
                )
              )
          }
        }
    }

    @Sendable nonisolated func deleteUserPermission(
      _ userID: User.ID
    ) async {
      let existingPermissions: OrderedSet<PermissionDTO> = await existingPermissions()
      formState
        .withValue { (state: inout FormState) in
          state
            .newPermissions
            .removeAll { (permission: NewPermissionDTO) in
              permission.userID == userID
            }
          state
            .updatedPermissions
            .removeAll { (permission: PermissionDTO) in
              permission.userID == userID
            }
          state
            .deletedPermissions
            .append(
              contentsOf:
                existingPermissions
                .filter { (permission: PermissionDTO) in
                  permission.userID == userID
                }
            )
        }
    }

    @Sendable nonisolated func setUserGroupPermission(
      _ userGroupID: UserGroup.ID,
      permissionType: PermissionType
    ) async {
      let existingPermissions: OrderedSet<PermissionDTO> = await existingPermissions()
      formState
        .withValue { (state: inout FormState) in
          state
            .newPermissions
            .removeAll { (permission: NewPermissionDTO) in
              permission.userGroupID == userGroupID
            }
          state
            .updatedPermissions
            .removeAll { (permission: PermissionDTO) in
              permission.userGroupID == userGroupID
            }
          state
            .deletedPermissions
            .removeAll { (permission: PermissionDTO) in
              permission.userGroupID == userGroupID
            }

          let curentPermission: PermissionDTO? = existingPermissions.first { (permission: PermissionDTO) in
            permission.userGroupID == userGroupID
          }

          if let curentPermission: PermissionDTO = curentPermission {
            guard curentPermission.type != permissionType
            else { return /* NOP */ }
            state
              .updatedPermissions
              .append(
                .userGroupToResource(
                  id: curentPermission.id,
                  userGroupID: userGroupID,
                  resourceID: resourceID,
                  type: permissionType
                )
              )
          }
          else {
            state
              .newPermissions
              .append(
                .userGroupToResource(
                  userGroupID: userGroupID,
                  resourceID: resourceID,
                  type: permissionType
                )
              )
          }
        }
    }

    @Sendable nonisolated func deleteUserGroupPermission(
      _ userGroupID: UserGroup.ID
    ) async {
      let existingPermissions: OrderedSet<PermissionDTO> = await existingPermissions()
      formState
        .withValue { (state: inout FormState) in
          state
            .newPermissions
            .removeAll { (permission: NewPermissionDTO) in
              permission.userGroupID == userGroupID
            }
          state
            .updatedPermissions
            .removeAll { (permission: PermissionDTO) in
              permission.userGroupID == userGroupID
            }
          state
            .deletedPermissions
            .append(
              contentsOf:
                existingPermissions
                .filter { (permission: PermissionDTO) in
                  permission.userGroupID == userGroupID
                }
            )
        }
    }

    @Sendable nonisolated func validate(
      formState: FormState
    ) async throws {
      let existingPermissions: OrderedSet<PermissionDTO> = await existingPermissions()
      let newPermissionsHasOwner: Bool =
        formState
        .newPermissions
        .contains(
          where: { (permission: NewPermissionDTO) in
            permission.type.isOwner
          }
        )

      guard !newPermissionsHasOwner
      else { return }

      let updatedPermissionsHasOwner: Bool =
        formState
        .updatedPermissions
        .contains(
          where: { (permission: PermissionDTO) in
            permission.type.isOwner
          }
        )

      guard !updatedPermissionsHasOwner
      else { return }

      let currentPermissionsHasOwner: Bool =
        existingPermissions
        .contains(
          where: { (permission: PermissionDTO) in
            permission.type.isOwner
              && !formState
                .deletedPermissions
                .contains(
                  where: { (deletedPermission: PermissionDTO) in
                    deletedPermission.id == permission.id
                  }
                )
          }
        )

      guard !currentPermissionsHasOwner
      else { return }

      throw
        MissingResourceOwner
        .error()
    }

    @Sendable nonisolated func encryptSecret(
      for newPermissions: OrderedSet<NewPermissionDTO>
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

      let secret: ResourceSecret = try await resourceDetails.secret()

      return
        try await OrderedSet(
          usersPGPMessages
            .encryptMessageForUsers(
              uniqueNewUsers,
              secret.rawValue
            )
        )
    }

    @Sendable nonisolated func sendForm() async throws {
      let formState: FormState = formState.value

      try await validate(formState: formState)

      let newSecrets: OrderedSet<EncryptedMessage> = try await encryptSecret(for: formState.newPermissions)

      try await resourceShareNetworkOperation(
        .init(
          resourceID: resourceID,
          body: .init(
            newPermissions: formState.newPermissions,
            updatedPermissions: formState.updatedPermissions,
            deletedPermissions: formState.deletedPermissions,
            newSecrets: newSecrets
          )
        )
      )

      try await sessionData.refreshIfNeeded()
    }

    return Self(
      permissionsSequence: permissionsSequence,
      currentPermissions: currentPermissions,
      setUserPermission: setUserPermission(_:permissionType:),
      deleteUserPermission: deleteUserPermission(_:),
      setUserGroupPermission: setUserGroupPermission(_:permissionType:),
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
        load: ResourceShareForm.load(features:context:cancellables:)
      ),
      in: ResourceShareScope.self
    )
  }
}
