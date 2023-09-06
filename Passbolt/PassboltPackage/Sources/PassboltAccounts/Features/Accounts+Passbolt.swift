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
import Crypto
import OSFeatures
import Session

// MARK: - Implementation (Legacy)

extension Accounts {

  @MainActor fileprivate static func load(
    features: Features,
    cancellables: Cancellables
  ) throws -> Self {
    let uuidGenerator: UUIDGenerator = features.instance()

    let session: Session = try features.instance()
    let dataStore: AccountsDataStore = try features.instance()

    let updatesSource: Updates = .init()

    @Sendable nonisolated func verifyAccountsDataIntegrity() throws {
      try dataStore.verifyDataIntegrity()
    }

    @Sendable nonisolated func storedAccounts() -> Array<AccountWithProfile> {
			dataStore
				.loadAccounts()
				.compactMap { (account: Account) -> AccountWithProfile? in
					do {
						return AccountWithProfile(
							account: account,
							profile: try dataStore.loadAccountProfile(account.localID)
						)
					}
					catch {
						error.logged(
							info: .message("Failed to load account profile. Account will be unavailable!")
						)
						return .none
					}
				}
    }

    @Sendable nonisolated func lastUsedAccount() -> AccountWithProfile? {
      dataStore
				.loadLastUsedAccount()
				.flatMap { (account: Account) -> AccountWithProfile? in
					do {
						return AccountWithProfile(
							account: account,
							profile: try dataStore.loadAccountProfile(account.localID)
						)
					}
					catch {
						error.logged(
							info: .message("Failed to load account profile. Account will be unavailable!")
						)
						return .none
					}
				}
    }

    @Sendable nonisolated func addAccount(
      _ transferedAccount: AccountTransferData
    ) throws -> Account {
      let storedAccount: Account? =
        dataStore
        .loadAccounts()
        .first(
          where: { stored in
            stored.userID.rawValue == transferedAccount.userID
              && stored.domain == transferedAccount.domain
          }
        )

      let account: Account
      if let storedAccount: Account = storedAccount {
        account = storedAccount
      }
      else {
        let accountID: Account.LocalID = .init(rawValue: uuidGenerator.uuid())
        account = .init(
          localID: accountID,
          domain: transferedAccount.domain,
          userID: transferedAccount.userID,
          fingerprint: transferedAccount.fingerprint
        )
        let accountProfile: AccountProfile = .init(
          accountID: accountID,
          label: "\(transferedAccount.firstName) \(transferedAccount.lastName)",  // initial label
          username: transferedAccount.username,
          firstName: transferedAccount.firstName,
          lastName: transferedAccount.lastName,
          avatarImageURL: transferedAccount.avatarImageURL
        )

        do {
          try dataStore
            .storeAccount(account, accountProfile, transferedAccount.armoredKey)
          updatesSource.update()
        }
        catch {
					Diagnostics.logger.info("...failed to store account data...")
          Diagnostics.debug(
            "Failed to save account: \(account.localID)"
          )
          throw error
        }
      }
      return account
    }

    @Sendable nonisolated func remove(
      account: Account
    ) throws {
      Diagnostics.logger.info("Removing local account data...")
      Task {
        #warning("TODO: manage spawning tasks")
        await session.close(account)
      }
      dataStore.deleteAccount(account.localID)
      updatesSource.update()
      Diagnostics.logger.info("...removing local account data succeeded!")
    }

    return Self(
      updates: updatesSource.asAnyUpdatable(),
      verifyDataIntegrity: verifyAccountsDataIntegrity,
      storedAccounts: storedAccounts,
      lastUsedAccount: lastUsedAccount,
      addAccount: addAccount(_:),
      removeAccount: remove(account:)
    )
  }
}

extension FeaturesRegistry {

  public mutating func usePassboltAccounts() {
    self.use(
      .lazyLoaded(
        Accounts.self,
        load: Accounts.load(features:cancellables:)
      )
    )
  }
}
