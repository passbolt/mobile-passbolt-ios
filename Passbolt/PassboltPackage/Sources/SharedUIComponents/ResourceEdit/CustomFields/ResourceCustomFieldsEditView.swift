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

internal struct ResourceCustomFieldsEditView: ControlledView {

  internal let controller: ResourceCustomFieldsEditViewController

  @FocusState private var focusState

  internal init(
    controller: ResourceCustomFieldsEditViewController
  ) {
    self.controller = controller
  }

  internal var body: some View {
    self.content
      .frame(maxHeight: .infinity)
      .navigationTitle(
        displayable: self.controller.editsExisting
          ? "resource.edit.title"
          : "resource.edit.create.title"
      )
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
          Text(displayable: "resource.edit.customFields.title")
            .font(.inter(ofSize: 16, weight: .bold))
            .padding(.vertical, 20)
            .padding(.top, 20)
            .foregroundColor(.primary)

          whenFalse(\.customFields.isEmpty) {
            VStack(alignment: .leading, spacing: 20) {
              withEach(\.customFields) { customField in
                VStack(alignment: .leading, spacing: 4) {
                  Text(customField.name)
                    .text(
                      .leading,
                      lines: .none,
                      font: .inter(
                        ofSize: 14,
                        weight: .bold
                      ),
                      color: .passboltPrimaryText
                    )
                  switch customField.value {
                  case .valid(let value):
                    Text(value)
                      .text(
                        .leading,
                        lines: .none,
                        font: .inter(
                          ofSize: 14,
                          weight: .regular
                        ),
                        color: .passboltSecondaryText
                      )
                  case .invalid:
                    Text(displayable: "resource.edit.customFields.error.invalid")
                      .text(
                        .leading,
                        lines: .none,
                        font: .interItalic(
                          ofSize: 14,
                          weight: .regular
                        ),
                        color: .passboltSecondaryRed
                      )
                  }
                }
              }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .backgroundColor(.passboltBackgroundGray)
            .cornerRadius(4)
          }
          HStack {
            Spacer()
            Text(displayable: "resource.edit.customFields.description")
              .text(
                .leading,
                lines: .none,
                font: .inter(
                  ofSize: 14,
                  weight: .regular
                ),
                color: .passboltSecondaryText
              )
            Spacer()
          }
          .padding(.vertical, 16)
        }
        .padding(.bottom, 96)
      }
    }
  }
}
