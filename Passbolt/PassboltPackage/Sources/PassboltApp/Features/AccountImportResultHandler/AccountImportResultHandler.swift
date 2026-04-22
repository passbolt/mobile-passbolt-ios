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

extension AccountImportResultHandler {

  @MainActor internal static func load(
    using features: Features
  ) throws -> Self {
    let navigationToResultView: NavigationToGenericResult = try features.instance()
    let navigationToAccountSelection: NavigationToAccountSelection = try features.instance()
    let accountTransfer: AccountImport = try features.instance()
    let navigationToTransferSignIn: NavigationToTransferSignIn = try features.instance()

    @Sendable func createFailureViewContext(
      title: DisplayableString,
      icon: ImageNameConstant
    ) -> GenericResultViewController.Context {
      .init(
        icon: icon,
        title: title,
        buttonTitle: .localized(key: .continue),
        buttonAction: {
          try await navigationToAccountSelection.perform(context: .init(isSignIn: true))
        }
      )
    }

    @Sendable func handleImportError(error: Error) {
      Task {
        let title: DisplayableString?
        var icon: ImageNameConstant = .failureMark

        switch error {
        case is AccountKitImportFailure:
          title = "error.account.kit.fail.to.import"
        case is AccountKitImportInvalidSignature:
          title = "error.account.kit.signature.verification"
        case is AccountKitAccountAlreadyExist:
          title = "transfer.account.result.already.linked.title"
          icon = .duplicateMark
        default:
          // If the error type is not recognized, do not perform any navigation
          return
        }
        if let title {
          let context = createFailureViewContext(title: title, icon: icon)
          try await navigationToResultView.perform(context: context)
        }
      }
    }

    @Sendable func handleImportResult(
      result: Result<AccountTransferData, Error>
    ) async throws {
      switch result {
      case .success(let accountDataTransfer):
        accountTransfer.importAccountByPayload(accountDataTransfer)
        try await navigationToResultView.perform(
          context: .init(
            icon: .successMark,
            title: "transfer.account.kit.result.success.title",
            message: "",
            buttonTitle: .localized(key: .continue),
            buttonAction: {
              try await navigationToTransferSignIn.perform()
            }
          )
        )
      case .failure(let error):
        handleImportError(error: error)
      }
    }

    return .init(handleImportResult: handleImportResult(result:))
  }
}

extension FeaturesRegistry {

  internal mutating func usePassboltAccountImportResultHandler() {
    self.use(
      .lazyLoaded(
        AccountImportResultHandler.self,
        load: AccountImportResultHandler.load(using:)
      ),
      in: AccountTransferScope.self
    )
  }
}
