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

import Resources
import Session

// MARK: - Implementation

extension ResourceFolderEditForm {

  fileprivate static func load(
    features: FeatureFactory,
    context: Context,
    cancellables: Cancellables
  ) async throws -> Self {

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
    ) -> Bool {
      form.name = nameValidator.validate(form.name.value)
      form.permissions = permissionsValidator.validate(form.permissions.value)

      return form.isValid
    }

    let initialFormState: ResourceFolderEditFormState
    switch context {
    case .create(.none):
      let currentUserID: User.ID =
        try await features
        .instance(
          of: Session.self
        )
        .currentAccount()
        .userID

      initialFormState = .init(
        name: .valid(""),
        location: .valid(.init()),
        permissions: .valid(
          [
            .user(
              id: currentUserID,
              type: .owner,
              permissionID: .none
            )
          ]
        )
      )

    case let .create(.some(enclosingFolderID)):
      let enclosingFolderDetails: ResourceFolderDetailsDSV = try await features.instance(
        of: ResourceFolderDetails.self,
        context: enclosingFolderID
      ).details.value

      initialFormState = .init(
        name: .valid(""),
        location: .valid(.init()),
        permissions: .valid(
          enclosingFolderDetails.permissions
        )
      )

    case let .modify(folderID):
      let folderDetails: ResourceFolderDetailsDSV = try await features.instance(
        of: ResourceFolderDetails.self,
        context: folderID
      ).details.value

      initialFormState = .init(
        name: .valid(folderDetails.name),
        location: .valid(.init()),
        permissions: .valid(
          folderDetails.permissions
        )
      )
    }

    let formState: UpdatableValueSource<ResourceFolderEditFormState> = .init(
      initial: initialFormState
    )

    @Sendable func setFolderName(
      _ folderName: String
    ) {
      formState.update { (state: inout ResourceFolderEditFormState) in
        state.name = nameValidator.validate(folderName)
      }
    }

    @Sendable func sendForm() async throws {
      let formValid: Bool = formState.update(validate(form:))
      guard formValid
      else {
        throw InvalidForm.error(
          displayable: .localized(
            key: "error.validation.form.invalid"
          )
        )
      }
      #warning("TODO: MOB-615")
      throw
        Unimplemented
        .error()
    }

    return Self(
      formState: formState.updatableValue,
      setFolderName: setFolderName(_:),
      sendForm: sendForm
    )
  }
}

extension FeatureFactory {

  internal func usePassboltResourceFolderEditForm() {
    self.use(
      .lazyLoaded(
        ResourceFolderEditForm.self,
        load: ResourceFolderEditForm.load(features:context:cancellables:)
      )
    )
  }
}
