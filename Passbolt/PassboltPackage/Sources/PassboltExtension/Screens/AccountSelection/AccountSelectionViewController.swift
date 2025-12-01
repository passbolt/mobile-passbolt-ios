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
import NetworkOperations
import Session
import SharedUIComponents

internal final class AccountSelectionViewController: ViewController {

  internal typealias Context = Mode

  internal struct ViewState: Equatable {
    internal let mode: Mode
    internal var rows: Array<AccountSelectionListItem>
  }

  nonisolated let viewState: ViewStateSource<ViewState>

  private let autofillExtensionContext: AutofillExtensionContext
  private let navigationToAuthorization: NavigationToAuthorization

  internal init(context: Context, features: Features) throws {

    self.autofillExtensionContext = features.instance()
    self.navigationToAuthorization = try features.instance()

    let accounts: Accounts = try features.instance()
    let session: Session = try features.instance()
    let mediaDownloadNetworkOperation: MediaDownloadNetworkOperation = try features.instance()

    self.viewState = .init(
      initial: .init(
        mode: context,
        rows: .init()
      ),
      updateFrom: accounts.updates,
      update: { updateState, _ in
        let currentAccount: Account? = try? await session.currentAccount()
        var listItems: Array<AccountSelectionListItem> = .init()
        for storedAccount: AccountWithProfile in accounts.storedAccounts() {
          let item: AccountSelectionCellItem = AccountSelectionCellItem(
            account: storedAccount.account,
            title: storedAccount.label,
            subtitle: storedAccount.username,
            isCurrentAccount: storedAccount.account == currentAccount,
            imagePublisher:
              Just(Void())
              .asyncMap {
                try? await mediaDownloadNetworkOperation.execute(storedAccount.avatarImageURL)
              }
              .eraseToAnyPublisher(),
            listModePublisher: Empty().eraseToAnyPublisher()
          )

          listItems.append(.account(item))
          updateState { state in
            state.rows = listItems
          }
        }
      }
    )
  }

  internal func closeExtension() {
    autofillExtensionContext.cancelAndCloseExtension()
  }

  internal func selectAccount(
    _ account: Account
  ) async throws {
    try await navigationToAuthorization.perform(
      context: account
    )
  }
}

extension AccountSelectionViewController {

  internal enum Mode {

    case switchAccount
    case signIn
  }
}

#if DEBUG

extension AccountSelectionViewController {

  public static func previewDependencies(
    _ features: inout PreviewFeaturesContainer
  ) {
    features.usePlaceholder(for: AutofillExtensionContext.self)
    features.patch(
      \Accounts.storedAccounts,
      with: {
        [
          .init(account: .ada, profile: .ada),
          .init(account: .betty, profile: .betty),
        ]
      }
    )
    features.patch(
      \Accounts.updates,
      with: Constant(()).asAnyUpdatable()
    )
    features.patch(
      \NavigationToAuthorization.mockPerform,
      with: { _, _ in }
    )

    features.patch(
      \Session.currentAccount,
      with: {
        .init(
          localID: .empty,
          domain: "passbolt.local",
          userID: .init(),
          fingerprint: .empty
        )
      }
    )
    features.patch(
      \MediaDownloadNetworkOperation.execute,
      with: { _ in Data() }
    )
  }
}

#endif
