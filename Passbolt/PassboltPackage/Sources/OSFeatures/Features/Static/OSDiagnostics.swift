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

import Commons
import OSLog

import struct Foundation.Date
import struct Foundation.UUID
import struct OSLog.Logger
import class UIKit.UIDevice
import let os.SIGTRAP
import func os.raise

// MARK: - Interface

public struct OSDiagnostics {

  public var trace: () -> Trace
  public var debugLog: (String) -> Void
  public var diagnosticLog: (StaticString, MessageVariable) -> Void
  public var diagnosticsInfo: () -> Array<String>
  public var breakpoint: () -> Void
}

extension OSDiagnostics {

  public struct Trace {

    fileprivate var debugLog: (String) -> Void
    fileprivate var diagnosticLog: (StaticString, MessageVariable) -> Void
  }

  public enum MessageVariable {

    case none
    case variable(StaticString)
    case variables(StaticString, StaticString)
    case unsafeVariable(String)
    case unsafeVariables(String, String)
  }
}

extension OSDiagnostics: StaticFeature {

  #if DEBUG
  public static var placeholder: Self {
    Self(
      trace: unimplemented0(),
      debugLog: unimplemented1(),
      diagnosticLog: unimplemented2(),
      diagnosticsInfo: unimplemented0(),
      breakpoint: unimplemented0()
    )
  }
  #endif
}

// MARK: - Implementation

extension OSDiagnostics {

  fileprivate static var live: Self {
    #if DEBUG
    let debugLog: Logger = .init(
      subsystem: "com.passbolt.mobile",
      category: "debug"
    )
    #endif
    let diagnosticLog: Logger = .init(
      subsystem: "com.passbolt.mobile",
      category: "diagnostic"
    )
    let environmentInfo: String =
      """
      Device: \(UIDevice.current.localizedModel) \(UIDevice.current.model)
      OS: \(UIDevice.current.systemVersion)
      App: \(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?.?.?")
      ----------
      """

    func trace() -> Trace {
      let id: String = UUID().uuidString

      return .init(
        debugLog: { (message: String) in
          #if DEBUG
          debugLog.log(
            level: .debug,
            "[\(id, privacy: .public)] \(message, privacy: .public)"
          )
          #endif
        },
        diagnosticLog: { (message: StaticString, variable: MessageVariable) in
          switch variable {
          case .none:
            diagnosticLog.log(
              level: .default,
              "[\(id, privacy: .public)] \(message, privacy: .public)"
            )

          case let .variable(string):
            diagnosticLog.log(
              level: .default,
              "[\(id, privacy: .public)] \(message, privacy: .public) \(string, privacy: .public)"
            )

          case let .variables(first, second):
            diagnosticLog.log(
              level: .default,
              "[\(id, privacy: .public)] \(message, privacy: .public) \(first, privacy: .public) \(second, privacy: .public)"
            )

          case let .unsafeVariable(string):
            diagnosticLog.log(
              level: .default,
              "[\(id, privacy: .public)] \(message, privacy: .public) \(string, privacy: .public)"
            )

          case let .unsafeVariables(first, second):
            diagnosticLog.log(
              level: .default,
              "[\(id, privacy: .public)] \(message, privacy: .public) \(first, privacy: .public) \(second, privacy: .public)"
            )
          }
        }
      )
    }

    func debugLog(
      _ message: String
    ) {
      #if DEBUG
      debugLog.log(
        level: .debug,
        "\(message, privacy: .public)"
      )
      #endif
    }

    func diagnosticLog(
      _ message: StaticString,
      variable: MessageVariable
    ) {
      switch variable {
      case .none:
        diagnosticLog.log(
          level: .default,
          "\(message, privacy: .public)"
        )

      case let .variable(string):
        diagnosticLog.log(
          level: .default,
          "\(message, privacy: .public) \(string, privacy: .public)"
        )

      case let .variables(first, second):
        diagnosticLog.log(
          level: .default,
          "\(message, privacy: .public) \(first, privacy: .public) \(second, privacy: .public)"
        )

      case let .unsafeVariable(string):
        diagnosticLog.log(
          level: .default,
          "\(message, privacy: .public) \(string, privacy: .public)"
        )

      case let .unsafeVariables(first, second):
        diagnosticLog.log(
          level: .default,
          "\(message, privacy: .public) \(first, privacy: .public) \(second, privacy: .public)"
        )
      }
    }

    func diagnosticsInfo() -> Array<String> {
      do {
        let logStore: OSLogStore = try .init(scope: .currentProcessIdentifier)
        let dateFormatter: DateFormatter = .init()
        dateFormatter.timeZone = .init(secondsFromGMT: 0)
        dateFormatter.dateFormat = "YYYY-MM-dd HH:mm:ss"
        return try [environmentInfo]
          + logStore
          .getEntries(
            at:
              logStore
              .position(  // last hour
                date: Date(timeIntervalSinceNow: -60 * 60)
              ),
            matching: NSPredicate(
              format: "category == %@ OR category == %@",
              argumentArray: ["diagnostic", "error"]
            )
          )
          .map { logEntry in
            "[\(dateFormatter.string(from: logEntry.date))] \(logEntry.composedMessage)"
          }
      }
      catch {
        return [
          environmentInfo,
          "Logs are not available",
        ]
      }
    }

    func breakpoint() {
      #if DEBUG
      raise(SIGTRAP)
      #endif
    }

    return .init(
      trace: trace,
      debugLog: debugLog(_:),
      diagnosticLog: diagnosticLog(_:variable:),
      diagnosticsInfo: diagnosticsInfo,
      breakpoint: breakpoint
    )
  }

