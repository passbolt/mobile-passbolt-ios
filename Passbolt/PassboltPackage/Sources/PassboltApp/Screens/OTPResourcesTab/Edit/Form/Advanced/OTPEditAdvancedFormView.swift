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

internal struct OTPEditAdvancedFormView: ControlledView {

  internal let controller: OTPEditAdvancedFormViewController

  internal init(
    controller: OTPEditAdvancedFormViewController
  ) {
    self.controller = controller
  }

  internal var body: some View {
    ScrollView {
      VStack(spacing: 16) {
        WarningView(message: "otp.edit.form.edit.advanced.warning")
        self.periodField
        self.digitsField
        self.algorithmField
      }
      .autocorrectionDisabled()
      .textInputAutocapitalization(.never)
    }
    .padding(16)
    .frame(maxHeight: .infinity)
    .navigationTitle(
      displayable: "otp.edit.form.edit.advanced.title"
    )
  }

  @MainActor @ViewBuilder internal var periodField: some View {
    WithViewState(
      from: self.controller,
      at: \.period
    ) { (state: Validated<String>) in
      HStack {
        FormTextFieldView(
          title: "otp.edit.form.field.period.title",
          mandatory: true,
          state: self.validatedBinding(
            to: \.period,
            updating: { (newValue: String) in
              withAnimation {
                self.controller.setPeriod(newValue)
              }
            }
          ),
          accessory: {
            Text(displayable: "otp.edit.form.field.period.label")
              .text(
                font: .inter(
                  ofSize: 14
                ),
                color: .passboltSecondaryText
              )
              .multilineTextAlignment(.leading)
              .frame(maxWidth: .infinity, alignment: .leading)
              .layoutPriority(1)
          }
        )
        .keyboardType(.numberPad)
      }
    }
  }

  @MainActor @ViewBuilder internal var digitsField: some View {
    WithViewState(
      from: self.controller,
      at: \.digits
    ) { (state: Validated<String>) in
      HStack {
        FormTextFieldView(
          title: "otp.edit.form.field.digits.title",
          mandatory: true,
          state: self.binding(
            to: \.digits,
            updating: { (newValue: Validated<String>) in
              withAnimation {
                self.controller.setDigits(newValue.value)
              }
            }
          ),
          accessory: {
            Text(displayable: "otp.edit.form.field.digits.label")
              .text(
                font: .inter(
                  ofSize: 14
                ),
                color: .passboltSecondaryText
              )
              .multilineTextAlignment(.leading)
              .frame(maxWidth: .infinity, alignment: .leading)
              .layoutPriority(1)
          }
        )
        .keyboardType(.numberPad)
      }
    }
  }

  @MainActor @ViewBuilder internal var algorithmField: some View {
    WithViewState(
      from: self.controller,
      at: \.algorithm
    ) { (state: Validated<HOTPAlgorithm?>) in
      FormPickerFieldView<HOTPAlgorithm>(
        title: "otp.edit.form.field.algorithm.title",
        mandatory: true,
        // TODO: those should be loaded from field specification
        values: HOTPAlgorithm.allCases,
        state: state,
        update: { (algorithm: HOTPAlgorithm) in
          self.controller.setAlgorithm(algorithm)
        }
      )
    }
  }
}

extension HOTPAlgorithm: FormPickerFieldValue {

  public var id: Self { self }

  public var fromPickerFieldLabel: String {
    self.rawValue
  }
}
