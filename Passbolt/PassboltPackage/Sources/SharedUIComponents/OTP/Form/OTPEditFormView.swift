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
          VStack(alignment: .leading, spacing: 20) {
            with(\.isStandaloneTOTP) { (isStandaloneTOTP: Bool) in
              if isStandaloneTOTP {
                self.nameField
              }
            }
            Text(displayable: "resource.edit.field.totp.label")
              .font(.inter(ofSize: 16, weight: .bold))
            VStack(spacing: 16) {
              self.uriField
              self.secretField
              self.advancedLink
            }
            .padding(16)
            .background(Color.passboltBackgroundGray)
            .cornerRadius(4)
          }
        }

        SecondaryButton(
          title: "resource.edit.totp.remove.button.title",
          iconName: .trash,
          action: {
            await self.controller.removeTOTP()
          }
        )

        Spacer()
        with(\.isStandaloneTOTP) { (isStandaloneTOTP: Bool) in
          if isStandaloneTOTP {
            self.sendForm(editng: isEditing)
          }
          else {
            self.applyForm()
          }
        }
      }
      .padding(16)
      .frame(maxHeight: .infinity)
      .navigationBarBackButtonHidden()
      .toolbar {  // replace back button
        ToolbarItemGroup(placement: .navigationBarLeading) {
          BackButton(
            action: {
              await self.controller.discardForm()
            }
          )
        }
      }
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
        ),
        accessory: {
          AsyncButton(
            action: {
              await self.controller.scanTOTP()
            },
            label: {
              Image(named: .camera)
                .tint(.passboltPrimaryText)
                .padding(12)
                .backgroundColor(.passboltDivider)
                .cornerRadius(4)
            }
          )
        }
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
    .padding(.vertical, 8)
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

  @MainActor @ViewBuilder internal func applyForm() -> some View {
    PrimaryButton(
      title: "otp.edit.form.apply.button.title",
      action: self.controller.applyForm
    )
  }
}