  // drop all diagnostics
  public nonisolated static var disabled: Self {
    .init(
      trace: {
        .init(
          debugLog: { _ in },
          diagnosticLog: { _, _ in }
        )
      },
      debugLog: { _ in },
      diagnosticLog: { _, _ in },
      diagnosticsInfo: { ["OSDiagnostics disabled"] },
      breakpoint: {}
    )
  }
}

extension OSDiagnostics {

  public func log<Variable>(
    debug message: @autoclosure () -> Variable
  ) {
    #if DEBUG
    self.debugLog(String(describing: message()))
    #endif
  }

  public func log(
    diagnostic message: StaticString,
    _ variable: OSDiagnostics.MessageVariable = .none
  ) {
    self.diagnosticLog(message, variable)
  }

  public func log<Variable>(
    diagnostic message: StaticString,
    unsafe variable: Variable
  ) {
    self.log(diagnostic: message, .unsafeVariable(String(describing: variable)))
  }

  public func log<First, Second>(
    diagnostic message: StaticString,
    unsafe first: First,
    _ second: Second
  ) {
    self.log(
      diagnostic: message,
      .unsafeVariables(
        String(describing: first),
        String(describing: second)
      )
    )
  }

  public func log(
    diagnostic message: StaticString,
    _ variable: StaticString
  ) {
    self.log(diagnostic: message, .variable(variable))
  }

  public func log(
    diagnostic message: StaticString,
    _ first: StaticString,
    _ second: StaticString
  ) {
    self.log(diagnostic: message, .variables(first, second))
  }

  public func log(
    error: Error,
    info: DiagnosticsInfo? = .none
  ) {
    let theError: TheError
    switch error {
    case is CancellationError, is Cancelled:
      return  // ignore log
    case let error:
      theError =
        info
        .map { error.asTheError().pushing($0) }
        ?? error.asTheError()
    }

    #if DEBUG
    self.debugLog(theError.debugDescription)
    #endif
    for message in theError.diagnosticMessages {
      self.log(diagnostic: message)
    }
  }

  public func logCatch(
    info: DiagnosticsInfo? = .none,
    _ operation: () throws -> Void
  ) {
    do {
      try operation()
    }
    catch {
      self.log(
        error: error,
        info: info
      )
    }
  }

  @_transparent
  public func withLogCatch(
    info: DiagnosticsInfo? = .none,
    _ operation: () async throws -> Void
  ) async {
    do {
      try await operation()
    }
    catch is Cancelled where Task.isCancelled {
      // NOP - ignore in logs
    }
    catch {
      self.log(
        error: error,
        info: info
      )
    }
  }
}

extension OSDiagnostics.Trace {

  public func log<Variable>(
    debug message: @autoclosure () -> Variable
  ) {
    #if DEBUG
    self.debugLog(String(describing: message()))
    #endif
  }

  public func log(
    diagnostic message: StaticString,
    _ variable: OSDiagnostics.MessageVariable = .none
  ) {
    self.diagnosticLog(message, variable)
  }

  public func log<Variable>(
    diagnostic message: StaticString,
    unsafe variable: Variable
  ) {
    self.log(diagnostic: message, .unsafeVariable(String(describing: variable)))
  }

  public func log<First, Second>(
    diagnostic message: StaticString,
    unsafe first: First,
    _ second: Second
  ) {
    self.log(
      diagnostic: message,
      .unsafeVariables(
        String(describing: first),
        String(describing: second)
      )
    )
  }

  public func log(
    diagnostic message: StaticString,
    _ variable: StaticString
  ) {
    self.log(diagnostic: message, .variable(variable))
  }

  public func log(
    diagnostic message: StaticString,
    _ first: StaticString,
    _ second: StaticString
  ) {
    self.log(diagnostic: message, .variables(first, second))
  }

  public func log(
    error: Error,
    info: DiagnosticsInfo? = .none
  ) {
    let theError: TheError
    switch error {
    case is CancellationError, is Cancelled:
      return  // ignore log
    case let error:
      theError =
        info
        .map { error.asTheError().pushing($0) }
        ?? error.asTheError()
    }

    #if DEBUG
    self.debugLog(theError.debugDescription)
    #endif
    for message in theError.diagnosticMessages {
      self.log(diagnostic: message)
    }
  }
}

extension FeaturesRegistry {

  internal mutating func useOSDiagnostics() {
    self.use(
      OSDiagnostics.live
    )
  }

  internal mutating func useDisabledOSDiagnostics() {
    self.use(
      OSDiagnostics.disabled
    )
  }
}
