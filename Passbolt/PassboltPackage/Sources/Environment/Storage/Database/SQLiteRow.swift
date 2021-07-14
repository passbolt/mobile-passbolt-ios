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

import SQLCipher

import struct Foundation.Data

@dynamicMemberLookup
public struct SQLiteRow {

  public var columnNames: Set<String> { Set(values.keys) }

  private let values: Dictionary<String, SQLiteBindable?>

  internal init(
    _ handle: OpaquePointer?
  ) {
    func bindable(
      at index: Int32
    ) -> SQLiteBindable? {
      let columnType: Int32 = sqlite3_column_type(
        handle,
        index
      )

      switch columnType {
      case SQLITE_BLOB:
        let pointer: UnsafeRawPointer? = sqlite3_column_blob(
          handle,
          index
        )

        if let pointer: UnsafeRawPointer = pointer {
          let length: Int = .init(
            sqlite3_column_bytes(
              handle,
              index
            )
          )
          return Data(
            bytes: pointer,
            count: length
          )
        }
        else {
          return Data()
        }

      case SQLITE_FLOAT:
        return sqlite3_column_double(
          handle,
          index
        )

      case SQLITE_INTEGER:
        return sqlite3_column_int64(
          handle,
          index
        )

      case SQLITE_NULL:
        return nil

      case SQLITE_TEXT:
        return String(
          cString: UnsafePointer(
            sqlite3_column_text(
              handle,
              index
            )
          )
        )

      case let type:
        fatalError(
          "Encountered unsupported SQLite column type: \(type)"
        )
      }
    }

    self.values = .init(
      uniqueKeysWithValues: (0..<sqlite3_column_count(handle))
        .map { columnIndex in
          (
            key: String(
              cString: sqlite3_column_name(
                handle,
                columnIndex
              )
            ),
            value: bindable(
              at: columnIndex
            )
          )
        }
    )
  }

  public subscript(
    dynamicMember column: String
  ) -> Data? {
    values[column] as? Data
  }

  public subscript(
    dynamicMember column: String
  ) -> String? {
    values[column] as? String
  }

  public subscript(
    dynamicMember column: String
  ) -> Int64? {
    values[column] as? Int64
  }

  public subscript(
    dynamicMember column: String
  ) -> Int? {
    (values[column] as? Int64)
      .map(Int.init)
  }

  public subscript(
    dynamicMember column: String
  ) -> Double? {
    values[column] as? Double
  }

  public subscript(
    dynamicMember column: String
  ) -> Bool? {
    (values[column] as? Int64)
      .map { $0 != 0 }
  }
}

extension SQLiteRow: CustomStringConvertible {

  public var description: String {
    """
    ---
    SQLiteRow
    \(
      values
        .map { key, value in
          "  \(key): \((value as Any?).map { "\($0)" } ?? "nil")"
        }
        .joined(separator: "\n")
    )
    ---
    """
  }
}

#if DEBUG

extension SQLiteRow {

  public init(
    values: Dictionary<String, SQLiteBindable?>
  ) {
    self.values = values
  }
}

#endif
