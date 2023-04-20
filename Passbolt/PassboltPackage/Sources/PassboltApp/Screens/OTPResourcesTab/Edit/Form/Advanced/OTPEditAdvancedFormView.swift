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

  private let controller: OTPEditAdvancedFormController

  internal init(
    controller: OTPEditAdvancedFormController
  ) {
    self.controller = controller
  }

  internal var body: some View {
    WithViewState(
      from: self.controller,
      at: \.snackBarMessage
    ) { (message: SnackBarMessage?) in
      VStack(spacing: 0) {
        ScrollView {
          VStack(spacing: 16) {
            WarningView(message: "otp.edit.form.edit.advanced.warning")
            self.periodField
            self.digitsField
            self.algorithmField
          }
        }

        Spacer()

        self.applyButton
      }
      .padding(16)
      .snackBarMessage(
        presenting: self.controller
          .binding(
            to: \.snackBarMessage
          )
      )
      .frame(maxHeight: .infinity)
    }
    .navigationTitle(
      displayable: "otp.edit.form.edit.advanced.title"
    )
  }

  @MainActor @ViewBuilder internal var periodField: some View {
    WithViewState(
      from: self.controller,
      at: \.period
    ) { _ in
      HStack {
        FormTextFieldView(
          title: "otp.edit.form.field.period.title",
          mandatory: true,
          text: self.controller
            .validatedBinding(
              to: \.period,
              updating: { (string: String) in
                self.controller.setPeriod(string)
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
    ) { _ in
      HStack {
        FormTextFieldView(
          title: "otp.edit.form.field.digits.title",
          mandatory: true,
          text: self.controller
            .validatedBinding(
              to: \.digits,
              updating: { (string: String) in
                self.controller.setDigits(string)
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
    ) { (_: Validated<HOTPAlgorithm>) in
      FormPickerFieldView<HOTPAlgorithm>(
        title: "otp.edit.form.field.algorithm.title",
        mandatory: true,
        values: [HOTPAlgorithm.sha1, .sha256, .sha512],
        selected: self.controller
          .validatedBinding(
            to: \.algorithm,
            updating: {
              self.controller.setAlgorithm($0)
            }
          )
      )
    }
  }

  @MainActor @ViewBuilder internal var applyButton: some View {
    PrimaryButton(
      title: "otp.edit.form.apply.button.title",
      action: self.controller.applyChanges
    )
  }
}

extension HOTPAlgorithm: FormPickerFieldValue {

  public var id: Self { self }

  public var fromPickerFieldLabel: String {
    self.rawValue
  }
}
