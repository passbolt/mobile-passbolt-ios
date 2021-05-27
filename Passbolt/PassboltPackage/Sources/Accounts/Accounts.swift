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
  
  public var verifyAccountsDataIntegrity: () -> Result<Void, TheError>
  public var storedAccounts: () -> Array<Account>
  public var storeAccount: (
    _ domain: String,
    _ userID: String,
    _ fingerprint: String,
    _ armoredKey: ArmoredPrivateKey
  ) -> Result<Account, TheError>
  public var removeAccount: (Account) -> Void
}

extension Accounts: Feature {
  
  public typealias Environment = (
    preferences: Preferences,
    keychain: Keychain,
    uuidGenerator: UUIDGenerator
  )
  
  public static func environmentScope(
    _ rootEnvironment: RootEnvironment
  ) -> Environment {
    (
      preferences: rootEnvironment.preferences,
      keychain: rootEnvironment.keychain,
      uuidGenerator: rootEnvironment.uuidGenerator
    )
  }
  
  public static func load(
    in environment: Environment,
    using features: FeatureFactory,
    cancellables: inout Array<AnyCancellable>
  ) -> Self {
    let dataStore: AccountsDataStore = features.instance()
    
    func verifyAccountsDataIntegrity() -> Result<Void, TheError> {
      dataStore.verifyDataIntegrity()
    }
    
    func storedAccounts() -> Array<Account> {
      dataStore.loadAccounts()
    }
    
    func storeAccount(
      domain: String,
      userID: String,
      fingerprint: String,
      armoredKey: ArmoredPrivateKey
    ) -> Result<Account, TheError> {
      let account: Account = .init(
        localID: .init(rawValue: environment.uuidGenerator().uuidString),
        domain: domain,
        userID: userID,
        fingerprint: fingerprint
      )
      return dataStore.storeAccount(
        account,
        armoredKey
      )
      .map { _ in account }
    }
    
    func removeAccount(_ account: Account) -> Void {
      dataStore.deleteAccount(account)
      #warning("TODO: [PAS-69] - clear session data and passphrese? It might be done in Safety")
    }
    
    return Self(
      verifyAccountsDataIntegrity: verifyAccountsDataIntegrity,
      storedAccounts: storedAccounts,
      storeAccount: storeAccount(domain:userID:fingerprint:armoredKey:),
      removeAccount: removeAccount
    )
  }
  
  #if DEBUG
  // placeholder implementation for mocking and testing, unavailable in release
  public static var placeholder: Self {
    Self(
      verifyAccountsDataIntegrity: Commons.placeholder("You have to provide mocks for used methods"),
      storedAccounts: Commons.placeholder("You have to provide mocks for used methods"),
      storeAccount: Commons.placeholder("You have to provide mocks for used methods"),
      removeAccount: Commons.placeholder("You have to provide mocks for used methods")
    )
  }
  #endif
}

extension Accounts {
  
  public func storeTransferedAccount(
    domain: String,
    userID: String,
    fingerprint: String,
    armoredKey: ArmoredPrivateKey
  ) -> Result<Account, TheError> {
    storeAccount(domain, userID, fingerprint, armoredKey)
  }
}
