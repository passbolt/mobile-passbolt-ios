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

public struct ResourceEditView: ControlledView {

  public let controller: ResourceEditViewController
  @State private var discardFormAlertVisible: Bool
  @FocusState private var focusState

  public init(
    controller: ResourceEditViewController
  ) {
    self.controller = controller
    self.discardFormAlertVisible = false
  }

  public var body: some View {
    self.contentView
      .alert(
        isPresented: self.$discardFormAlertVisible,
        title: "generic.are.you.sure",
        message: "resource.edit.exit.confirmation.message",
        actions: {
          Button(
            displayable: "resource.edit.exit.confirmation.button.edit.title",
            role: .cancel,
            action: { /* NOP */  }
          )
          AsyncButton(
            role: .destructive,
            action: {
              await self.controller.discardForm()
            },
            label: {
              Text(displayable: "resource.edit.exit.confirmation.button.revert.title")
            }
          )
        }
      )
      .navigationBarBackButtonHidden()
      .toolbar {  // replace back button
        ToolbarItemGroup(placement: .navigationBarLeading) {
          WithViewState(
            from: self.controller,
            at: \.edited
          ) { (edited: Bool) in
            BackButton(
              action: {
                if edited {
                  self.discardFormAlertVisible = true
                }
                else {
                  await self.controller.discardForm()
                }
              }
            )
          }
        }
      }
      .navigationTitle(
        displayable: self.controller.editsExisting
          ? "resource.edit.title"
          : "resource.edit.create.title"
      )
      .backgroundColor(.passboltBackground)
      .foregroundColor(.passboltPrimaryText)
  }

