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
    features: FeatureFactory,
    cancellables: Cancellables
  ) async throws -> Self {
    let uuidGenerator: UUIDGenerator = features.instance()
    let diagnostics: OSDiagnostics = features.instance()
    let session: Session = try await features.instance()
    let dataStore: AccountsDataStore = try await features.instance()

    let updatesSequenceSource: UpdatesSequenceSource = .init()

    @Sendable nonisolated func verifyAccountsDataIntegrity() throws {
      try dataStore.verifyDataIntegrity()
    }

    @Sendable nonisolated func storedAccounts() -> Array<Account> {
      dataStore.loadAccounts()
    }

    @Sendable nonisolated func lastUsedAccount() -> Account? {
      dataStore.loadLastUsedAccount()
    }

    @Sendable nonisolated func addAccount(
      _ transferedAccount: TransferedAccount
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
          updatesSequenceSource.sendUpdate()
        }
        catch {
          diagnostics.log(diagnostic: "...failed to store account data...")
          diagnostics.debugLog(
            "Failed to save account: \(account.localID): \(error)"
          )
          throw error
        }
      }
      return account
    }

    @Sendable nonisolated func remove(
      account: Account
    ) throws {
      diagnostics.log(diagnostic: "Removing local account data...")
      Task {
        #warning("TODO: manage spawning tasks")
        await session.close(account)
      }
      dataStore.deleteAccount(account.localID)
      updatesSequenceSource.sendUpdate()
      diagnostics.log(diagnostic: "...removing local account data succeeded!")
    }

    return Self(
      updates: updatesSequenceSource.updatesSequence,
      verifyDataIntegrity: verifyAccountsDataIntegrity,
      storedAccounts: storedAccounts,
      lastUsedAccount: lastUsedAccount,
      addAccount: addAccount(_:),
      removeAccount: remove(account:)
    )
  }
}

extension FeatureFactory {

  @MainActor public func usePassboltAccounts() {
    self.use(
      .lazyLoaded(
        Accounts.self,
        load: Accounts.load(features:cancellables:)
      )
    )
  }
}
