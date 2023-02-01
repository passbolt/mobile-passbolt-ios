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
import Session
import SessionData

// MARK: - Implementation

extension ResourceFolderEditForm {

  @MainActor fileprivate static func load(
    features: Features,
    context: Context,
    cancellables: Cancellables
  ) throws -> Self {
    try features.ensureScope(SessionScope.self)
    try features.ensureScope(ResourceFolderEditScope.self)

    let currentAccount: Account = try features.sessionAccount()

    let diagnostics: OSDiagnostics = features.instance()
    let asyncExecutor: AsyncExecutor = try features.instance()

    let sessionData: SessionData = try features.instance()
    let resourceFolderCreateNetworkOperation: ResourceFolderCreateNetworkOperation = try features.instance()
    let resourceFolderShareNetworkOperation: ResourceFolderShareNetworkOperation = try features.instance()

    let formUpdates: UpdatesSequenceSource = .init()
    let formState: CriticalState<ResourceFolderEditFormState> = .init(
      .init(
        name: .valid(.init()),
        location: .valid(.init()),
        permissions: .valid(.init())
      )
    )

    asyncExecutor.schedule { @MainActor in
      do {
        switch context {
        case .create(.none):
          formState.access { state in
            state.permissions = .valid(
              [
                .user(
                  id: currentAccount.userID,
                  type: .owner,
                  permissionID: .none
                )
              ]
            )
          }

        case let .create(.some(enclosingFolderID)):
          let enclosingFolderDetails: ResourceFolderDetailsDSV = try await features.instance(
            of: ResourceFolderDetails.self,
            context: enclosingFolderID
          ).details()

          let location =
            enclosingFolderDetails.location
            .map { (item: ResourceFolderLocationItemDSV) -> ResourceFolderLocationItem in
              ResourceFolderLocationItem(
                folderID: item.folderID,
                folderName: item.folderName
              )
            }
            + [
              ResourceFolderLocationItem(
                folderID: enclosingFolderDetails.id,
                folderName: enclosingFolderDetails.name
              )
            ]

          let permissions = enclosingFolderDetails
            .permissions
            .map { (permission: ResourceFolderPermissionDSV) -> ResourceFolderPermissionDSV in
              switch permission {
              case let .user(id, type, _):
                return .user(
                  id: id,
                  type: type,
                  permissionID: .none
                )

              case let .userGroup(id, type, _):
                return .userGroup(
                  id: id,
                  type: type,
                  permissionID: .none
                )
              }
            }
            .asOrderedSet()

          formState.access { state in
            state.location = .valid(location)
            state.permissions = .valid(permissions)
          }

        case let .modify(folderID):
          let folderDetails: ResourceFolderDetailsDSV = try await features.instance(
            of: ResourceFolderDetails.self,
            context: folderID
          ).details()

          let location = folderDetails.location
            .map { (item: ResourceFolderLocationItemDSV) -> ResourceFolderLocationItem in
              ResourceFolderLocationItem(
                folderID: item.folderID,
                folderName: item.folderName
              )
            }

          formState.access { state in
            state.name = .valid(folderDetails.name)
            state.location = .valid(location)
            state.permissions = .valid(folderDetails.permissions)
          }
        }
        formUpdates.sendUpdate()
      }
      catch {
        diagnostics.log(error: error)
      }
    }

    let nameValidator: Validator<String> = zip(
      .nonEmpty(
        displayable: .localized(
          key: "error.validation.folder.name.empty"
        )
      ),
      .maxLength(
        256,
        displayable: .localized(
          key: "error.validation.folder.name.too.long"
        )
      )
    )

    let permissionsValidator: Validator<OrderedSet<ResourceFolderPermissionDSV>> = zip(
      .nonEmpty(
        displayable: .localized(
          key: "error.validation.permissions.empty"
        )
      ),
      .contains(
        where: { $0.type == .owner },
        displayable: .localized(
          key: "error.validation.permissions.owner.required"
        )
      )
    )

    @Sendable func validate(
      form: inout ResourceFolderEditFormState
    ) -> ResourceFolderEditFormState {
      form.name = nameValidator.validate(form.name.value)
      form.permissions = permissionsValidator.validate(form.permissions.value)
      formUpdates.sendUpdate()
      return form
    }

    @Sendable func accessFormState() -> ResourceFolderEditFormState {
      formState.get(\.self)
    }

    @Sendable func setFolderName(
      _ folderName: String
    ) {
      formState.access { (state: inout ResourceFolderEditFormState) in
        state.name = nameValidator.validate(folderName)
      }
      formUpdates.sendUpdate()
    }

    @Sendable func sendForm() async throws {
      let formState: ResourceFolderEditFormState = formState.access(validate(form:))

      guard formState.isValid
      else {
        throw InvalidForm.error(
          displayable: .localized(
            key: "error.validation.form.invalid"
          )
        )
      }

      switch context {
      case let .create(containingFolderID):
        let createdFolderResult: ResourceFolderCreateNetworkOperationResult =
          try await resourceFolderCreateNetworkOperation
          .execute(
            .init(
              name: formState.name.value,
              parentFolderID: containingFolderID
            )
          )

        let newPermissions: OrderedSet<NewPermissionDTO> = formState.permissions.value
          .compactMap { (permission: ResourceFolderPermissionDSV) -> NewPermissionDTO? in
            switch permission {
            case let .user(id, type, _):
              guard id != currentAccount.userID
              else { return .none }
              return .userToFolder(
                userID: id,
                folderID: createdFolderResult.resourceFolderID,
                type: type
              )
            case let .userGroup(id, type, _):
              return .userGroupToFolder(
                userGroupID: id,
                folderID: createdFolderResult.resourceFolderID,
                type: type
              )
            }
          }
          .asOrderedSet()

        let updatedPermissions: OrderedSet<PermissionDTO> = formState.permissions.value
          .compactMap { (permission: ResourceFolderPermissionDSV) -> PermissionDTO? in
            if case .user(currentAccount.userID, let type, _) = permission, type != .owner {
              return .userToFolder(
                id: createdFolderResult.ownerPermissionID,
                userID: currentAccount.userID,
                folderID: createdFolderResult.resourceFolderID,
                type: type
              )
            }
            else {
              return .none
            }
          }
          .asOrderedSet()

        let deletedPermissions: OrderedSet<PermissionDTO>
        if !formState.permissions.value.contains(where: { (permission: ResourceFolderPermissionDSV) -> Bool in
          if case .user(currentAccount.userID, _, _) = permission {
            return true
          }
          else {
            return false
          }
        }) {
          deletedPermissions = [
            .userToFolder(
              id: createdFolderResult.ownerPermissionID,
              userID: currentAccount.userID,
              folderID: createdFolderResult.resourceFolderID,
              type: .owner
            )
          ]
        }
        else {
          deletedPermissions = .init()
        }
        // if shared or different permission
        if !newPermissions.isEmpty || !updatedPermissions.isEmpty || !deletedPermissions.isEmpty {
          try await resourceFolderShareNetworkOperation.execute(
            .init(
              resourceFolderID: createdFolderResult.resourceFolderID,
              body: .init(
                newPermissions: newPermissions,
                updatedPermissions: updatedPermissions,
                deletedPermissions: deletedPermissions
              )
            )
          )
        }  // else private owned

      case .modify:
        throw
          Unimplemented
          .error()
      }

      try await sessionData.refreshIfNeeded()
    }

    return Self(
      formUpdates: formUpdates.updatesSequence,
      formState: accessFormState,
      setFolderName: setFolderName(_:),
      sendForm: sendForm
    )
  }
}

extension FeaturesRegistry {

  internal mutating func usePassboltResourceFolderEditForm() {
    self.use(
      .lazyLoaded(
        ResourceFolderEditForm.self,
        load: ResourceFolderEditForm.load(features:context:cancellables:)
      ),
      in: ResourceFolderEditScope.self
    )
  }
}
