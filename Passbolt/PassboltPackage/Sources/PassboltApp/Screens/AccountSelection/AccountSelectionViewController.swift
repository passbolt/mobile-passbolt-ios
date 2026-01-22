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

  internal struct Context {
    internal let isSignIn: Bool
  }

  internal struct ViewState: Equatable {
    internal let isSignIn: Bool
    internal var alert: AlertViewModel?
    internal var mode: Mode
    internal var accounts: Array<AccountSelectionCellItem>
    internal var canAddAccount: Bool {
      mode == .selection
    }
    internal var isRemovalMode: Bool {
      mode == .removal
    }
  }

  nonisolated let viewState: ViewStateSource<ViewState>

  private let navigationToAuthorization: NavigationToAuthorization
  private let navigationToAccountImportInfo: NavigationToAccountImportInfo
  private let navigationToHelp: NavigationToHelpMenu
  private let accounts: Accounts

  private let features: Features

  internal init(context: Context, features: Features) throws {
    self.features = features
    self.navigationToAuthorization = try features.instance()
    self.navigationToAccountImportInfo = try features.instance()
    let navigationToWelcomeScreen: NavigationToWelcomeScreen = try features.instance()
    let accounts: Accounts = try features.instance()
    self.accounts = accounts
    self.navigationToHelp = try features.instance()

    let session: Session = try features.instance()
    let mediaDownloadNetworkOperation: MediaDownloadNetworkOperation = try features.instance()

    self.viewState = .init(
      initial: .init(
        isSignIn: context.isSignIn,
        mode: .selection,
        accounts: .init()
      ),
      updateFrom: accounts.updates,
      update: { [navigationToWelcomeScreen] updateState, _ in
        let currentAccount: Account? = try? await session.currentAccount()
        var listItems: Array<AccountSelectionCellItem> = .init()
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
              .receive(on: DispatchQueue.main)
              .eraseToAnyPublisher(),
            listModePublisher: Empty().eraseToAnyPublisher()
          )
          listItems.append(item)
        }
        if listItems.isEmpty {
          try await navigationToWelcomeScreen.perform()
        }

        updateState { state in
          state.accounts = listItems
        }
      }
    )
  }

  internal func addAccount() async {
    await consumingErrors {
      try await navigationToAccountImportInfo.perform()
    }
  }

  internal func selectAccount(
    _ account: Account
  ) async throws {
    try await navigationToAuthorization.perform(
      context: account
    )
  }

  internal func toggleMode() async {
    withAnimation {
      viewState.update { state in
        state.mode = state.mode == .selection ? .removal : .selection
      }
    }
  }

  internal func removeAccount(_ account: Account) async {
    self.viewState.update(
      \.alert,
      to: .init(
        title: "account.selection.remove.alert.title",
        message: "account.selection.remove.alert.message",
        actions: [
          .cancel(id: .init(), title: .localized(key: .cancel)),
          .destructive(
            id: .init(),
            title: .localized(key: .remove),
            perform: { [weak self] in
              await self?.confirmedAccountRemoval(account)
            }
          ),
        ]
      )
    )
  }

  private func confirmedAccountRemoval(_ account: Account) async {
    await consumingErrors {
      try await accounts.removeAccount(account)
    }
  }

  internal func backButtonTapped() async {
    await consumingErrors {
      try features.ensureScope(SessionScope.self)
      let navigationToSelf: NavigationToManageAccounts = try features.instance()
      try await navigationToSelf.revert()
    }
  }

  internal func openHelp() async {
    await consumingErrors {
      try await navigationToHelp.perform(context: .init())
    }
  }
}

extension AccountSelectionViewController {

  internal enum Mode {

    case selection
    case removal
  }
}

#if DEBUG

extension AccountSelectionViewController {

  public static func previewDependencies(
    _ features: inout PreviewFeaturesContainer
  ) {
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
