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

internal struct AccountExportInfoView: ControlledView {

  internal let controller: AccountExportInfoViewController

  internal init(controller: AccountExportInfoViewController) {
    self.controller = controller
  }

  internal var body: some View {
    withAlert(
      \.alert,
      content: { self.content }
    )
  }

  private var content: some View {
    TransferInfoStepsView(
      title: "",
      steps: [
        step1,
        step2,
        step3,
        step4,
      ]
    )
    .overlay(alignment: .bottom) {
      PrimaryButton(
        title: "transfer.account.export.scan.qr.button",
        action: self.controller.start
      )
      .accessibilityIdentifier("transfer.account.export.scan.qr.button")
      .padding(.bottom, 16)
    }
    .padding(.top, 16)
    .padding(.horizontal, 16)
    .navigationBarTitleDisplayMode(.inline)
    .navigationTitle(displayable: "transfer.account.title")
    .navigationBarBackButtonHidden()
    .toolbar {
      ToolbarItem(placement: .topBarLeading) {
        BackButton(action: self.controller.back)
      }
    }
  }

  private var step1: TransferInfoStepsView.Step {
    .displayable(
      .localized(key: "transfer.account.export.info.step.first"),
      font: .inter(
        ofSize: 14,
        weight: .regular
      ),
      color: .secondaryText
    )
  }

  private var step2: TransferInfoStepsView.Step {
    .displayable(
      .localized(key: "transfer.account.export.info.step.second"),
      font: .inter(
        ofSize: 14,
        weight: .regular
      ),
      color: .secondaryText
    )
  }

  private var step3: TransferInfoStepsView.Step {
    .displayable(
      .localized(key: "transfer.account.export.info.step.third"),
      font: .inter(
        ofSize: 14,
        weight: .regular
      ),
      color: .secondaryText
    )
  }

  private var step4: TransferInfoStepsView.Step {
    .displayable(
      .localized(key: "transfer.account.export.info.step.fourth"),
      font: .inter(
        ofSize: 14,
        weight: .regular
      ),
      color: .secondaryText
    )
  }
}
