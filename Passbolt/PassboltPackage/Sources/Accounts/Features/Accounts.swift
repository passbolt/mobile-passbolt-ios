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

import CommonModels
import Crypto
import Features

public struct Accounts {

  public var verifyStorageDataIntegrity: @StorageAccessActor () -> Result<Void, Error>
  public var storedAccounts: @StorageAccessActor () -> Array<Account>
  // Saves account data if authorization succeeds and creates session.
  public var transferAccount:
    @StorageAccessActor (
      _ domain: URLString,
      _ userID: String,
      _ username: String,
      _ firstName: String,
      _ lastName: String,
      _ avatarImageURL: String,
      _ fingerprint: Fingerprint,
      _ armoredKey: ArmoredPGPPrivateKey,
      _ passphrase: Passphrase
    ) -> AnyPublisher<Void, Error>
  public var removeAccount: @StorageAccessActor (Account) -> Result<Void, Error>
}

extension Accounts: Feature {

  public static func load(
    in environment: AppEnvironment,
    using features: FeatureFactory,
    cancellables: Cancellables
  ) async throws -> Self {
    let uuidGenerator: UUIDGenerator = environment.uuidGenerator

    let diagnostics: Diagnostics = try await features.instance()
    let session: AccountSession = try await features.instance()
    let dataStore: AccountsDataStore = try await features.instance()

    @StorageAccessActor func verifyAccountsDataIntegrity() -> Result<Void, Error> {
      dataStore.verifyDataIntegrity()
    }

    @StorageAccessActor func storedAccounts() -> Array<Account> {
      dataStore.loadAccounts()
    }

    @StorageAccessActor func transferAccount(
      domain: URLString,
      userID: String,
      username: String,
      firstName: String,
      lastName: String,
      avatarImageURL: String,
      fingerprint: Fingerprint,
      armoredKey: ArmoredPGPPrivateKey,
      passphrase: Passphrase
    ) -> AnyPublisher<Void, Error> {

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
        return Fail(
          error:
            AccountDuplicate
            .error("Duplicate account used for account transfer")
            .recording(domain, for: "domain")
            .recording(userID, for: "userID")
        )
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

      return cancellables.executeOnStorageAccessActorWithPublisher { () -> Void in
        _ =
          try await session
          .authorize(account, .adHoc(passphrase, armoredKey))

        switch dataStore.storeAccount(account, accountProfile, armoredKey) {
        case .success:
          return Void()

        case let .failure(error):
          diagnostics.diagnosticLog("...failed to store account data...")
          diagnostics.debugLog(
            "Failed to save account: \(account.localID): \(error)"
          )
          await session.close()  // cleanup session
          throw error
        }
      }
      .eraseToAnyPublisher()
    }

    @StorageAccessActor func remove(
      account: Account
    ) -> Result<Void, Error> {
      diagnostics.diagnosticLog("Removing local account data...")
      dataStore.deleteAccount(account.localID)
      session
        .statePublisher()
        .first()
        .sink { sessionState in
          switch sessionState {
          case let .authorized(currentAccount) where currentAccount.localID == account.localID,
            let .authorizedMFARequired(currentAccount, _) where currentAccount.localID == account.localID,
            let .authorizationRequired(currentAccount) where currentAccount.localID == account.localID:
            cancellables.executeOnAccountSessionActor(session.close)

          case .authorized, .authorizedMFARequired, .authorizationRequired, .none:
            break
          }
        }
        .store(in: cancellables)
      diagnostics.diagnosticLog("...removing local account data succeeded!")
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
      verifyStorageDataIntegrity: unimplemented("You have to provide mocks for used methods"),
      storedAccounts: unimplemented("You have to provide mocks for used methods"),
      transferAccount: unimplemented("You have to provide mocks for used methods"),
      removeAccount: unimplemented("You have to provide mocks for used methods")
    )
  }
  #endif
}
