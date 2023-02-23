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

import AsyncAlgorithms
import Commons
import Features

import struct Foundation.Date
import let Foundation.NSEC_PER_SEC
import func Foundation.time

// MARK: - Interface

public struct OSTime {

  public var timestamp: @Sendable () -> Timestamp
  public var waitFor: @Sendable (Seconds) async throws -> Void
  public var timerSequence: @Sendable (Seconds) -> AnyAsyncSequence<Void>
}

extension OSTime: StaticFeature {

  #if DEBUG
  nonisolated public static var placeholder: Self {
    Self(
      timestamp: unimplemented0(),
      waitFor: unimplemented1(),
      timerSequence: unimplemented1()
    )
  }
  #endif
}

extension OSTime {

  public func dateNow() -> Date {
    timestamp().asDate
  }
}

// MARK: - Implementation

extension OSTime {

  @available(iOS 16.0, *)
  fileprivate static var live: Self {
    let continuousClock: ContinuousClock = .init()

    @Sendable func timestamp() -> Timestamp {
      .init(rawValue: time(nil))
    }

    @Sendable func waitFor(
      _ time: Seconds
    ) async throws {
      try await continuousClock
        .sleep(
          until: continuousClock
            .now
            .advanced(
              by: .seconds(time.rawValue)
            )
        )
    }

    @Sendable func timerSequence(
      _ time: Seconds
    ) -> AnyAsyncSequence<Void> {
      AsyncTimerSequence(
        interval: .seconds(time.rawValue),
        tolerance: .milliseconds(100),
        clock: continuousClock
      )
      .map { _ in Void() }
      .asAnyAsyncSequence()
    }

    return Self(
      timestamp: timestamp,
      waitFor: waitFor(_:),
      timerSequence: timerSequence(_:)
    )
  }

  @available(iOS, deprecated: 16, message: "Please switch to `live`")
  fileprivate static var liveOld: Self {

    @Sendable func timestamp() -> Timestamp {
      .init(rawValue: time(nil))
    }

    @Sendable func waitFor(
      _ time: Seconds
    ) async throws {
      try await Task.sleep(
        nanoseconds: NSEC_PER_SEC * time.rawValue
      )
    }

    @Sendable func timerSequence(
      _ delay: Seconds
    ) -> AnyAsyncSequence<Void> {
      .init {
        while true {
          // this is not fully correct since
          // timer using Task.sleep drifts
          // substantially and quickly
          // becomes out of sync, however
          // this is deprecated anyway
          try? await waitFor(delay)
        }
      }
    }

    return Self(
      timestamp: timestamp,
      waitFor: waitFor(_:),
      timerSequence: timerSequence(_:)
    )
  }
}

extension FeaturesRegistry {

  internal mutating func useOSTime() {
    if #available(iOS 16.0, *) {
      self.use(
        OSTime.live
      )
    }
    else {
      self.use(
        OSTime.liveOld
      )
    }
  }
}
