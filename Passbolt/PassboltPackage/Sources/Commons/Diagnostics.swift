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

import OSLog

import struct Foundation.Date
import class UIKit.UIDevice

// MARK: - Interface

public struct Diagnostics {

  #if DEBUG
  public static var shared: Self = {
    let enabled: Bool = {
      // Disabled automatically for XCTest
      !(Bundle.main.infoDictionary?["CFBundleName"] as? String == "xctest"
        || ProcessInfo.processInfo.environment.keys.contains("XCTestBundlePath")
        || ProcessInfo.processInfo.environment.keys.contains("XCTestSessionIdentifier"))
    }()
    if enabled {
      return .live
    }
    else {
      return .disabled
    }
  }()
  #else
  public static let shared: Self = .live
  #endif
  public static var logger: Logger {
    @_transparent _read { yield Self.shared.logger }
  }
  @_transparent public static func debug<Variable>(
    _ variable: @autoclosure @escaping () -> Variable
  ) {
    #if DEBUG
		Self.logger.log(level: .debug, "🏴‍☠️ \(String(describing: variable()), privacy: .private)")
    #endif
  }

  public let logger: Logger
  public var info: () -> Array<String>
}

// MARK: - Implementation

extension Diagnostics {

  fileprivate static var live: Self {
    let logger: Logger = .init(
      subsystem: "com.passbolt.mobile",
      category: "diagnostic"
    )
    let environmentInfo: String =
      """
      Device: \(UIDevice.current.model)
      OS: \(UIDevice.current.systemVersion)
      App: \(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?.?.?")
      ----------
      """

    func info() -> Array<String> {
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
              format: "category == %@",
              argumentArray: ["diagnostic"]
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

    return .init(
      logger: logger,
      info: info
    )
  }

  // drop all diagnostics
  public nonisolated static var disabled: Self {
    .init(
      logger: .init(.disabled),
      info: { ["Diagnostics disabled"] }
    )
  }
}

extension Error {

  @_transparent @discardableResult
  public func logged(
    info: DiagnosticsInfo? = .none
  ) -> TheError {
    let theError: TheError = self.asTheError()
    if let info: DiagnosticsInfo {
      theError
        .pushing(info)
        .log()
    }
    else {
      theError
        .log()
    }
    return theError
  }
}

@_transparent
public func withLogCatch(
  failInfo: StaticString? = .none,
  file: StaticString = #fileID,
  line: UInt = #line,
  @_inheritActorContext fallback: ((Error) -> Void)? = .none,
  _ operation: () throws -> Void
) {
  do {
    try operation()
  }
  catch {
    let error: TheError =
      error
      .logged(
        info:
          failInfo
          .map { .message($0, file: file, line: line) }
      )
    fallback?(error)
  }
}

@_transparent
public func withLogCatch<Returned>(
  failInfo: StaticString? = .none,
  file: StaticString = #fileID,
  line: UInt = #line,
  @_inheritActorContext fallback: (Error) -> Returned,
  _ operation: () throws -> Returned
) -> Returned {
  do {
    return try operation()
  }
  catch {
    let error: TheError =
      error
      .logged(
        info:
          failInfo
          .map { .message($0, file: file, line: line) }
      )
    return fallback(error)
  }
}

@_transparent
public func withLogCatch(
  failInfo: StaticString? = .none,
  file: StaticString = #fileID,
  line: UInt = #line,
  @_inheritActorContext fallback: ((Error) async -> Void)? = .none,
  _ operation: () async throws -> Void
) async {
  do {
    try await operation()
  }
  catch {
    let error: TheError =
      error
      .logged(
        info:
          failInfo
          .map { .message($0, file: file, line: line) }
      )
    await fallback?(error)
  }
}

@_transparent
public func withLogCatch<Returned>(
  failInfo: StaticString? = .none,
  file: StaticString = #fileID,
  line: UInt = #line,
  @_inheritActorContext fallback: (Error) async -> Returned,
  _ operation: () async throws -> Returned
) async -> Returned {
  do {
    return try await operation()
  }
  catch {
    let error: TheError =
      error
      .logged(
        info:
          failInfo
          .map { .message($0, file: file, line: line) }
      )
    return await fallback(error)
  }
}
