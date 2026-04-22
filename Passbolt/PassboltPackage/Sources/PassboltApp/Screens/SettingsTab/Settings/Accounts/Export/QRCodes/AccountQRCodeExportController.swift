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

  private let accountExport: AccountChunkedExport
  private let qrCodeGenerator: QRCodeGenerator

  internal init(
    context: Void,
    features: Features
  ) throws {
    try features.ensureScope(AccountTransferScope.self)
    self.accountExport = try features.instance()
    self.qrCodeGenerator = features.instance()

    let navigationToAccountExportInfo: NavigationToAccountExportInfo = try features.instance()
    let navigationToResult: NavigationToGenericResult = try features.instance()
    let navigationToAccountAuth: NavigationToAccountExportAuthorization = try features.instance()

    func handle(error: TheError) async {
      await consumingErrors {
        try await navigationToResult.perform(
          context: .init(
            icon: .failureMark,
            title: "generic.error",
            message: error.displayableMessage,
            buttonTitle: "generic.try.again",
            buttonAction: { [navigationToAccountAuth] in
              try await navigationToAccountAuth.revert()
            }
          )
        )
      }
    }

    self.viewState = .init(
      initial: .init(
        currentQRcode: .init()
      ),
      updateFrom: self.accountExport.updates,
      update: { [navigationToResult, accountExport, qrCodeGenerator] (updateState, _) in
        switch accountExport.status() {
        case .part(_, let content):
          do {
            let qrCodePart: Data = try qrCodeGenerator.generateQRCode(content)
            updateState { (viewState: inout ViewState) in
              viewState.currentQRcode = qrCodePart
            }
          }
          catch {
            await handle(error: error.asTheError())
          }

        case .finished:
          try await navigationToResult.perform(
            context: .init(
              icon: .successMark,
              title: "transfer.account.result.success.title",
              message: "",
              buttonTitle: "transfer.account.export.exit.success.button",
              buttonAction: {
                try await navigationToAccountExportInfo.revert()
              }
            )
          )

        case .error(let error):
          await handle(error: error.asTheError())

        case .uninitialized:
          await handle(
            error:
              InternalInconsistency
              .error(
                "Account export used without initialization."
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
    internal var alert: AlertViewModel?
  }
}

extension AccountQRCodeExportController {

  internal func showCancelConfirmation() {
    self.viewState.update(
      \.alert,
      to: .init(
        title: "transfer.account.exit.confirmation.title",
        message: "transfer.account.exit.confirmation.message",
        actions: [
          .cancel(id: .init(), title: .localized(key: .cancel)),
          .destructive(
            id: .init(),
            title: "transfer.account.export.exit.confirmation.confirm.button.title",
            perform: { [weak self] in
              await self?.cancelTransfer()
            }
          ),
        ]
      )
    )
  }

  internal func cancelTransfer() async {
    self.accountExport.cancel()
  }
}
