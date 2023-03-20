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
import Features

import struct Foundation.URL
import let LocalAuthentication.errSecAuthFailed

// MARK: - Interface (Legacy)

/// Legacy access to all acounts data storage.
/// TODO: Split to per account features
public struct AccountsDataStore {

  public var verifyDataIntegrity: @Sendable () throws -> Void
  public var loadAccounts: @Sendable () -> Array<Account>
  public var loadLastUsedAccount: @Sendable () -> Account?
  public var storeLastUsedAccount: @Sendable (Account.LocalID) -> Void
  public var storeAccount: @Sendable (Account, AccountProfile, ArmoredPGPPrivateKey) throws -> Void
  public var loadAccountPrivateKey: @Sendable (Account.LocalID) throws -> ArmoredPGPPrivateKey
  public var isAccountPassphraseStored: @Sendable (Account.LocalID) -> Bool
  public var storeAccountPassphrase: @Sendable (Account.LocalID, Passphrase) throws -> Void
  public var loadAccountPassphrase: @Sendable (Account.LocalID) throws -> Passphrase
  public var deleteAccountPassphrase: @Sendable (Account.LocalID) throws -> Void
  public var storeAccountMFAToken: @Sendable (Account.LocalID, String) throws -> Void
  public var loadAccountMFAToken: @Sendable (Account.LocalID) throws -> String?
  public var deleteAccountMFAToken: @Sendable (Account.LocalID) throws -> Void
  public var loadAccountProfile: @Sendable (Account.LocalID) throws -> AccountProfile
  public var updateAccountProfile: @Sendable (AccountProfile) throws -> Void
  public var deleteAccount: @Sendable (Account.LocalID) -> Void
  public var storeServerFingerprint: @Sendable (Account.LocalID, Fingerprint) throws -> Void
  public var loadServerFingerprint: @Sendable (Account.LocalID) throws -> Fingerprint?

  public init(
    verifyDataIntegrity: @escaping @Sendable () throws -> Void,
    loadAccounts: @escaping @Sendable () -> Array<Account>,
    loadLastUsedAccount: @escaping @Sendable () -> Account?,
    storeLastUsedAccount: @escaping @Sendable (Account.LocalID) -> Void,
    storeAccount: @escaping @Sendable (Account, AccountProfile, ArmoredPGPPrivateKey) throws -> Void,
    loadAccountPrivateKey: @escaping @Sendable (Account.LocalID) throws -> ArmoredPGPPrivateKey,
    isAccountPassphraseStored: @escaping @Sendable (Account.LocalID) -> Bool,
    storeAccountPassphrase: @escaping @Sendable (Account.LocalID, Passphrase) throws -> Void,
    loadAccountPassphrase: @escaping @Sendable (Account.LocalID) throws -> Passphrase,
    deleteAccountPassphrase: @escaping @Sendable (Account.LocalID) throws -> Void,
    storeAccountMFAToken: @escaping @Sendable (Account.LocalID, String) throws -> Void,
    loadAccountMFAToken: @escaping @Sendable (Account.LocalID) throws -> String?,
    deleteAccountMFAToken: @escaping @Sendable (Account.LocalID) throws -> Void,
    loadAccountProfile: @escaping @Sendable (Account.LocalID) throws -> AccountProfile,
    updateAccountProfile: @escaping @Sendable (AccountProfile) throws -> Void,
    deleteAccount: @escaping @Sendable (Account.LocalID) -> Void,
    storeServerFingerprint: @escaping @Sendable (Account.LocalID, Fingerprint) throws -> Void,
    loadServerFingerprint: @escaping @Sendable (Account.LocalID) throws -> Fingerprint?
  ) {
    self.verifyDataIntegrity = verifyDataIntegrity
    self.loadAccounts = loadAccounts
    self.loadLastUsedAccount = loadLastUsedAccount
    self.storeLastUsedAccount = storeLastUsedAccount
    self.storeAccount = storeAccount
    self.loadAccountPrivateKey = loadAccountPrivateKey
    self.isAccountPassphraseStored = isAccountPassphraseStored
    self.storeAccountPassphrase = storeAccountPassphrase
    self.loadAccountPassphrase = loadAccountPassphrase
    self.deleteAccountPassphrase = deleteAccountPassphrase
    self.storeAccountMFAToken = storeAccountMFAToken
    self.loadAccountMFAToken = loadAccountMFAToken
    self.deleteAccountMFAToken = deleteAccountMFAToken
    self.loadAccountProfile = loadAccountProfile
    self.updateAccountProfile = updateAccountProfile
    self.deleteAccount = deleteAccount
    self.storeServerFingerprint = storeServerFingerprint
    self.loadServerFingerprint = loadServerFingerprint
  }
}

extension AccountsDataStore: LoadableFeature {

  public typealias Context = ContextlessLoadableFeatureContext

  #if DEBUG
  public static var placeholder: Self {
    Self(
      verifyDataIntegrity: unimplemented0(),
      loadAccounts: unimplemented0(),
      loadLastUsedAccount: unimplemented0(),
      storeLastUsedAccount: unimplemented1(),
      storeAccount: unimplemented3(),
      loadAccountPrivateKey: unimplemented1(),
      isAccountPassphraseStored: unimplemented1(),
      storeAccountPassphrase: unimplemented2(),
      loadAccountPassphrase: unimplemented1(),
      deleteAccountPassphrase: unimplemented1(),
      storeAccountMFAToken: unimplemented2(),
      loadAccountMFAToken: unimplemented1(),
      deleteAccountMFAToken: unimplemented1(),
      loadAccountProfile: unimplemented1(),
      updateAccountProfile: unimplemented1(),
      deleteAccount: unimplemented1(),
      storeServerFingerprint: unimplemented2(),
      loadServerFingerprint: unimplemented1()
    )
  }
  #endif
}
