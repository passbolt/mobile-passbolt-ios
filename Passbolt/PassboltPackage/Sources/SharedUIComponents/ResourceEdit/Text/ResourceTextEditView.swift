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

internal struct ResourceTextEditView: ControlledView {

  internal let controller: ResourceTextEditViewController

  @FocusState private var focusState

  internal init(
    controller: ResourceTextEditViewController
  ) {
    self.controller = controller
  }

  internal var body: some View {
    self.content
      .overlay(alignment: .bottom) {
        VStack {
          Spacer()
          VStack(spacing: 16) {
            when(\.showAction) {
              with(\.action) { action in
                SecondaryButton(
                  title: action?.title ?? "",
                  iconName: action?.icon,
                  action: {
                    await self.controller.executeAction()
                  }
                )
              }
            }
            PrimaryButton(
              title: "generic.apply",
              action: {
                await self.controller.apply()
              }
            )
          }
          .padding(16)
          .background(.background)
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
          with(\.title) { title in
            Text(displayable: title)
              .font(.inter(ofSize: 16, weight: .bold))
              .padding(.vertical, 20)
              .foregroundColor(.primary)
          }
          VStack(alignment: .leading, spacing: 0) {
            with(\.fieldName) { fieldName in
              FormLongTextFieldView(
                title: fieldName,
                prompt: nil,
                mandatory: false,
                encrypted: .none,
                state: self.validatedBinding(
                  to: \.text,
                  updating: { (newValue: String) in
                    withAnimation {
                      self.controller.update(newValue)
                    }
                  }
                ),
                textFieldMinHeight: 100,
                textFieldMaxHeight: 280
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
            }
            with(\.description) { description in
              Text(displayable: description)
                .font(.inter(ofSize: 12, weight: .regular))
                .foregroundColor(.primary)
                .padding(.top, 8)
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
}
