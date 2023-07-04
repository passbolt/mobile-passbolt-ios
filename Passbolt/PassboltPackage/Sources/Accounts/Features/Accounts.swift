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

import Features

// MARK: - Interface

/// Access locally stored accounts.
public struct Accounts {

  /// Updates in stored accounts.
  /// Includes adding and removing accounts.
  public var updates: Updates
  /// Accounts data integrity check.
  /// Cleans up any leftover data
  /// and removes inproperly stored accounts.
  public var verifyDataIntegrity: @Sendable () throws -> Void
  /// List of currently stored accounts.
  public var storedAccounts: @Sendable () -> Array<Account>
  /// Last used account if any and still stored.
  public var lastUsedAccount: @Sendable () -> Account?
  /// Saves account data locally.
  public var addAccount: @Sendable (AccountTransferData) throws -> Account
  /// Delete locally stored data for given account.
  /// Closes the session for that account if needed.
  public var removeAccount: @Sendable (Account) throws -> Void

  public init(
    updates: Updates,
    verifyDataIntegrity: @escaping @Sendable () throws -> Void,
    storedAccounts: @escaping @Sendable () -> Array<Account>,
    lastUsedAccount: @escaping @Sendable () -> Account?,
    addAccount: @escaping @Sendable (AccountTransferData) throws -> Account,
    removeAccount: @escaping @Sendable (Account) throws -> Void
  ) {
    self.updates = updates
    self.verifyDataIntegrity = verifyDataIntegrity
    self.storedAccounts = storedAccounts
    self.lastUsedAccount = lastUsedAccount
    self.addAccount = addAccount
    self.removeAccount = removeAccount
  }
}

extension Accounts: LoadableFeature {

  public typealias Context = ContextlessLoadableFeatureContext

  #if DEBUG
  nonisolated public static var placeholder: Self {
    Self(
      updates: .never,
      verifyDataIntegrity: unimplemented0(),
      storedAccounts: unimplemented0(),
      lastUsedAccount: unimplemented0(),
      addAccount: unimplemented1(),
      removeAccount: unimplemented1()
    )
  }
  #endif
}
