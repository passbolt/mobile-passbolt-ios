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

internal struct ResourceNoteEditView: ControlledView {

  internal let controller: ResourceNoteEditViewController

  internal init(
    controller: ResourceNoteEditViewController
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
          Text(displayable: "resource.edit.field.add.note")
            .font(.inter(ofSize: 16, weight: .bold))
            .padding(.vertical, 20)
            .foregroundColor(.primary)
          VStack(alignment: .leading, spacing: 0) {
            FormLongTextFieldView(
              title: "resource.edit.note.content.title",
              prompt: nil,
              mandatory: true,
              encrypted: .none,
              state: self.validatedBinding(
                to: \.note,
                updating: { (newValue: String) in
                  withAnimation {
                    self.controller.update(newValue)
                  }
                }
              ),
              textFieldMinHeight: 100
            )

            Text(displayable: "resource.edit.note.content.disclaimer")
              .font(.inter(ofSize: 12, weight: .regular))
              .foregroundColor(.primary)
              .padding(.top, 8)
          }
          .padding(.horizontal, 16)
          .padding(.vertical, 8)
          .backgroundColor(.passboltBackgroundGray)
          .cornerRadius(4)

          SecondaryButton(
            title: "resource.edit.note.remove.button.title",
            iconName: .trash,
            action: {
              await self.controller.removeNote()
            }
          )
        }
      }
    }
  }
}
