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

public func XCTAssertSuccessEqual<T, E>(
  _ lhs: Result<T, E>,
  _ rhs: T,
  _ file: StaticString = #filePath,
  _ line: UInt = #line
) where T: Equatable, E: Error {
  switch lhs {
  case let .success(value):
    XCTAssertEqual(value, rhs)
    
  case let .failure(error):
    XCTFail("Unexpected failure with value: \(rhs), got error: \(error)", file: file, line: line)
  }
}

public func XCTAssertSuccessNotEqual<T, E>(
  _ lhs: Result<T, E>,
  _ rhs: T,
  _ file: StaticString = #filePath,
  _ line: UInt = #line
) where T: Equatable, E: Error {
  switch lhs {
  case let .success(value):
    XCTAssertNotEqual(value, rhs)
    
  case let .failure(error):
    XCTFail("Unexpected failure with value: \(rhs), got error: \(error)", file: file, line: line)
  }
}

public func XCTAssertFailureEqual<T, E>(
  _ lhs: Result<T, E>,
  _ rhs: E,
  _ file: StaticString = #filePath,
  _ line: UInt = #line
) where E: Equatable & Error {
  switch lhs {
  case let .success(value):
    XCTFail("Unexpected success with value: \(rhs), got value: \(value)", file: file, line: line)
    
  case let .failure(error):
    XCTAssertEqual(error, rhs)
  }
}

public func XCTAssertFailureNotEqual<T, E>(
  _ lhs: Result<T, E>,
  _ rhs: E,
  _ file: StaticString = #filePath,
  _ line: UInt = #line
) where E: Equatable & Error {
  switch lhs {
  case let .success(value):
    XCTFail("Unexpected success with value: \(rhs), got value: \(value)", file: file, line: line)
    
  case let .failure(error):
    XCTAssertNotEqual(error, rhs)
  }
}
