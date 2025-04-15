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

internal struct ResourcePasswordEditView: ControlledView {

  internal let controller: ResourcePasswordEditViewController

  internal init(
    controller: ResourcePasswordEditViewController
  ) {
    self.controller = controller
  }

  internal var body: some View {
    self.content
      .frame(maxHeight: .infinity)
      .overlay(alignment: .bottom) {
        VStack {
          Spacer()
          VStack(spacing: 0) {
            PrimaryButton(
              title: "generic.apply",
              action: {
                await self.controller.apply()
              }
            )
          }
          .background(.background)
          .padding(16)
        }
        .ignoresSafeArea(.keyboard)
      }
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
  }

  private var content: some View {
    CommonList {
      CommonListSection {
        VStack(alignment: .leading, spacing: 8) {
          Text(displayable: "resource.edit.create.title")
            .font(.inter(ofSize: 16, weight: .bold))
            .padding(.vertical, 20)
            .foregroundColor(.primary)
          VStack(alignment: .leading, spacing: 0) {
            withEach(\.fields) { (field: ResourceEditFieldViewModel) in
              self.fieldView(for: field)
            }
          }
          .padding(.horizontal, 16)
          .padding(.vertical, 8)
          .backgroundColor(.passboltBackgroundGray)
          .cornerRadius(4)
        }
      }
    }
  }
  @MainActor @ViewBuilder private func fieldView(for fieldModel: ResourceEditFieldViewModel) -> some View {
    switch fieldModel.value {
    case .plainShort(let state):
      FormTextFieldView(
        title: fieldModel.name,
        prompt: fieldModel.placeholder,
        mandatory: fieldModel.requiredMark,
        state: self.validatedOptionalBinding(
          to: \.validatedString,
          in: \.fields[fieldModel.path],
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

    case .password(let state, let entropy):
      VStack(spacing: 4) {
        FormSecureTextFieldView(
          title: fieldModel.name,
          prompt: fieldModel.placeholder,
          mandatory: fieldModel.requiredMark,
          state: self.validatedOptionalBinding(
            to: \.validatedString,
            in: \.fields[fieldModel.path],
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

    case _:
      EmptyView()
    }
  }
}
