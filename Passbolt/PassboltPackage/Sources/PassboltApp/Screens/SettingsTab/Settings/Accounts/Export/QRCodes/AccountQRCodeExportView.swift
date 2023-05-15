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

internal struct AccountQRCodeExportView: ControlledView {

  @EnvironmentObject var displayViewBridgeHandle: DisplayViewBridgeHandle<Self>
  private let controller: AccountQRCodeExportController

  internal init(
    controller: AccountQRCodeExportController
  ) {
    self.controller = controller
  }

  internal var body: some View {
    WithViewState(from: self.controller) { (state: ViewState) in
      ScreenView(
        title: .localized("transfer.account.title"),
        contentView: {
          contentView(using: state)
        }
      )
    }
    .onAppear {
      self.displayViewBridgeHandle.setNavigationBackButton(hidden: true)
    }
  }

  @ViewBuilder @MainActor private func contentView(
    using state: ViewState
  ) -> some View {
    VStack(alignment: .center) {
      Spacer()
      Image(data: state.currentQRcode)?
        .interpolation(.none)
        .resizable()
        .aspectRatio(contentMode: .fit)
        .accessibilityIdentifier("transfer.account.export.qrcode.image")
      Spacer()
      PrimaryButton(
        title: .localized("transfer.account.export.cancel.button"),
        style: .destructive,
        action: {
          controller.showCancelConfirmation()
        }
      )
      .accessibilityIdentifier("transfer.account.export.cancel.button")
    }
    .padding(16)
    .alert(
      presenting: self.controller
        .binding(to: \.exitConfirmationAlertPresented)
        .map(
          get: { (presented: Bool) -> ConfirmationAlertMessage? in
            if presented {
              return .init(
                title: .localized(key: "transfer.account.exit.confirmation.title"),
                message: .localized(key: "transfer.account.exit.confirmation.message"),
                destructive: true,
                confirmAction: self.controller.cancelTransfer,
                confirmLabel: .localized(key: "transfer.account.export.exit.confirmation.confirm.button.title")
              )
            }
            else {
              return .none
            }
          },
          set: { (message: ConfirmationAlertMessage?) -> Bool in
            message != .none
          }
        )
    )
  }
}
