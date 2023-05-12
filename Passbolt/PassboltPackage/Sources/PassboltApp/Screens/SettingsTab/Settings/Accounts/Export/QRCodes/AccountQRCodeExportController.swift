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

internal struct AccountQRCodeExportController {

  internal var viewState: MutableViewState<ViewState>

  internal var showCancelConfirmation: () -> Void
  internal var cancelTransfer: () -> Void
}

extension AccountQRCodeExportController: ViewController {

  internal struct ViewState: Hashable {

    internal var currentQRcode: Data
    internal var exitConfirmationAlertPresented: Bool
  }

  #if DEBUG
  internal nonisolated static var placeholder: Self {
    .init(
      viewState: .placeholder(),
      showCancelConfirmation: unimplemented0(),
      cancelTransfer: unimplemented0()
    )
  }
  #endif
}

// MARK: - Implementation

extension AccountQRCodeExportController {

  @MainActor fileprivate static func load(
    features: Features
  ) throws -> Self {
    try features.ensureScope(AccountTransferScope.self)

    let diagnostics: OSDiagnostics = features.instance()
    let asyncExecutor: AsyncExecutor = try features.instance()
    let navigation: DisplayNavigation = try features.instance()

    let accountExport: AccountChunkedExport = try features.instance()
    let qrCodeGenerator: QRCodeGenerator = features.instance()

    let viewState: MutableViewState<ViewState> = .init(
      initial: .init(
        currentQRcode: .init(),
        exitConfirmationAlertPresented: false
      )
    )

    asyncExecutor.scheduleIteration(
      over: accountExport.updates,
      catchingWith: diagnostics,
      failMessage: "Updates broken!"
    ) { (_) in
      switch accountExport.status() {
      case .part(_, let content):
        do {
          let qrCodePart: Data = try await qrCodeGenerator.generateQRCode(content)
          await viewState.update { state in
            state.currentQRcode = qrCodePart
          }
        }
        catch {
          await navigation
            .push(
              legacy: AccountTransferFailureViewController.self,
              context: error
            )
          throw CancellationError()  // don't continue observing
        }

      case .finished:
        await navigation
          .push(legacy: AccountTransferSuccessViewController.self)

      case .error(let error):
        await navigation
          .push(
            legacy: AccountTransferFailureViewController.self,
            context: error
          )
        throw CancellationError()  // don't continue observing

      case .uninitialized:
        await navigation
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

    nonisolated func showCancelConfirmation() {
      asyncExecutor.schedule(.reuse) {
        await viewState.update { (state: inout ViewState) in
          state.exitConfirmationAlertPresented = true
        }
      }
    }

    nonisolated func cancelTransfer() {
      accountExport.cancel()
    }

    return .init(
      viewState: viewState,
      showCancelConfirmation: showCancelConfirmation,
      cancelTransfer: cancelTransfer
    )
  }
}

extension FeaturesRegistry {

  internal mutating func useAccountQRCodeExportController() {
    use(
      .disposable(
        AccountQRCodeExportController.self,
        load: AccountQRCodeExportController.load(features:)
      ),
      in: AccountTransferScope.self
    )
  }
}
