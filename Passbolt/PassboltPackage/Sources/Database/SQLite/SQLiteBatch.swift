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

/// Sizing for multi-row SQL statements (batched `INSERT` / `IN (...)`) built by the store operations.
///
/// A batched statement is bounded by two independent limits of the bundled SQLCipher build, and must
/// stay under BOTH:
/// - `SQLITE_MAX_VARIABLE_NUMBER` (32766): host parameters (`?`) per prepared statement. The
///   `SQLITE_MAX_LIMIT_VARIABLE_NUMBER` define in Package.swift is misspelled, so this stays at the
///   source default.
/// - `SQLITE_MAX_SQL_LENGTH` (100000 bytes, set in Package.swift): length of the statement *text*. The
///   `?`-skeleton grows with the row count even though the bound values do not count toward it, so for
///   wide rows this is the *tighter* limit — sizing by parameter count alone overflows it.
///
/// `maxRows(perRowBindings:)` returns the largest row count satisfying both, so every batch is as large
/// as safely possible and self-corrects when a table gains or loses a column.
public enum SQLiteBatch {

  /// Host parameters SQLite accepts in one prepared statement — SQLCipher's `SQLITE_MAX_VARIABLE_NUMBER`.
  public static let maximumHostParameters: Int = 32_766

  /// SQL statement text length SQLite accepts — SQLCipher's `SQLITE_MAX_SQL_LENGTH`.
  public static let maximumStatementLength: Int = 100_000

  /// Host-parameter budget, kept below ``maximumHostParameters`` for a few fixed parameters per statement.
  public static let parameterBudget: Int = 30_000

  /// SQL-text budget, kept below ``maximumStatementLength`` for each statement's fixed header/footer
  /// (column list, `ON CONFLICT` clause, …).
  public static let statementLengthBudget: Int = 90_000

  /// Largest number of rows that fit in one multi-row statement under both budgets.
  ///
  /// - Parameter perRowBindings: Number of `?` placeholders each row contributes; values below 1 are
  ///   treated as 1.
  /// - Returns: A positive row count (at least 1).
  public static func maxRows(perRowBindings: Int) -> Int {
    let bindings: Int = Swift.max(1, perRowBindings)
    // Each row renders as "( ?, ?, … )" plus a ", " separator: ~3 bytes per placeholder ("?, ") and
    // ~8 bytes of per-row wrapper/separator overhead.
    let estimatedBytesPerRow: Int = bindings * 3 + 8
    let rowsByParameters: Int = self.parameterBudget / bindings
    let rowsByLength: Int = self.statementLengthBudget / estimatedBytesPerRow
    return Swift.max(1, Swift.min(rowsByParameters, rowsByLength))
  }
}
