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

internal struct OTPEditFormView: ControlledView {

  internal let controller: OTPEditFormViewController

  internal init(
    controller: OTPEditFormViewController
  ) {
    self.controller = controller
  }

  internal var body: some View {
    with(\.isEditing) { (isEditing: Bool) in
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

          self.sendForm(editng: isEditing)
        }
        .padding(16)
        .frame(maxHeight: .infinity)
      .navigationTitle(
        displayable: isEditing
          ? "otp.edit.form.edit.title"
          : "otp.edit.form.create.title"
      )
    }
  }

  @MainActor @ViewBuilder internal var nameField: some View {
    with(\.nameField) { (state: Validated<String>) in
      FormTextFieldView(
        title: "otp.edit.form.field.name.title",
        prompt: "otp.edit.form.field.name.prompt",
        mandatory: true,
        state: self.validatedBinding(
          to: \.nameField,
          updating: { (newValue: String) in
            withAnimation {
              self.controller.setName(newValue)
            }
          }
        )
      )
      .textInputAutocapitalization(.sentences)
    }
  }

  @MainActor @ViewBuilder internal var uriField: some View {
    with(\.uriField) { (state: Validated<String>) in
      FormTextFieldView(
        title: "otp.edit.form.field.uri.title",
        prompt: "otp.edit.form.field.uri.prompt",
        mandatory: false,
        state: self.binding(
          to: \.uriField,
          updating: { (newValue: Validated<String>) in
            withAnimation {
              self.controller.setURI(newValue.value)
            }
          }
        )
      )
      .textInputAutocapitalization(.never)
      .autocorrectionDisabled()
    }
  }

  @MainActor @ViewBuilder internal var secretField: some View {
    with(\.secretField) { (state: Validated<String>) in
      FormTextFieldView(
        title: "otp.edit.form.field.secret.title",
        prompt: "otp.edit.form.field.secret.prompt",
        mandatory: true,
        state: self.validatedBinding(
          to: \.secretField,
          updating: { (newValue: String) in
            withAnimation {
              self.controller.setSecret(newValue)
            }
          }
        )
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

  @MainActor @ViewBuilder internal func sendForm(
    editng isEditing: Bool
  ) -> some View {
    if isEditing {
      PrimaryButton(
        title: "otp.edit.form.edit.button.title",
        action: self.controller.createOrUpdateOTP
      )
    }
    else {
      VStack(spacing: 8) {
        PrimaryButton(
          title: "otp.edit.form.create.button.title",
          action: self.controller.createOrUpdateOTP
        )
        SecondaryButton(
          title: "otp.scanning.success.link.button.title",
          action: self.controller.selectResourceToAttach
        )
      }
    }
  }
}
