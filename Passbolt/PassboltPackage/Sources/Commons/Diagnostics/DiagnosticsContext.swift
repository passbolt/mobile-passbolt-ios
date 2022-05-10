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

public struct DiagnosticsContext {

  internal private(set) var infoStack: Array<DiagnosticsInfo>

  public mutating func push(
    _ info: DiagnosticsInfo
  ) {
    self.infoStack.append(info)
  }
}

extension DiagnosticsContext {

  /// Create instance of `DiagnosticsContext`.
  ///
  /// - Parameter info: `DiagnosticsInfo` used as initial context.
  /// - Returns: New instance of `DiagnosticsContext`.
  public static func context(
    _ info: DiagnosticsInfo
  ) -> Self {
    Self(
      infoStack: [info]
    )
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
    #if DEBUG
    // infoStack has always one or more elements
    let index: Array<DiagnosticsInfo>.Index = self.infoStack.index(before: self.infoStack.endIndex)
    self.infoStack[index].record(value(), for: key)
    #else
    /* NOP */
    #endif
  }

  /// Record a values associated with last info message.
  /// Does nothing in nondebug builds. Recording value for a key
  /// which already holds any value replaces current one.
  ///
  /// - Parameter values: Values to be recorded.
  public mutating func record(
    values: @autoclosure () -> Dictionary<StaticString, Any>
  ) {
    #if DEBUG
    // infoStack has always one or more elements
    let index: Array<DiagnosticsInfo>.Index = self.infoStack.index(before: self.infoStack.endIndex)
    self.infoStack[index].record(values())
    #else
    /* NOP */
    #endif
  }

  /// Make a copy of this context while recording a value associated with last info message.
  /// Does nothing in nondebug builds.Recording value for a key
  /// which already holds any value replaces current one.
  ///
  /// - Parameters:
  ///   - value: Value to be recorded.
  ///   - key: Key identifying recorded value.
  /// - Returns: Copy of this context with additional value associated.
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

  /// Make a copy of this context while recording values associated with last info message.
  /// Does nothing in nondebug builds.Recording value for a key
  /// which already holds any value replaces current one.
  ///
  /// - Parameter values: Values to be recorded.
  /// - Returns: Copy of this context with additional values associated.
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

extension DiagnosticsContext: CustomDebugStringConvertible {

  public var debugDescription: String {
    "\(Self.self)\n\(self.infoStack.reduce(into: "", { $0.append("\($1.debugDescription)\n")}))\n"
  }
}

extension DiagnosticsContext {

  /// Merge multiple contexts according to provided order.
  public static func merging(
    _ head: DiagnosticsContext,
    _ mid: DiagnosticsContext,
    _ tail: DiagnosticsContext...
  ) -> Self {
    .merging([head, mid] + tail)
  }

  /// Merge multiple contexts according to provided order.
  public static func merging(
    _ contexts: Array<DiagnosticsContext>
  ) -> Self {
    Self(
      infoStack:
        contexts
        .reduce(
          into: .init(),
          { result, context in
            result.append(contentsOf: context.infoStack)
          }
        )
    )
  }
}
