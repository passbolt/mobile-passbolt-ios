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
import SQLCipher

import struct Foundation.Data
import struct Foundation.Date

@usableFromInline
internal protocol SQLiteBindable {

  func bind(
    _ handle: OpaquePointer?,
    at index: Int32
  ) -> Bool
}

extension SQLiteValue: SQLiteBindable {

  public func bind(
    _ handle: OpaquePointer?,
    at index: Int32
  ) -> Bool {
    switch self {
    case .null:
      return sqlite3_bind_null(
        handle,
        index
      ) == SQLITE_OK

    case .bool(let value):
      return sqlite3_bind_int(
        handle,
        index,
        value ? 1 : 0
      ) == SQLITE_OK

    case .int(let value):
      return sqlite3_bind_int64(
        handle,
        index,
        Int64(value)
      ) == SQLITE_OK

    case .double(let value):
      return sqlite3_bind_double(
        handle,
        index,
        value
      ) == SQLITE_OK

    case .string(let value):
      return sqlite3_bind_text(
        handle,
        index,
        value,
        -1,
        SQLITE_TRANSIENT
      ) == SQLITE_OK

    case .date(let value):
      return sqlite3_bind_int64(
        handle,
        index,
        Int64(value.timeIntervalSince1970)
      ) == SQLITE_OK

    case .data(let value):
      return sqlite3_bind_blob(
        handle,
        index,
        [UInt8](value),
        Int32(value.count),
        SQLITE_TRANSIENT
      ) == SQLITE_OK
    }
  }
}

// The SQLITE_TRANSIENT value means that the content will likely change in the near future and that SQLite should make its own private copy of the content before returning. https://sqlite.org/c3ref/c_static.html
// swift-format-ignore: AlwaysUseLowerCamelCase
private let SQLITE_TRANSIENT = unsafeBitCast(
  -1,
  to: sqlite3_destructor_type.self
)
