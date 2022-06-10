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

import Features
import NetworkClient
import Users

// MARK: - Interface

public struct ResourceShareForm {

  public var permissionsSequence: () -> AnyAsyncSequence<OrderedSet<ResourceShareFormPermission>>
  public var setUserPermission: (User.ID, PermissionType) async throws -> Void
  public var deleteUserPermission: (User.ID) async throws -> Void
  public var setUserGroupPermission: (UserGroup.ID, PermissionType) async throws -> Void
  public var deleteUserGroupPermission: (UserGroup.ID) async throws -> Void
  public var sendForm: @AccountSessionActor () async throws -> Void
  public var cancelForm: @FeaturesActor () async -> Void

  public init(
    permissionsSequence: @escaping () -> AnyAsyncSequence<OrderedSet<ResourceShareFormPermission>>,
    setUserPermission: @escaping (User.ID, PermissionType) async throws -> Void,
    deleteUserPermission: @escaping (User.ID) async throws -> Void,
    setUserGroupPermission: @escaping (UserGroup.ID, PermissionType) async throws -> Void,
    deleteUserGroupPermission: @escaping (UserGroup.ID) async throws -> Void,
    sendForm: @escaping @AccountSessionActor () async throws -> Void,
    cancelForm: @escaping @FeaturesActor () async -> Void
  ) {
    self.permissionsSequence = permissionsSequence
    self.setUserPermission = setUserPermission
    self.deleteUserPermission = deleteUserPermission
    self.setUserGroupPermission = setUserGroupPermission
    self.deleteUserGroupPermission = deleteUserGroupPermission
    self.sendForm = sendForm
    self.cancelForm = cancelForm
  }
}

extension ResourceShareForm: LoadableFeature {

  public typealias Context = Resource.ID
}

// MARK: - Implementation

extension ResourceShareForm {

