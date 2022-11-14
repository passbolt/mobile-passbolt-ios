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

internal struct ResourceFolderEditView: ControlledView {

  private let controller: ResourceFolderEditController

  internal init(
    controller: ResourceFolderEditController
  ) {
    self.controller = controller
  }

  internal var body: some View {
    WithViewState(self.controller) { (state: ViewState) in
      ScreenView(
        title: .localized(
          key: "folder.edit.form.create.title"
        ),
        loading: state.loading,
        snackBarMessage: self.controller.binding(to: \.snackBarMessage),
        contentView: {
          self.contentView(using: state)
        }
      )
    }
  }

  @ViewBuilder @MainActor private func contentView(
    using state: ViewState
  ) -> some View {
    VStack(spacing: 16) {
      FormTextFieldView(
        title: .localized(
          key: "form.field.name.title"
        ),
        mandatory: true,
        text: .init(
          get: { state.folderName },
          set: { (newValue: Validated<String>) in
            self.controller.setFolderName(newValue.value)
          }
        ),
        prompt: .localized(
          key: "folder.edit.form.name.field.placeholder"
        )
      )

      FolderLocationView(
        locationElements: state.folderLocation
      )

      PermissionAvatarsView(
        title: .localized(key: "shared.avatars.view.title"),
        items: state.folderPermissionItems
      )

      Spacer()

      PrimaryButton(
        title: .localized(
          key: "form.button.save.title"
        ),
        action: self.controller.saveChanges
      )
    }
    .padding(16)
  }
}
