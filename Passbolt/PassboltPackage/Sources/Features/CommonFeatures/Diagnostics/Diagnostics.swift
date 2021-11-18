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

import struct Foundation.Date
import struct Foundation.UUID
import class os.OSLog
import let os.SIGTRAP
import func os.os_log
import func os.os_signpost
import func os.raise

public struct Diagnostics {

  public var debugLog: (String) -> Void
  public var diagnosticLog: (StaticString, StaticString?) -> Void
  public var measurePerformance: (StaticString) -> TimeMeasurement
  public var uniqueID: () -> String
  public var breakpoint: () -> Void
}

extension Diagnostics {

  public struct TimeMeasurement {

    public let event: (StaticString) -> Void
    public let end: () -> Void
  }
}

extension Diagnostics: Feature {

  public static func load(
    in environment: Environment,
    using features: FeatureFactory,
    cancellables: Cancellables
  ) -> Diagnostics {
    #if DEBUG
    let time: Time = environment.time
    #endif
    let uuidGenerator: UUIDGenerator = environment.uuidGenerator
    let diagnosticLog: OSLog = .init(subsystem: "com.passbolt.mobile", category: "diagnostic")
    let perfomanceLog: OSLog = .init(subsystem: "com.passbolt.mobile.performance", category: .pointsOfInterest)

    return Self(
      debugLog: { message in
        #if DEBUG
        print(
          "[\(Date(timeIntervalSince1970: Double(time.timestamp())))] \(message)"
        )
        #endif
      },
      diagnosticLog: { message, argument in
        if let argument: CVarArg = argument?.description {
          os_log(.info, log: diagnosticLog, message, argument)
        }
        else {
          os_log(.info, log: diagnosticLog, message)
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
    self.diagnosticLog(message, variable)
  }

  // drop all diagnostics
  public static var disabled: Self {
    Self(
      debugLog: { _ in },
      diagnosticLog: { _, _ in },
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
      debugLog: Commons.placeholder("You have to provide mocks for used methods"),
      diagnosticLog: Commons.placeholder("You have to provide mocks for used methods"),
      measurePerformance: Commons.placeholder("You have to provide mocks for used methods"),
      uniqueID: Commons.placeholder("You have to provide mocks for used methods"),
      breakpoint: Commons.placeholder("You have to provide mocks for used methods")
    )
  }
}
#endif
