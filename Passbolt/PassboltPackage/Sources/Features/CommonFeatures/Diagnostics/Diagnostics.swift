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

import Environment
import OSLog

import struct Foundation.Date
import struct Foundation.UUID
import class UIKit.UIDevice
import let os.SIGTRAP
import func os.raise

public struct Diagnostics {

  public var debugLog: (String) -> Void
  public var diagnosticLog: (StaticString, DiagnosticMessageVariable) -> Void
  public var deviceInfo: () -> String
  public var collectedLogs: () -> Array<String>
  public var measurePerformance: (StaticString) -> TimeMeasurement
  public var uniqueID: () -> String
  public var breakpoint: () -> Void
}

extension Diagnostics {

  public struct TimeMeasurement {

    public let event: (StaticString) -> Void
    public let end: () -> Void
  }

  public enum DiagnosticMessageVariable {

    case none
    case variable(StaticString)
    case variables(StaticString, StaticString)
    case unsafeVariable(String)
  }
}

extension Diagnostics: Feature {

  public static func load(
    in environment: Environment,
    using features: FeatureFactory,
    cancellables: Cancellables
  ) -> Diagnostics {
    let time: Time = environment.time
    let uuidGenerator: UUIDGenerator = environment.uuidGenerator
    let diagnosticLog: OSLog = .init(subsystem: "com.passbolt.mobile", category: "diagnostic")
    let perfomanceLog: OSLog = .init(subsystem: "com.passbolt.mobile.performance", category: .pointsOfInterest)

    func hardwareModel() -> String {
      var systemInfo: utsname = .init()
      uname(&systemInfo)
      let machineMirror = Mirror(reflecting: systemInfo.machine)
      return machineMirror.children.reduce("") { identifier, element in
        guard let value = element.value as? Int8, value != 0 else { return identifier }
        return identifier + String(UnicodeScalar(UInt8(value)))
      }
    }

    func osVersion() -> String {
      UIDevice.current.systemVersion
    }

    func appVersion() -> String {
      Bundle.main
        .infoDictionary?["CFBundleShortVersionString"]
        as? String
        ?? "?.?.?"
    }

    return Self(
      debugLog: { message in
        #if DEBUG
        print(
          "[\(time.timestamp().asDate)] \(message)"
        )
        #endif
      },
      diagnosticLog: { message, variables in
        switch variables {
        case .none:
          os_log(.info, log: diagnosticLog, message)

        case let .variable(string):
          os_log(.info, log: diagnosticLog, message, string.description)

        case let .variables(first, second):
          os_log(.info, log: diagnosticLog, message, first.description, second.description)

        case let .unsafeVariable(string):
          os_log(.info, log: diagnosticLog, message, string)
        }
      },
      deviceInfo: {
        """
        Device: \(hardwareModel())
        OS: \(osVersion())
        App: \(appVersion())
        ----------
        """
      },
      collectedLogs: {
        if #available(iOS 15.0, *) {
          do {
            let logStore: OSLogStore = try .init(scope: .currentProcessIdentifier)
            let dateFormatter: DateFormatter = .init()
            dateFormatter.timeZone = .init(secondsFromGMT: 0)
            dateFormatter.dateFormat = "YYYY-MM-dd HH:mm:ss"
            return
              try logStore
              .getEntries(
                at:
                  logStore
                  .position(
                    date:
                      time
                      .dateNow()
                      .addingTimeInterval(-60 * 60 /* last hour */)
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
            return ["Logs are not available"]
          }
        }
        else {
          return ["Logs are available from iOS 15+"]
        }
      },
      measurePerformance: { name in
        let id: String = uuidGenerator().uuidString

        os_signpost(
          .begin,
          log: perfomanceLog,
          name: name,
          "[%{public}s] time measurement start",
          id
        )

        return TimeMeasurement(
          event: { eventName in
            os_signpost(
              .event,
              log: perfomanceLog,
              name: name,
              "[%{public}s] %{public}s",
              id,
              eventName.description
            )
          },
          end: {
            os_signpost(
              .end,
              log: perfomanceLog,
              name: name,
              "[%{public}s] time measurement end",
              id
            )
          }
        )
      },
      uniqueID: { uuidGenerator().uuidString },
      breakpoint: {
        #if DEBUG
        raise(SIGTRAP)
        #endif
      }
    )
  }
}

extension Diagnostics {

  public func diagnosticLog(
    _ message: StaticString,
    variable: StaticString? = nil
  ) {
    self.diagnosticLog(message, variable.map { .variable($0) } ?? .none)
  }

  public func diagnosticLog(
    _ message: StaticString,
    variables first: StaticString,
    _ second: StaticString
  ) {
    self.diagnosticLog(message, .variables(first, second))
  }

  public func diagnosticLog(
    _ message: StaticString,
    unsafeVariable: String
  ) {
    self.diagnosticLog(message, .unsafeVariable(unsafeVariable))
  }

  // drop all diagnostics
  public static var disabled: Self {
    Self(
      debugLog: { _ in },
      diagnosticLog: { _, _ in },
      deviceInfo: { "" },
      collectedLogs: { [] },
      measurePerformance: { _ in
        TimeMeasurement(event: { _ in }, end: {})
      },
      uniqueID: { UUID().uuidString },
      breakpoint: {}
    )
  }
}

#if DEBUG
extension Diagnostics {

  // placeholder implementation for mocking and testing, unavailable in release
  public static var placeholder: Self {
    Self(
      debugLog: unimplemented("You have to provide mocks for used methods"),
      diagnosticLog: unimplemented("You have to provide mocks for used methods"),
      deviceInfo: unimplemented("You have to provide mocks for used methods"),
      collectedLogs: unimplemented("You have to provide mocks for used methods"),
      measurePerformance: unimplemented("You have to provide mocks for used methods"),
      uniqueID: unimplemented("You have to provide mocks for used methods"),
      breakpoint: unimplemented("You have to provide mocks for used methods")
    )
  }
}
#endif
