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

import Localization

import protocol Foundation.LocalizedError

/// Common protocol for error instances.
///
/// Inspired by: https://github.com/miquido/MQ-iOS
///
/// "One Error to rule them all, One Error to handle them, One Error to bring them all, and on the screen bind them."
public protocol TheError: Error, LocalizedError, CustomDebugStringConvertible {

  /// String which can be desplayed to the user when presenting this error on screen.
  var displayableMessage: DisplayableString { get }
  /// Diagnostics context containing additional informations related with error.
  /// Used to prepare diagnostic messages for logger.
  var context: DiagnosticsContext { get set }
  /// Stack of diagnostic messages to be used with diagnostic log.
  /// Default implementaion is based on current `context` value.
  var diagnosticMessages: Array<StaticString> { get }
}

extension TheError {

  public var displayableMessage: DisplayableString {
    .localized(key: "generic.error")
  }

  public var diagnosticMessages: Array<StaticString> {
    self.context.infoStack.map(\.message)
  }

  public var localizedDescription: String {
    self.displayableMessage.string()
  }
}

extension TheError /* LocalizedError */ {

  public var errorDescription: String {
    self.localizedDescription
  }
}

extension TheError /* CustomDebugStringConvertible */ {

  public var debugDescription: String {
    "\(Self.self)\n\(self.displayableMessage.string())\n\(self.context.debugDescription)"
  }
}

extension TheError {

  /// Terminate process with this error as the cause.
  ///
  /// - Parameters:
  ///   - message: Optional, additional message associated with process termination.
  ///   Default is empty.
  ///   - file: Source code file identifier.
  ///   Filled automatically based on compile time constants.
  ///   - line: Line in given source code file.
  ///   Filled automatically based on compile time constants.
  public func asFatalError(
    message: @autoclosure () -> StaticString = .init(),
    file: StaticString = #fileID,
    line: UInt = #line
  ) -> Never {
    logFatal(
      error: self,
      info: .message(
        message(),
        file: file,
        line: line
      )
    )
    fatalError(
      "\(message())\n\(self.debugDescription)",
      file: file,
      line: line
    )
  }

  /// Treat this error as the cause of assertion failure.
  ///
  /// - Parameters:
  ///   - message: Optional, additional message associated with assertion failure.
  ///   Default is empty.
  ///   - file: Source code file identifier.
  ///   Filled automatically based on compile time constants.
  ///   - line: Line in given source code file.
  ///   Filled automatically based on compile time constants.
  @discardableResult
  public func asAssertionFailure(
    message: @autoclosure () -> String = .init(),
    file: StaticString = #fileID,
    line: UInt = #line
  ) -> Self {
    assertionFailure(
      "\(message())\n\(self.debugDescription)",
      file: file,
      line: line
    )
    return self
  }

  /// Push new info message into context.
  ///
  /// - Parameter info: `DiagnosticsInfo` to be pushed on top of the `context` stack.
  public mutating func push(
    _ info: DiagnosticsInfo
  ) {
    self.context.push(info)
  }

  /// Make a copy of this error while pushing new info message into context.
  ///
  /// - Parameter info: `DiagnosticsInfo` to be pushed on top of the `context` stack.
  /// - Returns: Copy of this error with additional `DiagnosticsInfo`.
  public func pushing(
    _ info: DiagnosticsInfo
  ) -> Self {
    var copy: Self = self
    copy.push(info)
    return copy
  }

  /// Record a value associated with last info message.
  /// Does nothing in nondebug builds. Recording value for a key
  /// which already holds any value replaces current one.
  ///
  /// - Parameters:
  ///   - value: Value to be recorded.
  ///   - key: Key identifying recorded value.
  public mutating func record(
    _ value: @autoclosure () -> Any,
    for key: StaticString
  ) {
    self.context.record(value(), for: key)
  }

  /// Record values associated with last info message.
  /// Does nothing in nondebug builds. Recording value for a key
  /// which already holds any value replaces current one.
  ///
  /// - Parameter values: Values to be recorded.
  public mutating func record(
    values: @autoclosure () -> Dictionary<StaticString, Any>
  ) {
    self.context.record(values: values())
  }

  /// Make a copy of this error while recording a value associated with last info message.
  /// Does nothing in nondebug builds. Recording value for a key
  /// which already holds any value replaces current one.
  ///
  /// - Parameters:
  ///   - value: Value to be recorded.
  ///   - key: Key identifying recorded value.
  /// - Returns: Copy of this error with additional value associated with current context.
  public func recording(
    _ value: @autoclosure () -> Any,
    for key: StaticString
  ) -> Self {
    #if DEBUG
    var copy: Self = self
    copy.record(value(), for: key)
    return copy
    #else
    return self
    #endif
  }

  /// Make a copy of this error while recording values associated with last info message.
  /// Does nothing in nondebug builds. Recording value for a key
  /// which already holds any value replaces current one.
  ///
  /// - Parameter values: Values to be recorded.
  /// - Returns: Copy of this error with additional values associated with current context.
  public func recording(
    values: @autoclosure () -> Dictionary<StaticString, Any>
  ) -> Self {
    #if DEBUG
    var copy: Self = self
    copy.record(values: values())
    return copy
    #else
    return self
    #endif
  }
}

/// TheError wrapping other error.
/// Used to add more context information for error handling.
public protocol TheErrorWrapper: TheError {

  var underlyingError: TheError { get }
}

extension Error {

  /// Cast error to TheError or convert it to Unidentified
  public func asTheError(
    file: StaticString = #fileID,
    line: UInt = #line
  ) -> TheError {
    (self as? TheError)?
      .recording("\(file):\(line)", for: "Casting from Error")
      ?? (self as? CancellationError)
      .map { _ in
        Cancelled
          .error()
          .recording(self, for: "underlyingError")
          .recording("\(file):\(line)", for: "Casting from Error")
      }
      ?? self.asUnidentified(file: file, line: line)
  }
}
