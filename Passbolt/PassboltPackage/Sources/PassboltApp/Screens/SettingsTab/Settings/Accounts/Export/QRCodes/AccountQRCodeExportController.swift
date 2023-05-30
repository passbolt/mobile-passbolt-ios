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
import OSFeatures

internal final class AccountQRCodeExportController: ViewController {

  internal nonisolated let viewState: MutableViewState<ViewState>

  private let diagnostics: OSDiagnostics
  private let asyncExecutor: AsyncExecutor
  private let navigation: DisplayNavigation
  private let accountExport: AccountChunkedExport
  private let qrCodeGenerator: QRCodeGenerator

  internal init(
    context: Void,
    features: Features
  ) throws {
    try features.ensureScope(AccountTransferScope.self)

    self.diagnostics = features.instance()
    self.asyncExecutor = try features.instance()
    self.navigation = try features.instance()
    self.accountExport = try features.instance()
    self.qrCodeGenerator = features.instance()

    self.viewState = .init(
      initial: .init(
        currentQRcode: .init(),
        exitConfirmationAlertPresented: false
      )
    )

    self.asyncExecutor.scheduleIteration(
      over: self.accountExport.updates,
      catchingWith: self.diagnostics,
      failMessage: "Updates broken!"
    ) { [unowned self] (_) in
      switch self.accountExport.status() {
      case .part(_, let content):
        do {
          let qrCodePart: Data = try await self.qrCodeGenerator.generateQRCode(content)
          await viewState.update { state in
            state.currentQRcode = qrCodePart
          }
        }
        catch {
          await self.navigation
            .push(
              legacy: AccountTransferFailureViewController.self,
              context: error
            )
          throw CancellationError()  // don't continue observing
        }

      case .finished:
        await self.navigation
          .push(legacy: AccountTransferSuccessViewController.self)

      case .error(let error):
        await self.navigation
          .push(
            legacy: AccountTransferFailureViewController.self,
            context: error
          )
        throw CancellationError()  // don't continue observing

      case .uninitialized:
        await self.navigation
          .push(
            legacy: AccountTransferFailureViewController.self,
            context:
              InternalInconsistency
              .error(
                "Account export used without initialization."
              )
          )
        throw CancellationError()  // don't continue observing
      }
    }
  }
}

extension AccountQRCodeExportController {

  internal struct ViewState: Hashable {

    internal var currentQRcode: Data
    internal var exitConfirmationAlertPresented: Bool
  }
}

extension AccountQRCodeExportController {

  nonisolated func showCancelConfirmation() {
    self.asyncExecutor.schedule(.reuse) { [unowned self] in
      await self.viewState.update { (state: inout ViewState) in
        state.exitConfirmationAlertPresented = true
      }
    }
  }

  nonisolated func cancelTransfer() {
    self.accountExport.cancel()
  }
}
