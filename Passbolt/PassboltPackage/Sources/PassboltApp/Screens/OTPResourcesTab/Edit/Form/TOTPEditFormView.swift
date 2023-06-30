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
import UICommons

internal struct TOTPEditFormView: ControlledView {

  private let controller: TOTPEditFormController

  internal init(
    controller: TOTPEditFormController
  ) {
    self.controller = controller
  }

  internal var body: some View {
    WithSnackBarMessage(
      from: self.controller
    ) {
      VStack(spacing: 0) {
        ScrollView {
          VStack(spacing: 16) {
            self.nameField
            self.uriField
            self.secretField
            self.advancedLink
          }
        }

        Spacer()

        self.sendForm
      }
      .padding(16)
      .frame(maxHeight: .infinity)
    }
    .navigationTitle(
      displayable: self.controller.isEditing
        ? "otp.edit.form.edit.title"
        : "otp.edit.form.create.title"
    )
  }

  @MainActor @ViewBuilder internal var nameField: some View {
    WithViewState(
      from: self.controller,
      at: \.nameField
    ) { (state: Validated<String>) in
      FormTextFieldView(
        title: "otp.edit.form.field.name.title",
        prompt: "otp.edit.form.field.name.prompt",
        mandatory: true,
        state: state,
        update: { (value: String) in
          self.controller.setNameField(value)
        }
      )
      .textInputAutocapitalization(.sentences)
    }
  }

  @MainActor @ViewBuilder internal var uriField: some View {
    WithViewState(
      from: self.controller,
      at: \.uriField
    ) { (state: Validated<String>) in
      FormTextFieldView(
        title: "otp.edit.form.field.uri.title",
        prompt: "otp.edit.form.field.uri.prompt",
        mandatory: false,
        state: state,
        update: { (value: String) in
          self.controller.setURIField(value)
        }
      )
      .textInputAutocapitalization(.never)
      .autocorrectionDisabled()
    }
  }

  @MainActor @ViewBuilder internal var secretField: some View {
    WithViewState(
      from: self.controller,
      at: \.secretField
    ) { (state: Validated<String>) in
      FormTextFieldView(
        title: "otp.edit.form.field.secret.title",
        prompt: "otp.edit.form.field.secret.prompt",
        mandatory: true,
        state: state,
        update: { (value: String) in
          self.controller.setSecretField(value)
        }
      )
      .textInputAutocapitalization(.never)
      .autocorrectionDisabled()
    }
  }

  @MainActor @ViewBuilder internal var advancedLink: some View {
    LinkButton(
      title: "otp.edit.form.advanced.button.title",
      iconName: .cog,
      action: self.controller.showAdvancedSettings
    )
  }

  @MainActor @ViewBuilder internal var sendForm: some View {
    PrimaryButton(
      title: self.controller.isEditing
        ? "otp.edit.form.edit.button.title"
        : "otp.edit.form.create.button.title",
      action: self.controller.sendForm
    )
  }
}
