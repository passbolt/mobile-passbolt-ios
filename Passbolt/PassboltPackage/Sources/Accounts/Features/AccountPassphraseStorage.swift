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

/// Storage for account passphrases protected by biometric authentication.
public struct AccountPassphraseStorage: Sendable {

  public var isAccountPassphraseStored: @Sendable (Account.LocalID) -> Bool
  public var storeAccountPassphrase: @Sendable (Account.LocalID, Passphrase) throws -> Void
  public var loadAccountPassphrase: @Sendable (Account.LocalID) throws -> Passphrase
  public var deleteAccountPassphrase: @Sendable (Account.LocalID) throws -> Void

  public init(
    isAccountPassphraseStored: @escaping @Sendable (Account.LocalID) -> Bool,
    storeAccountPassphrase: @escaping @Sendable (Account.LocalID, Passphrase) throws -> Void,
    loadAccountPassphrase: @escaping @Sendable (Account.LocalID) throws -> Passphrase,
    deleteAccountPassphrase: @escaping @Sendable (Account.LocalID) throws -> Void
  ) {
    self.isAccountPassphraseStored = isAccountPassphraseStored
    self.storeAccountPassphrase = storeAccountPassphrase
    self.loadAccountPassphrase = loadAccountPassphrase
    self.deleteAccountPassphrase = deleteAccountPassphrase
  }
}

extension AccountPassphraseStorage: LoadableFeature {

  #if DEBUG
  public static var placeholder: Self {
    Self(
      isAccountPassphraseStored: unimplemented1(),
      storeAccountPassphrase: unimplemented2(),
      loadAccountPassphrase: unimplemented1(),
      deleteAccountPassphrase: unimplemented1()
    )
  }
  #endif
}
