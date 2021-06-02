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

import struct Foundation.Data
import SQLite3

public protocol DatabaseStatementBindable {
  
  func bind(
    _ handle: OpaquePointer?,
    at index: Int32
  ) -> Bool
}

// The SQLITE_TRANSIENT value means that the content will likely change in the near future and that SQLite should make its own private copy of the content before returning. https://sqlite.org/c3ref/c_static.html
// swiftlint:disable:next identifier_name
private let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

extension Int32: DatabaseStatementBindable {
  
  public func bind(
    _ handle: OpaquePointer?,
    at index: Int32
  ) -> Bool {
    sqlite3_bind_int(handle, index, self) == SQLITE_OK
  }
}

extension Int64: DatabaseStatementBindable {
  
  public func bind(
    _ handle: OpaquePointer?,
    at index: Int32
  ) -> Bool {
    sqlite3_bind_int64(handle, index, self) == SQLITE_OK
  }
}

extension String: DatabaseStatementBindable {
  
  public func bind(
    _ handle: OpaquePointer?,
    at index: Int32
  ) -> Bool {
    sqlite3_bind_text(handle, index, self, -1, SQLITE_TRANSIENT) == SQLITE_OK
  }
}

extension Bool: DatabaseStatementBindable {
  
  public func bind(
    _ handle: OpaquePointer?,
    at index: Int32
  ) -> Bool {
    sqlite3_bind_int(handle, index, self ? 1 : 0) == SQLITE_OK
  }
}

extension Double: DatabaseStatementBindable {
  
  public func bind(
    _ handle: OpaquePointer?,
    at index: Int32
  ) -> Bool {
    sqlite3_bind_double(handle, index, self) == SQLITE_OK
  }
}

extension Data: DatabaseStatementBindable {
  
  public func bind(
    _ handle: OpaquePointer?,
    at index: Int32
  ) -> Bool {
    sqlite3_bind_blob(handle, index, [UInt8](self), Int32(self.count), SQLITE_TRANSIENT) == SQLITE_OK
  }
}
