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
import NetworkOperations

internal final class AccountMenuViewController: ViewController {

  internal struct ViewState: Equatable {
    internal var currentUser: AccountData? = .none
    internal var otherAccounts: [AccountData] = .init()
  }

  nonisolated let viewState: ViewStateSource<ViewState>

  private let navigationToSelf: NavigationToAccountMenu
  private let navigationToAccountDetails: NavigationToAccountDetails
  private let navigationToManageAccounts: NavigationToManageAccounts
  private let navigationToAuthorization: NavigationToAuthorization
  private let session: Session

  internal init(context: (), features: Features) throws {
    let accounts: Accounts = try features.instance()

    let currentAccount: Account = try features.sessionAccount()
    let currentAccountDetails: AccountDetails = try features.instance()
    let profile: AccountWithProfile = try currentAccountDetails.profile()
    self.navigationToSelf = try features.instance()
    self.navigationToAccountDetails = try features.instance()
    self.navigationToManageAccounts = try features.instance()
    self.navigationToAuthorization = try features.instance()
    self.session = try features.instance()
    let mediaDownloadNetworkOperation: MediaDownloadNetworkOperation =
      try features.instance()

    self.viewState = .init(
      initial: .init(
        currentUser: .init(
          account: currentAccount,
          username: profile.label,
          email: profile.username,
          loadAvatarData: currentAccountDetails.avatarImage
        )
      ),
      updateFrom: accounts.updates,
      update: { update, _ in
        var otherAccounts: [AccountData] = .init()
        for storedAccount in accounts.storedAccounts()
        where storedAccount.account != currentAccount {  // skip current account
          otherAccounts.append(
            .init(
              account: storedAccount.account,
              username: storedAccount.label,
              email: storedAccount.username,
              loadAvatarData: {
                try await mediaDownloadNetworkOperation.execute(
                  storedAccount.avatarImageURL
                )
              }
            )
          )
        }
        update { state in
          state.otherAccounts = otherAccounts
        }
      }
    )
  }

  internal func dismiss() async {
    do {
      try await navigationToSelf.revert()
    }
    catch {
      error.logged(
        info: .message(
          "Navigation back from account menu failed!"
        )
      )
    }
  }

  internal func presentAccountDetails() async {
    do {
      try await navigationToSelf.revert()
      try await navigationToAccountDetails.perform()
    }
    catch {
      error.logged(
        info: .message(
          "Navigation to account details failed!"
        )
      )
    }
  }

  internal func signOut() async {
    await session.close(.none)
  }

  internal func presentAccountSwitch(
    account: Account
  ) async {
    do {
      try await navigationToSelf.revert()
      try await navigationToAuthorization.perform(context: account)
    }
    catch {
      error.logged(
        info: .message(
          "Navigation to account switch failed!"
        )
      )
    }
  }

  internal func presentManageAccounts() async {
    do {
      try await navigationToSelf.revert()
      try await navigationToManageAccounts.perform()
    }
    catch {
      error.logged(
        info: .message(
          "Navigation to manage accounts failed!"
        )
      )
    }
  }

  internal func onAccountTap(account: Account) async {
    do {
      try await navigationToSelf.revert()
      try await navigationToAuthorization.perform(context: account)
    }
    catch {
      error.logged(
        info: .message(
          "Navigation to account switch failed!"
        )
      )
    }
  }
}

extension AccountMenuViewController {

  internal struct AccountData: Equatable, Identifiable {

    internal var id: Account.LocalID {
      account.localID
    }
    internal var account: Account
    internal var username: String
    internal var email: String
    internal var loadAvatarData: @Sendable () async throws -> Data?

    internal init(
      account: Account,
      username: String,
      email: String,
      loadAvatarData: @escaping @Sendable () async throws -> Data?
    ) {
      self.account = account
      self.username = username
      self.email = email
      self.loadAvatarData = loadAvatarData
    }

    static func == (
      lhs: AccountData,
      rhs: AccountData
    ) -> Bool {
      lhs.id == rhs.id
        && lhs.username == rhs.username
        && lhs.email == rhs.email
    }
  }

}
