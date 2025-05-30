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

internal struct ResourceURIEditView: ControlledView {

  internal let controller: ResourceURIEditViewController

  @FocusState private var focusState

  internal init(
    controller: ResourceURIEditViewController
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
          .padding(16)
          .background(.background)
        }
        .ignoresSafeArea(.keyboard)
      }
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
          Text(displayable: "resource.edit.uris.title")
            .font(.inter(ofSize: 16, weight: .bold))
            .padding(.vertical, 20)
            .padding(.top, 20)
            .foregroundColor(.primary)

          VStack(alignment: .leading, spacing: 0) {
            Text(displayable: "resource.edit.uris.main.uri.title")
              .font(.inter(ofSize: 12, weight: .bold))
              .padding(.vertical, 20)
              .foregroundColor(.primary)
            with(\.mainURI) { mainURI in
              FormTextFieldView(
                prompt: "resource.edit.uris.main.uri.placeholder",
                state: self.validatedBinding(
                  to: \.mainURI,
                  updating: { (newValue: String) in
                    withAnimation {
                      self.controller.setMainURI(newValue)
                    }
                  }
                )
              )
              .textInputAutocapitalization(.never)
              .autocorrectionDisabled()
              .padding(bottom: 8)
            }
            Text(displayable: "resource.edit.uris.additional.uris.title")
              .font(.inter(ofSize: 12, weight: .bold))
              .padding(.vertical, 20)
              .foregroundColor(.primary)
            VStack(spacing: 20) {
              withEach(\.additionalURIs) { additionalURI in
                FormTextFieldView(
                  prompt: "resource.edit.uris.additional.uri.placeholder",
                  state: self.validatedOptionalBinding(
                    to: \.uri,
                    in: \.additionalURIs[additionalURI.id],
                    default: .valid(""),
                    updating: { (newValue: String) in
                      withAnimation {
                        self.controller.set(newValue, for: additionalURI.id)
                      }
                    }
                  ),
                  accessory: {
                    Button(
                      action: {
                        self.controller.removeURI(withId: additionalURI.id)
                      },
                      label: {
                        Image(named: .trash)
                          .tint(.passboltPrimaryText)
                          .padding(12)
                          .backgroundColor(.passboltDivider)
                          .cornerRadius(4)
                      }
                    )
                  }
                )
              }
            }
          }
          .padding(.horizontal, 16)
          .padding(.vertical, 8)
          .backgroundColor(.passboltBackgroundGray)
          .cornerRadius(4)
          HStack {
            Spacer()
            AsyncButton(
              action: {
                await self.controller.addURI()
              },
              label: {
                HStack(spacing: 10) {
                  Text(displayable: "resource.edit.uris.additional.uri.add")
                    .foregroundColor(.passboltPrimaryText)
                  Image(named: .plus)
                    .tint(.passboltPrimaryText)
                }
                .padding(12)
                .backgroundColor(.passboltDivider)
                .cornerRadius(4)
              }
            )
            Spacer()
          }
          .padding(.top, 16)
          .padding(.bottom, 96)
        }
      }
    }
  }
}