  @MainActor @ViewBuilder private var contentView: some View {
    CommonList {
      CommonListSection {
        VStack(spacing: 8) {
          VStack(alignment: .leading, spacing: 0) {
            WithViewState(
              from: self.controller,
              at: \.containsUndefinedFields
            ) { (containsUndefinedFields: Bool) in
              if containsUndefinedFields {
                self.undefinedContentSectionView
              }
            }

            with(\.nameField) { nameField in
              if let nameField {
                self.fieldView(for: nameField)
              }
            }

            with(\.mainForm) { mainForm in
              Text(displayable: mainForm.title)
                .font(.inter(ofSize: 16, weight: .bold))
                .padding(.vertical, 20)
              VStack(spacing: 16) {
                withEach(\.mainForm.fields) { field in
                  self.fieldView(for: field)
                }
              }
              .padding(.horizontal, 16)
              .padding(.vertical, 8)
              .backgroundColor(.passboltBackgroundGray)
              .cornerRadius(4)
            }
          }
          when(\.canShowAdvancedSettings) {
            SecondaryButton(
              title: "resource.create.advanced.button",
              action: {
                withAnimation {
                  self.controller.showAdvancedSettings()
                }
              }
            )
          }
          CommonListSpacer(minHeight: 16)

        }
        .padding(.top, 16)
      }
      when(\.showsAdvancedSettings) {
        CommonListSection {
          VStack(alignment: .leading, spacing: 16) {
            Text(displayable: "resource.create.additional.secrets.title")
              .font(.inter(ofSize: 16, weight: .bold))
              .padding(.vertical, 20)
            VStack(spacing: 16) {
              withEach(\.mainForm.additionalOptions) { (additionalOption: MainFormViewModel.AdditionalOption) in
                self.additionalActionView(for: additionalOption)
              }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .backgroundColor(.passboltBackgroundGray)
            .cornerRadius(4)
          }
        }
      }
      .padding(.bottom, 120)
    }
    .overlay(alignment: .bottom) {
      VStack {
        Spacer()
        VStack(spacing: 0) {
          self.actionButtonView
            .padding(.vertical, 16)
        }
        .background(.white)

      }
      .ignoresSafeArea(.keyboard)
    }
  }

  @MainActor @ViewBuilder private func additionalActionView(
    for additionalOption: MainFormViewModel.AdditionalOption
  ) -> some View {
    switch additionalOption {
    case .addNote:
      CommonListRow(
        contentAction: self.controller.addNote,
        content: {
          ResourceFieldView(
            name: nil,
            content: {
              HStack(spacing: 16) {
                Image(named: .notes)
                Text(displayable: "resource.edit.field.add.note")
                  .font(.inter(ofSize: 14, weight: .semibold))
                  .foregroundColor(.passboltPrimaryText)
              }
            }
          )
        },
        accessory: DisclosureIndicatorImage.init
      )
    case .addPassword:
      CommonListRow(
        contentAction: self.controller.addPassword,
        content: {
          ResourceFieldView(
            name: nil,
            content: {
              HStack(spacing: 16) {
                Image(named: .key)
                Text(displayable: "resource.edit.field.add.password")
                  .font(.inter(ofSize: 14, weight: .semibold))
                  .foregroundColor(.passboltPrimaryText)
              }
            }
          )
        },
        accessory: DisclosureIndicatorImage.init
      )
    case .addTOTP:
      CommonListRow(
        contentAction: self.controller.createOrEditTOTP,
        content: {
          ResourceFieldView(
            name: nil,
            content: {
              HStack(spacing: 16) {
                Image(named: .otp)
                Text(displayable: "resource.create.advanced.add.otp")
                  .font(.inter(ofSize: 14, weight: .semibold))
                  .foregroundColor(.passboltPrimaryText)
              }
            }
          )
        },
        accessory: DisclosureIndicatorImage.init
      )
    }
  }

  @MainActor @ViewBuilder private var undefinedContentSectionView: some View {
    CommonListSection {
      CommonListRow {
        WarningView(message: "resource.form.undefined.content.warning")
      }
    }
  }

  /// Prepare the view for a specific field view model.
  @MainActor @ViewBuilder private func fieldView(for fieldModel: ResourceEditFieldViewModel) -> some View {
    switch fieldModel.value {
    case .plainShort(let state):
      FormTextFieldView(
        title: fieldModel.name,
        prompt: fieldModel.placeholder,
        mandatory: fieldModel.requiredMark,
        state: self.validatedOptionalBinding(
          to: \.validatedString,
          in: \.mainForm.fields[fieldModel.path],
          default: state,
          updating: { (newValue: String) in
            withAnimation {
              self.controller.set(newValue, for: fieldModel.path)
            }
          }
        )
      )
      .textInputAutocapitalization(.never)
      .autocorrectionDisabled()
      .padding(bottom: 8)
    case .list(let state):
      FormTextFieldView(
        title: fieldModel.name,
        prompt: fieldModel.placeholder,
        mandatory: fieldModel.requiredMark,
        state: self.validatedOptionalBinding(
          to: \.validatedString,
          in: \.mainForm.fields[fieldModel.path],
          default: state.first ?? .valid(""),
          updating: { (newValue: String) in
            withAnimation {
              self.controller.set(newValue, for: fieldModel.path)
            }
          }
        )
      )
      .textInputAutocapitalization(.never)
      .autocorrectionDisabled()
      .padding(bottom: 8)
    case .plainLong(let state):
      FormLongTextFieldView(
        title: fieldModel.name,
        prompt: fieldModel.placeholder,
        mandatory: fieldModel.requiredMark,
        encrypted: fieldModel.encryptedMark,
        state: self.validatedOptionalBinding(
          to: \.validatedString,
          in: \.mainForm.fields[fieldModel.path],
          default: state,
          updating: { (newValue: String) in
            withAnimation {
              self.controller.set(newValue, for: fieldModel.path)
            }
          }
        )
      )
      .focused($focusState)
      .toolbar {
        ToolbarItemGroup(placement: .keyboard) {
          HStack {
            Spacer()
            Button(
              displayable: "generic.done",
              action: {
                self.focusState.toggle()
              }
            )
            .foregroundStyle(.blue)
          }
        }
      }
      .textInputAutocapitalization(.sentences)
      .padding(bottom: 8)

    case .password(let state, let entropy):
      VStack(spacing: 4) {
        FormSecureTextFieldView(
          title: fieldModel.name,
          prompt: fieldModel.placeholder,
          mandatory: fieldModel.requiredMark,
          state: self.validatedOptionalBinding(
            to: \.validatedString,
            in: \.mainForm.fields[fieldModel.path],
            default: state,
            updating: { (newValue: String) in
              withAnimation {
                self.controller.set(newValue, for: fieldModel.path)
              }
            }
          ),
          accessory: {
            Button(
              action: {
                self.controller.generatePassword(for: fieldModel.path)
              },
              label: {
                Image(named: .dice)
                  .tint(.passboltPrimaryText)
                  .padding(12)
                  .backgroundColor(.passboltDivider)
                  .cornerRadius(4)
              }
            )
          }
        )

        EntropyView(entropy: entropy)
      }
      .padding(bottom: 8)

    case .selection(let state, let values):
      FormPickerFieldView(
        title: fieldModel.name,
        prompt: fieldModel.placeholder,
        mandatory: fieldModel.requiredMark,
        values: values,
        state: state,
        update: { (string: String) in
          withAnimation {
            self.controller.set(string, for: fieldModel.path)
          }
        }
      )
      .padding(bottom: 8)
    }
  }

  @MainActor @ViewBuilder private var actionButtonView: some View {
    PrimaryButton(
      title: self.controller.editsExisting
        ? "resource.form.update.button.title"
        : isInExtensionContext
          ? "resource.form.create.and.fill.button.title"
          : "resource.form.create.button.title",
      action: self.controller.sendForm
    )
    .padding(16)
  }
}
