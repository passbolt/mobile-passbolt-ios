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

public struct DiagnosticsInfo {

  internal let message: StaticString
  internal let file: StaticString
  internal let line: UInt

  #if DEBUG
  private var values: Dictionary<StaticString, Any> = .init()
  #endif
}

extension DiagnosticsInfo {

  /// Create instance of `DiagnosticsInfo`.
  ///
  /// - Parameters:
  ///   - message: Diagnostic message. Used to build log messages and describe
  ///   error context stacks.
  ///   - file: File context. Filled automatically based on invocation location.
  ///   - line: Line context. Filled automatically based on invocation location.
  /// - Returns: New instance of `DiagnosticsInfo`.
  public static func message(
    _ message: StaticString,
    file: StaticString = #fileID,
    line: UInt = #line
  ) -> Self {
    Self(
      message: message,
      file: file,
      line: line
    )
  }
}

#if DEBUG
extension DiagnosticsInfo {

  internal mutating func record(
    _ value: Any,
    for key: StaticString
  ) {
    self.values[key] = value
  }

  internal mutating func record(
    _ values: Dictionary<StaticString, Any>
  ) {
    self.values.merge(values, uniquingKeysWith: { $1 })
  }
}
#endif

extension DiagnosticsInfo {

  public var diagnosticsDescription: String {
    #if DEBUG
    self.debugDescription
    #else
    self.description
    #endif
  }
}

extension DiagnosticsInfo: CustomStringConvertible {

  public var description: String {
    "\(self.message) \(self.file):\(self.line)"
  }
}

extension DiagnosticsInfo: CustomDebugStringConvertible {

  public var debugDescription: String {
		#if DEBUG
		self.description
      .appending(
        self.values
          .reduce(
            into: String(),
            { (result, value) in
              result.append("\n 🧩 \(value.key): \(value.value)")
            }
          )
      )
		#else
		self.description
		#endif
  }
}
