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

import struct Foundation.Date
import struct Foundation.UUID
import Environment

public struct Diagnostics {
  
  public var log: (String) -> Void
  public var uniqueID: () -> String
}

extension Diagnostics: Feature {
  
  public typealias Environment = (
    time: Time,
    uuidGenerator: UUIDGenerator,
    logger: Logger
  )
  
  public static func environmentScope(
    _ rootEnvironment: RootEnvironment
  ) -> Environment {
    (
      time: rootEnvironment.time,
      uuidGenerator: rootEnvironment.uuidGenerator,
      logger: rootEnvironment.logger
    )
  }
  
  public static func load(
    in environment: Environment,
    using features: FeatureFactory,
    cancellables: inout Array<AnyCancellable>
  ) -> Diagnostics {
    Self(
      log: { message in
        environment
          .logger
          .consoleLog(
            "[\(Date(timeIntervalSince1970: Double(environment.time.timestamp())))] \(message)"
          )
      },
      uniqueID: { environment.uuidGenerator().uuidString }
    )
  }
}

extension Diagnostics {
  
  /// Debug log is stripped out in release build
  public func debugLog(_ message: String) {
    #if DEBUG
    log(message)
    #endif
  }
  
  // drop all diagnostics
  public static var disabled: Self {
    Self(
      log: { _ in },
      uniqueID: { UUID().uuidString }
    )
  }
}

#if DEBUG
extension Diagnostics {
  
  // placeholder implementation for mocking and testing, unavailable in release
  public static var placeholder: Self {
    Self(
      log: Commons.placeholder("You have to provide mocks for used methods"),
      uniqueID: Commons.placeholder("You have to provide mocks for used methods")
    )
  }
}
#endif
