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

import XCTest

@testable import Commons

final class Int_ClampedTests: XCTestCase {

  func test_clamped_valueWithinRange_returnsUnchanged() {
    XCTAssertEqual(5.clamped(to: 0 ... 10), 5)
  }

  func test_clamped_valueBelowLowerBound_returnsLowerBound() {
    XCTAssertEqual((-3).clamped(to: 0 ... 10), 0)
  }

  func test_clamped_valueAboveUpperBound_returnsUpperBound() {
    XCTAssertEqual(42.clamped(to: 0 ... 10), 10)
  }

  func test_clamped_valueEqualToLowerBound_returnsLowerBound() {
    XCTAssertEqual(0.clamped(to: 0 ... 10), 0)
  }

  func test_clamped_valueEqualToUpperBound_returnsUpperBound() {
    XCTAssertEqual(10.clamped(to: 0 ... 10), 10)
  }

  func test_clamped_singleValueRange_alwaysReturnsThatValue() {
    XCTAssertEqual((-100).clamped(to: 7 ... 7), 7)
    XCTAssertEqual(7.clamped(to: 7 ... 7), 7)
    XCTAssertEqual(100.clamped(to: 7 ... 7), 7)
  }

  func test_clamped_negativeRange_clampsCorrectly() {
    XCTAssertEqual(0.clamped(to: -10 ... -2), -2)
    XCTAssertEqual((-100).clamped(to: -10 ... -2), -10)
    XCTAssertEqual((-5).clamped(to: -10 ... -2), -5)
  }

  func test_clamped_rangeStraddlingZero_clampsCorrectly() {
    XCTAssertEqual(10.clamped(to: -5 ... 5), 5)
    XCTAssertEqual((-10).clamped(to: -5 ... 5), -5)
    XCTAssertEqual(0.clamped(to: -5 ... 5), 0)
  }
}
