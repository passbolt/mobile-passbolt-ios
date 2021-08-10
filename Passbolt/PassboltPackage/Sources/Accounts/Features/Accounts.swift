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

import Crypto
import Features

public struct Accounts {

  public var verifyStorageDataIntegrity: () -> Result<Void, TheError>
  public var storedAccounts: () -> Array<Account>
  // Saves account data if authorization succeeds and creates session.
  public var transferAccount:
    (
      _ domain: String,
      _ userID: String,
      _ username: String,
      _ firstName: String,
      _ lastName: String,
      _ avatarImageURL: String,
      _ fingerprint: String,
      _ armoredKey: ArmoredPGPPrivateKey,
      _ passphrase: Passphrase
    ) -> AnyPublisher<Void, TheError>
  public var removeAccount: (Account) -> Result<Void, TheError>
}

extension Accounts: Feature {

  public static func load(
    in environment: Environment,
    using features: FeatureFactory,
    cancellables: Cancellables
  ) -> Self {
    let uuidGenerator: UUIDGenerator = environment.uuidGenerator

    let diagnostics: Diagnostics = features.instance()
    let session: AccountSession = features.instance()
    let dataStore: AccountsDataStore = features.instance()

    func verifyAccountsDataIntegrity() -> Result<Void, TheError> {
      dataStore.verifyDataIntegrity()
    }

    func storedAccounts() -> Array<Account> {
      dataStore.loadAccounts()
    }

    func transferAccount(
      domain: String,
      userID: String,
      username: String,
      firstName: String,
      lastName: String,
      avatarImageURL: String,
      fingerprint: String,
      armoredKey: ArmoredPGPPrivateKey,
      passphrase: Passphrase
    ) -> AnyPublisher<Void, TheError> {

      let accountAlreadyStored: Bool =
        dataStore
        .loadAccounts()
        .contains(
          where: { stored in
            stored.userID.rawValue == userID
              && stored.domain == domain
          }
        )
      guard !accountAlreadyStored
      else {
        return Fail<Void, TheError>(error: .duplicateAccount())
          .eraseToAnyPublisher()
      }

      let accountID: Account.LocalID = .init(rawValue: uuidGenerator().uuidString)
      let account: Account = .init(
        localID: accountID,
        domain: domain,
        userID: Account.UserID(rawValue: userID),
        fingerprint: fingerprint
      )
      let accountProfile: AccountProfile = .init(
        accountID: accountID,
        label: "\(firstName) \(lastName)",  // initial label
        username: username,
        firstName: firstName,
        lastName: lastName,
        avatarImageURL: avatarImageURL,
        biometricsEnabled: false  // it is always disabled initially
      )

      return
        session
        .authorize(account, .adHoc(passphrase, armoredKey))
        .map { _ -> AnyPublisher<Void, TheError> in
          switch dataStore.storeAccount(account, accountProfile, armoredKey) {
          case .success:
            return Just(Void())
              .setFailureType(to: TheError.self)
              .eraseToAnyPublisher()
          case let .failure(error):
            diagnostics.debugLog(
              "Failed to save account: \(account.localID)"
                + " - status: \(error.osStatus.map(String.init(describing:)) ?? "N/A")"
            )
            session.close()  // cleanup session
            return Fail<Void, TheError>(error: error)
              .eraseToAnyPublisher()
          }
        }
        .switchToLatest()
        .eraseToAnyPublisher()
    }

    func remove(
      account: Account
    ) -> Result<Void, TheError> {
      dataStore.deleteAccount(account.localID)
      session
        .statePublisher()
        .first()
        .sink { sessionState in
          switch sessionState {
          case let .authorized(currentAccount) where currentAccount.localID == account.localID,
            let .authorizationRequired(currentAccount) where currentAccount.localID == account.localID:
            session.close()

          case .authorized, .authorizationRequired, .none:
            break
          }
        }
        .store(in: cancellables)

      return .success
    }

    return Self(
      verifyStorageDataIntegrity: verifyAccountsDataIntegrity,
      storedAccounts: storedAccounts,
      transferAccount: transferAccount(
        domain:
        userID:
        username:
        firstName:
        lastName:
        avatarImageURL:
        fingerprint:
        armoredKey:
        passphrase:
      ),
      removeAccount: remove(account:)
    )
  }

  #if DEBUG
  // placeholder implementation for mocking and testing, unavailable in release
  public static var placeholder: Self {
    Self(
      verifyStorageDataIntegrity: Commons.placeholder("You have to provide mocks for used methods"),
      storedAccounts: Commons.placeholder("You have to provide mocks for used methods"),
      transferAccount: Commons.placeholder("You have to provide mocks for used methods"),
      removeAccount: Commons.placeholder("You have to provide mocks for used methods")
    )
  }
  #endif
}
