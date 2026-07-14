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

import Database
import XCTest

final internal class SQLiteBatchTests: XCTestCase {

  internal func test_maxRows_keepsAFullBatchUnderTheHostParameterLimit() {
    // rows * bindingsPerRow must never exceed the host-parameter budget (and thus the hard limit).
    for bindingsPerRow: Int in 1 ... 16 {
      let rows: Int = SQLiteBatch.maxRows(perRowBindings: bindingsPerRow)
      XCTAssertLessThanOrEqual(rows * bindingsPerRow, SQLiteBatch.parameterBudget)
      XCTAssertLessThanOrEqual(rows * bindingsPerRow, SQLiteBatch.maximumHostParameters)
    }
  }

  internal func test_maxRows_keepsAFullBatchUnderTheStatementLengthLimit() {
    // The `?`-skeleton grows with the row count, so a full batch must also fit SQLITE_MAX_SQL_LENGTH.
    // Estimate per row as ~3 bytes per placeholder ("?, ") plus ~8 bytes of wrapper/separator.
    for bindingsPerRow: Int in 1 ... 16 {
      let estimatedBytesPerRow: Int = bindingsPerRow * 3 + 8
      let rows: Int = SQLiteBatch.maxRows(perRowBindings: bindingsPerRow)
      XCTAssertLessThanOrEqual(rows * estimatedBytesPerRow, SQLiteBatch.statementLengthBudget)
      XCTAssertLessThanOrEqual(rows * estimatedBytesPerRow, SQLiteBatch.maximumStatementLength)
    }
  }

  internal func test_maxRows_clampsNonPositiveBindingsToOne() {
    XCTAssertEqual(SQLiteBatch.maxRows(perRowBindings: 0), SQLiteBatch.maxRows(perRowBindings: 1))
    XCTAssertEqual(SQLiteBatch.maxRows(perRowBindings: -5), SQLiteBatch.maxRows(perRowBindings: 1))
    XCTAssertGreaterThanOrEqual(SQLiteBatch.maxRows(perRowBindings: 1000), 1)
  }

  internal func test_budgets_leaveHeadroomUnderTheHardLimits() {
    XCTAssertLessThan(SQLiteBatch.parameterBudget, SQLiteBatch.maximumHostParameters)
    XCTAssertLessThan(SQLiteBatch.statementLengthBudget, SQLiteBatch.maximumStatementLength)
  }
}
