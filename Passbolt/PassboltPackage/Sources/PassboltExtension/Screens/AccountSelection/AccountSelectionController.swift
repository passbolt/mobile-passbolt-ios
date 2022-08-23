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

import Accounts
import Display
import Session
import SharedUIComponents
import UIComponents

internal struct AccountSelectionController {

  internal var accountsPublisher: @MainActor () -> AnyPublisher<Array<AccountSelectionListItem>, Never>
  internal var screenMode: @MainActor () -> AccountSelectionController.Mode
  internal var selectAccount: @MainActor (Account) -> Void
  internal var closeExtension: @MainActor () -> Void
}

extension AccountSelectionController {

  internal enum Mode {

    case switchAccount
    case signIn
  }
}

extension AccountSelectionController: UIController {

  internal typealias Context = AccountSelectionController.Mode

  internal static func instance(
    in context: Context,
    with features: FeatureFactory,
    cancellables: Cancellables
  ) async throws -> AccountSelectionController {
    let navigationTree: NavigationTree = features.instance()
    let autofillContext: AutofillExtensionContext = features.instance()
    let accounts: Accounts = try await features.instance()
    let session: Session = try await features.instance()

    func accountsPublisher() -> AnyPublisher<Array<AccountSelectionListItem>, Never> {
      accounts
        .updates
        .map { () -> Array<AccountSelectionListItem> in
          let currentAccount: Account? = try? await session.currentAccount()
          var listItems: Array<AccountSelectionListItem> = .init()
          for storedAccount in accounts.storedAccounts() {
            let accountDetails: AccountDetails = try await features.instance(context: storedAccount)
            let accountWithProfile: AccountWithProfile = try accountDetails.profile()

            let item: AccountSelectionCellItem = AccountSelectionCellItem(
              account: accountWithProfile.account,
              title: accountWithProfile.label,
              subtitle: accountWithProfile.username,
              isCurrentAccount: storedAccount == currentAccount,
              imagePublisher:
                Just(Void())
                .asyncMap {
                  try? await accountDetails.avatarImage()
                }
                .eraseToAnyPublisher(),
              listModePublisher: Empty().eraseToAnyPublisher()
            )

            listItems.append(.account(item))
          }
          return listItems
        }
        .asPublisher()
    }

    func screenMode() -> AccountSelectionController.Mode {
      context
    }

    @MainActor func selectAccount(
      _ account: Account
    ) {
      Task {
        await navigationTree.push(
          AuthorizationViewController.self,
          context: account,
          using: features
        )
      }
    }

    @MainActor func closeExtension() {
      autofillContext.cancelAndCloseExtension()
    }

    return Self(
      accountsPublisher: accountsPublisher,
      screenMode: screenMode,
      selectAccount: selectAccount,
      closeExtension: closeExtension
    )
  }
}
