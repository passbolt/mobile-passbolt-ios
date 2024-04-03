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

import AccountSetup
import Display
import FeatureScopes
import OSFeatures
import SharedUIComponents

internal final class AccountQRCodeExportController: ViewController {

  internal nonisolated let viewState: ViewStateSource<ViewState>

  private let navigation: DisplayNavigation
  private let accountExport: AccountChunkedExport
  private let qrCodeGenerator: QRCodeGenerator

  internal init(
    context: Void,
    features: Features
  ) throws {
    try features.ensureScope(AccountTransferScope.self)

    self.navigation = try features.instance()
    self.accountExport = try features.instance()
    self.qrCodeGenerator = features.instance()

    self.viewState = .init(
      initial: .init(
        currentQRcode: .init(),
        exitConfirmationAlertPresented: false
      ),
      updateFrom: self.accountExport.updates,
      update: { [navigation, accountExport, qrCodeGenerator] (updateState, _) in
        switch accountExport.status() {
        case .part(_, let content):
          do {
            let qrCodePart: Data = try await qrCodeGenerator.generateQRCode(content)
            await updateState { (viewState: inout ViewState) in
              viewState.currentQRcode = qrCodePart
            }
          }
          catch {
            try? await navigation
              .push(
                OperationResultControlledView.self,
                controller: OperationResultViewController(
                  context: OperationResultConfiguration(
                    for: error.asTheError(),
                    confirmation: { [navigation] in
                      await navigation.pop(to: TransferInfoScreenViewController.self)
                    }
                  ),
                  features: features
                )
              )
          }

        case .finished:
          try? await navigation
            .push(
              OperationResultControlledView.self,
              controller: OperationResultViewController(
                context: OperationResultConfiguration(
                  image: .successMark,
                  title: "transfer.account.result.success.title",
                  actionLabel: "transfer.account.export.exit.success.button",
                  confirmation: { [navigation] in
                    await navigation.popToRoot()
                  }
                ),
                features: features
              )
            )

        case .error(let error):
          try? await navigation
            .push(
              OperationResultControlledView.self,
              controller: OperationResultViewController(
                context: OperationResultConfiguration(
                  for: error.asTheError(),
                  confirmation: { [navigation] in
                    await navigation.pop(to: TransferInfoScreenViewController.self)
                  }
                ),
                features: features
              )
            )

        case .uninitialized:
          try? await navigation
            .push(
              OperationResultControlledView.self,
              controller: OperationResultViewController(
                context: OperationResultConfiguration(
                  for:
                    InternalInconsistency
                    .error(
                      "Account export used without initialization."
                    ),
                  confirmation: { [navigation] in
                    await navigation.pop(to: TransferInfoScreenViewController.self)
                  }
                ),
                features: features
              )
            )
        }
      }
    )
  }
}

extension AccountQRCodeExportController {

  internal struct ViewState: Equatable {

    internal var currentQRcode: Data
    internal var exitConfirmationAlertPresented: Bool
  }
}

extension AccountQRCodeExportController {

  @MainActor internal func showCancelConfirmation() {
    self.viewState.update { (state: inout ViewState) in
      state.exitConfirmationAlertPresented = true
    }
  }

  @MainActor internal func cancelTransfer() {
    self.accountExport.cancel()
  }
}