  fileprivate static func load(
    features: FeatureFactory,
    context resourceID: Context,
    cancellables: Cancellables
  ) async throws -> Self {
    let networkClient: NetworkClient = try await features.instance()
    let resourceDetails: ResourceDetails = try await features.instance(context: resourceID)
    let usersPGPMessages: UsersPGPMessages = try await features.instance()
    let userGroups: UserGroups = try await features.instance()

    struct FormState {
      var newPermissions: OrderedSet<NewPermissionDTO>
      var updatedPermissions: OrderedSet<PermissionDTO>
      var deletedPermissions: OrderedSet<PermissionDTO>
    }

    let formState: AsyncVariable<FormState> = .init(
      initial: .init(
        newPermissions: .init(),
        updatedPermissions: .init(),
        deletedPermissions: .init()
      )
    )

    let currentPermissions: OrderedSet<PermissionDTO> = try await resourceDetails.details().permissions

    nonisolated func permissionsSequence() -> AnyAsyncSequence<OrderedSet<ResourceShareFormPermission>> {
      formState
        // .removeDuplicates() TODO: duplicates ??
        .map { (formState: FormState) -> OrderedSet<ResourceShareFormPermission> in
          let existingPermissionsList: Array<ResourceShareFormPermission> =
            currentPermissions
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
                      && (currentPermissions.contains(where: { $0.userID == lUserID })
                        && !currentPermissions.contains(where: { $0.userID == rUserID }))
                  case let (.userGroup(lUserGroupID, _), .userGroup(rUserGroupID, _)):
                    return lUserGroupID != rUserGroupID
                      && (currentPermissions.contains(where: { $0.userGroupID == lUserGroupID })
                        && !currentPermissions.contains(where: { $0.userGroupID == rUserGroupID }))
                  case (.userGroup, .user):
                    return true
                  case (.user, .userGroup):
                    return false
                  }
                }
            )
        }
        .map {
          $0
        }
        .asAnyAsyncSequence()
    }

    func setUserPermission(
      _ userID: User.ID,
      permissionType: PermissionType
    ) async throws {
      let curentPermission: PermissionDTO? = currentPermissions.first { (permission: PermissionDTO) in
        permission.userID == userID
      }

      return try await formState
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

    func deleteUserPermission(
      _ userID: User.ID
    ) async throws {
      try await formState
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
                currentPermissions
                .filter { (permission: PermissionDTO) in
                  permission.userID == userID
                }
            )
        }
    }

    func setUserGroupPermission(
      _ userGroupID: UserGroup.ID,
      permissionType: PermissionType
    ) async throws {
      try await formState
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

          let curentPermission: PermissionDTO? = currentPermissions.first { (permission: PermissionDTO) in
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

    func deleteUserGroupPermission(
      _ userGroupID: UserGroup.ID
    ) async throws {
      try await formState
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
                currentPermissions
                .filter { (permission: PermissionDTO) in
                  permission.userGroupID == userGroupID
                }
            )
        }
    }

    func validate(
      formState: FormState
    ) throws {
      let newPermissionsHasOwner: Bool =
        formState
        .newPermissions
        .contains(
          where: { (permission: NewPermissionDTO) in
            permission.type == .owner
          }
        )

      guard !newPermissionsHasOwner
      else { return }

      let updatedPermissionsHasOwner: Bool =
        formState
        .updatedPermissions
        .contains(
          where: { (permission: PermissionDTO) in
            permission.type == .owner
          }
        )

      guard !updatedPermissionsHasOwner
      else { return }

      let currentPermissionsHasOwner: Bool =
        currentPermissions
        .contains(
          where: { (permission: PermissionDTO) in
            permission.type == .owner
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

    func encryptSecret(
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
          of: OrderedSet<User.ID>.self,
          returning: OrderedSet<User.ID>.self
        ) { group in
          for userGroup in newUserGroups {
            group.addTask {
              try await userGroups.groupMembers(userGroup)
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

      let secret: ResourceSecret = try await resourceDetails.decryptSecret()

      return
        try await OrderedSet(
          usersPGPMessages
            .encryptMessageForUsers(
              uniqueNewUsers,
              secret.rawValue
            )
        )
    }

    @FeaturesActor func close() async {
      do {
        try await features.unload(
          Self.self,
          context: resourceID
        )
      }
      catch {
        error
          .asTheError()
          .asAssertionFailure()
      }
    }

    @AccountSessionActor func sendForm() async throws {
      let formState: FormState = await formState.value

      try validate(formState: formState)

      let newSecrets: OrderedSet<EncryptedMessage> = try await encryptSecret(for: formState.newPermissions)

      try await networkClient
        .shareResourceRequest
        .makeAsync(
          using: .init(
            resourceID: resourceID,
            body: .init(
              newPermissions: formState.newPermissions,
              updatedPermissions: formState.updatedPermissions,
              deletedPermissions: formState.deletedPermissions,
              newSecrets: newSecrets
            )
          )
        )

      await close()
    }

    @FeaturesActor func cancelForm() async {
      await close()
    }

    return ResourceShareForm(
      permissionsSequence: permissionsSequence,
      setUserPermission: setUserPermission(_:permissionType:),
      deleteUserPermission: deleteUserPermission(_:),
      setUserGroupPermission: setUserGroupPermission(_:permissionType:),
      deleteUserGroupPermission: deleteUserGroupPermission(_:),
      sendForm: sendForm,
      cancelForm: cancelForm
    )
  }
}

extension FeatureFactory {

  @FeaturesActor public func usePassboltResourceShareForm() {
    self.use(
      .lazyLoaded(
        ResourceShareForm.self,
        load: ResourceShareForm.load(features:context:cancellables:)
      )
    )
  }
}

#if DEBUG

extension ResourceShareForm {

  public static var placeholder: Self {
    Self(
      permissionsSequence: unimplemented(),
      setUserPermission: unimplemented(),
      deleteUserPermission: unimplemented(),
      setUserGroupPermission: unimplemented(),
      deleteUserGroupPermission: unimplemented(),
      sendForm: unimplemented(),
      cancelForm: unimplemented()
    )
  }
}
#endif
