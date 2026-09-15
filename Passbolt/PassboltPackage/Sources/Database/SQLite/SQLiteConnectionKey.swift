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

import Commons

import struct Foundation.Data

/// Key material handed to SQLCipher when opening or rekeying a database.
public enum SQLiteConnectionKey: Sendable, Equatable {

  /// Raw 256 bit key passed to SQLCipher verbatim as `x'<hex>'`, skipping key derivation.
  /// This is the format used for every database created or migrated by the current code.
  case raw(Data)

  /// Key derived from the account passphrase, kept only to open databases created before the
  /// raw key migration. Such a database is rekeyed to a `raw` key on its first open.
  case passphraseDerived(String)
}

extension SQLiteConnectionKey {

  /// String form understood by `sqlite3_key` / `sqlite3_rekey`.
  internal var sqlCipherRepresentation: String {
    switch self {
    case .raw(let keyData):
      return "x'\(keyData.bytesToHexString(uppercased: false))'"

    case .passphraseDerived(let key):
      return key
    }
  }

  /// Byte count passed to `sqlite3_key` / `sqlite3_rekey` alongside the string form.
  internal var sqlCipherByteCount: Int32 {
    switch self {
    case .raw:
      return Int32(self.sqlCipherRepresentation.utf8.count)

    case .passphraseDerived(let key):
      // Databases predating the migration were keyed with the terminating NUL byte counted in,
      // so the very same length has to be used here or they no longer decrypt.
      return Int32(key.utf8CString.count)
    }
  }
}
