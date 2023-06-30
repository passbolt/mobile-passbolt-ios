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

  private let controller: ResourceEditViewController
  @State private var discardFormAlertVisible: Bool

  public init(
    controller: ResourceEditViewController
  ) {
    self.controller = controller
    self.discardFormAlertVisible = false
  }

  public var body: some View {
    WithSnackBarMessage(
      from: self.controller
    ) {
      self.contentView
    }
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
          regularLabel: {
            Text(displayable: "resource.edit.exit.confirmation.button.revert.title")
          }
        )
      }
    )
    .navigationBarBackButtonHidden()
    .toolbar {  // replace back button
      ToolbarItemGroup(placement: .navigationBarLeading) {
        BackButton(
          action: {
            if self.controller.editedFields.get().isEmpty {
              await self.controller.discardForm()
            }
            else {
              self.discardFormAlertVisible = true
            }
          }
        )
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
    VStack(spacing: 8) {
      CommonList {
        WithViewState(
          from: self.controller,
          at: \.containsUndefinedFields
        ) { (containsUndefinedFields: Bool) in
          if containsUndefinedFields {
            self.undefinedContentSectionView
          }
        }
        self.fieldsSectionsView
        CommonListSpacer(minHeight: 16)
      }
      self.actionButtonView
    }
  }

  @MainActor @ViewBuilder private var undefinedContentSectionView: some View {
    CommonListSection {
      CommonListRow {
        WarningView(message: "resource.form.undefined.content.warning")
      }
    }
  }

  @MainActor @ViewBuilder private var fieldsSectionsView: some View {
    CommonListSection {
      WithEachViewState(
        from: self.controller,
        at: \.fields.values
      ) { (fieldModel: ResourceEditFieldViewModel) in
        CommonListRow(
          content: {
            switch fieldModel.value {
            case .plainShort(let state):
              FormTextFieldView(
                title: fieldModel.name,
                prompt: fieldModel.placeholder,
                mandatory: fieldModel.requiredMark,
                state: state,
                update: { (string: String) in
                  withAnimation {
                    self.controller.set(string, for: fieldModel.path)
                  }
                }
              )
              .padding(bottom: 8)

            case .plainLong(let state):
              FormLongTextFieldView(
                title: fieldModel.name,
                prompt: fieldModel.placeholder,
                mandatory: fieldModel.requiredMark,
                state: state,
                update: { (string: String) in
                  withAnimation {
                    self.controller.set(string, for: fieldModel.path)
                  }
                }
              )
              .padding(bottom: 8)

            case .password(let state, let entropy):
              VStack(spacing: 4) {
                FormSecureTextFieldView(
                  title: fieldModel.name,
                  prompt: fieldModel.placeholder,
                  mandatory: fieldModel.requiredMark,
                  state: state,
                  update: { (string: String) in
                    withAnimation {
                      self.controller.set(string, for: fieldModel.path)
                    }
                  },
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
        )
      }
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
