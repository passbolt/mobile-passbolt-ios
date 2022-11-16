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
import UIComponents

internal final class TransferSignInExitConfirmationViewController:
  AlertViewController<TransferSignInExitConfirmationController>, UIComponent
{

  internal func setup() {
    mut(self) {
      .combined(
        .title(.localized(key: "transfer.account.exit.confirmation.title")),
        .message(.localized(key: "transfer.account.exit.confirmation.message")),
        .action(
          .localized(key: "transfer.account.exit.confirmation.cancel.button.title"),
          style: .cancel,
          accessibilityIdentifier: "alert.button.cancel",
          handler: {}
        ),
        .action(
          .localized(key: "transfer.account.exit.confirmation.confirm.button.title"),
          style: .destructive,
          accessibilityIdentifier: "alert.button.confirm",
          handler: { [weak self] in
            self?.controller.exit()
          }
        )
      )
    }
  }
}

internal struct TransferSignInExitConfirmationController {

  internal var exit: @MainActor () -> Void
}

extension TransferSignInExitConfirmationController: UIController {

  internal typealias Context = Void

  internal static func instance(
    in context: Context,
    with features: FeatureFactory,
    cancellables: Cancellables
  ) async throws -> Self {
    let accountTransfer: AccountTransfer = try await features.instance()

    func exit() {
      accountTransfer.cancelTransfer()
    }

    return Self(
      exit: exit
    )
  }
}
