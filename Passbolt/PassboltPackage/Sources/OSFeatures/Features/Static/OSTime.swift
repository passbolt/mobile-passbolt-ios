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
import let os.CLOCK_MONOTONIC
import func os.clock_gettime_nsec_np

// MARK: - Interface

public struct OSTime {

  public var timestamp: @Sendable () -> Timestamp
  public var waitFor: @Sendable (Seconds) async throws -> Void
  public var timerSequence: @Sendable (Seconds) -> AnyAsyncSequence<Void>
  public var timeVariable: @Sendable (Seconds) -> TimeVariable
}

extension OSTime: StaticFeature {

  #if DEBUG
  nonisolated public static var placeholder: Self {
    Self(
      timestamp: unimplemented0(),
      waitFor: unimplemented1(),
      timerSequence: unimplemented1(),
      timeVariable: unimplemented1()
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
      .init(rawValue: Int64(time(nil)))
    }

    @Sendable func waitFor(
      _ delay: Seconds
    ) async throws {
      try await continuousClock
        .sleep(
          until: continuousClock
            .now
            .advanced(
              by: .seconds(delay.rawValue)
            )
        )
    }

    @Sendable func timerSequence(
      _ period: Seconds
    ) -> AnyAsyncSequence<Void> {
      AsyncTimerSequence(
        interval: .seconds(period.rawValue),
        tolerance: .milliseconds(100),
        clock: continuousClock
      )
      .map { _ in }
      .asAnyAsyncSequence()
    }

    return Self(
      timestamp: timestamp,
      waitFor: waitFor(_:),
      timerSequence: timerSequence(_:),
      timeVariable: { (period: Seconds) in
        TimeVariable(period: NSEC_PER_SEC * UInt64(period.rawValue))
      }
    )
  }

  @available(iOS, deprecated: 16, message: "Please switch to `live`")
  fileprivate static var liveOld: Self {

    @Sendable func timestamp() -> Timestamp {
      .init(rawValue: Int64(time(nil)))
    }

    @Sendable func waitFor(
      _ time: Seconds
    ) async throws {
      try await Task.sleep(
        nanoseconds: NSEC_PER_SEC * UInt64(time.rawValue)
      )
    }

    @Sendable func timerSequence(
      _ period: Seconds
    ) -> AnyAsyncSequence<Void> {
      .init { () -> Void? in
        // iterator `next`
        // this is not fully correct since
        // timer using Task.sleep drifts
        // substantially and quickly
        // becomes out of sync, however
        // this is deprecated anyway
        try? await Task.sleep(
          nanoseconds: NSEC_PER_SEC * UInt64(period.rawValue)
        )
      }
    }

    return Self(
      timestamp: timestamp,
      waitFor: waitFor(_:),
      timerSequence: timerSequence(_:),
      timeVariable: { (period: Seconds) in
        TimeVariable(period: NSEC_PER_SEC * UInt64(period.rawValue))
      }
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

// TODO: change implementation from iOS 16+ and use AnyUpdatable<Timestamp> as an interface
public final class TimeVariable: @unchecked Sendable {

  @usableFromInline internal typealias DeliverUpdate = @Sendable (Update<Void>) -> Void

  @usableFromInline @inline(__always) internal var lock: UnsafeLock
  @usableFromInline @inline(__always) internal var nextUpdateTime: UInt64
  @usableFromInline @inline(__always) internal var lastUpdateGeneration: UpdateGeneration
  @usableFromInline @inline(__always) internal var runningUpdate: Task<Void, Never>?
  @usableFromInline @inline(__always) internal var deliverUpdate: DeliverUpdate?
  @usableFromInline @inline(__always) internal let period: UInt64

  internal init(
    period: UInt64
  ) {
    self.lock = .init()
    self.nextUpdateTime = clock_gettime_nsec_np(CLOCK_MONOTONIC) + period
    self.lastUpdateGeneration = .next()
    self.deliverUpdate = .none
    self.period = period
  }

  deinit {
    // resume all waiting to avoid hanging
    self.deliverUpdate?(.cancelled())
  }
}

extension TimeVariable: Updatable {

  public var generation: UpdateGeneration {
    @_transparent @Sendable _read {
      self.lock.unsafe_lock()
      if self.nextUpdateTime <= clock_gettime_nsec_np(CLOCK_MONOTONIC) {
        self.nextUpdateTime = self.nextUpdateTime + period
        self.lastUpdateGeneration = .next()
        let deliverUpdate: DeliverUpdate? = self.deliverUpdate
        self.deliverUpdate = .none
        let update: Update<Void> = .init(
          generation: self.lastUpdateGeneration
        )
        yield self.lastUpdateGeneration
        self.lock.unsafe_unlock()
        // deliver update outside of lock
        deliverUpdate?(update)
      }
      else {
        yield self.lastUpdateGeneration
        self.lock.unsafe_unlock()
      }
    }
  }

  public var value: Void {
    @_transparent @Sendable get { Void() }
  }

  @Sendable public func notify(
    _ awaiter: @escaping @Sendable (Update<Void>) -> Void,
    after generation: UpdateGeneration
  ) {
    self.lock.unsafe_lock()

    let updateToDeliver: Update<Void>?
    if self.nextUpdateTime <= clock_gettime_nsec_np(CLOCK_MONOTONIC) {
      self.nextUpdateTime = self.nextUpdateTime + self.period
      self.lastUpdateGeneration = .next()
      updateToDeliver = .init(
        generation: self.lastUpdateGeneration
      )
    }
    else {
      updateToDeliver = .none
    }

    // check if current can be used to fulfill immediately
    if self.lastUpdateGeneration > generation {
      if let updateToDeliver: Update<Void> {
        let deliverUpdate: DeliverUpdate? = self.deliverUpdate
        self.deliverUpdate = .none
        self.lock.unsafe_unlock()
        // deliver updates outside of lock
        deliverUpdate?(updateToDeliver)
        awaiter(updateToDeliver)
      }
      else {
        self.lock.unsafe_unlock()
        // deliver update outside of lock
        awaiter(.init(generation: self.lastUpdateGeneration))
      }
    }
    else if let updateToDeliver: Update<Void> {
      let deliverUpdate: DeliverUpdate? = self.deliverUpdate
      self.deliverUpdate = .none
      self.lock.unsafe_unlock()
      // deliver updates outside of lock
      deliverUpdate?(updateToDeliver)
      awaiter(updateToDeliver)
    }
    else if case .none = self.runningUpdate {
      assert(self.deliverUpdate == nil, "No one should wait if there is no update running!")
      self.deliverUpdate = awaiter
      let nextUpdateTime: UInt64 = self.nextUpdateTime
      let period: UInt64 = self.period
      self.runningUpdate = .detached { [weak self] in
        try? await Task.sleep(nanoseconds: nextUpdateTime - clock_gettime_nsec_np(CLOCK_MONOTONIC))

        guard nextUpdateTime < clock_gettime_nsec_np(CLOCK_MONOTONIC)
        else { return }  // drop cancelled

        let update: Update<UInt64> = .init(
          generation: .next(),
          nextUpdateTime + period
        )
        self?.deliver(update)
      }
      return self.lock.unsafe_unlock()
    }
    // if update is in progress wait for it
    else if let currentDeliver: DeliverUpdate = self.deliverUpdate {
      self.deliverUpdate = { @Sendable(update:Update<Value>) in
        currentDeliver(update)
        awaiter(update)
      }
      self.lock.unsafe_unlock()
    }
    else {
      self.deliverUpdate = awaiter
      self.lock.unsafe_unlock()
    }
  }

  @Sendable private func deliver(
    _ update: Update<UInt64>
  ) {
    self.lock.unsafe_lock()
    guard self.lastUpdateGeneration < update.generation
    else {  // drop outdated updates but resume awaiters anyway
      self.runningUpdate.clearIfCurrent()
      let deliverUpdate: DeliverUpdate? = self.deliverUpdate
      self.deliverUpdate = .none
      self.lock.unsafe_unlock()
      // deliver update outside of lock
      deliverUpdate?(.init(generation: update.generation))
      return Void()
    }
    // time update can't produce errors
    self.nextUpdateTime = try! update.value
    self.lastUpdateGeneration = update.generation
    self.runningUpdate.clearIfCurrent()
    let deliverUpdate: DeliverUpdate? = self.deliverUpdate
    self.deliverUpdate = .none
    self.lock.unsafe_unlock()
    // deliver update outside of lock
    deliverUpdate?(.init(generation: update.generation))
  }
}

// Version below should be used from iOS 16+

//internal final class TimeVariable: @unchecked Sendable {
//
//	@usableFromInline internal typealias DeliverUpdate = @Sendable (Update<Void>) -> Void
//
//	@usableFromInline @inline(__always) internal var lock: UnsafeLock
//	@usableFromInline @inline(__always) internal var nextUpdateTime: ContinuousClock.Instant
//	@usableFromInline @inline(__always) internal var lastUpdateGeneration: UpdateGeneration
//	@usableFromInline @inline(__always) internal var runningUpdate: Task<Void, Never>?
//	@usableFromInline @inline(__always) internal var deliverUpdate: DeliverUpdate?
//	@usableFromInline @inline(__always) internal let period: Swift.Duration
//
//	internal init(
//		period: Swift.Duration
//	) {
//		self.lock = .init()
//		self.nextUpdateTime = .now.advanced(by: period)
//		self.lastUpdateGeneration = .next()
//		self.deliverUpdate = .none
//		self.period = period
//	}
//
//	deinit {
//	 // resume all waiting to avoid hanging
//	 self.deliverUpdate?(.cancelled())
// }
//}
//
//extension TimeVariable: Updatable {
//
//	internal var generation: UpdateGeneration {
//		@_transparent @Sendable _read {
//			self.lock.unsafe_lock()
//			if self.nextUpdateTime <= .now {
//				self.nextUpdateTime = self.nextUpdateTime.advanced(by: self.period)
//				self.lastUpdateGeneration = .next()
//				let deliverUpdate: DeliverUpdate? = self.deliverUpdate
//				self.deliverUpdate = .none
//				let update: Update<Void> = .init(
//					generation: self.lastUpdateGeneration
//				)
//				yield self.lastUpdateGeneration
//				self.lock.unsafe_unlock()
//				// deliver update outside of lock
//				deliverUpdate?(update)
//			}
//			else {
//				yield self.lastUpdateGeneration
//				self.lock.unsafe_unlock()
//			}
//		}
//	}
//
//	internal var value: Void {
//		@_transparent @Sendable get { Void() }
//	}
//
//	@Sendable internal func update(
//		_ awaiter: @escaping @Sendable (Update<Void>) -> Void,
//		after generation: UpdateGeneration
//	) {
//		self.lock.unsafe_lock()
//
//		let updateToDeliver: Update<Void>?
//		if self.nextUpdateTime <= .now {
//			self.nextUpdateTime = self.nextUpdateTime.advanced(by: self.period)
//			self.lastUpdateGeneration = .next()
//			updateToDeliver = .init(
//				generation: self.lastUpdateGeneration
//		 )
//		}
//		else {
//			updateToDeliver = .none
//		}
//
//		// check if current can be used to fulfill immediately
//		if self.lastUpdateGeneration > generation {
//			if let updateToDeliver: Update<Void> {
//				let deliverUpdate: DeliverUpdate? = self.deliverUpdate
//				self.deliverUpdate = .none
//				self.lock.unsafe_unlock()
//				// deliver updates outside of lock
//				deliverUpdate?(updateToDeliver)
//				awaiter(updateToDeliver)
//			}
//			else {
//				self.lock.unsafe_unlock()
//				// deliver update outside of lock
//				awaiter(.init(generation: self.lastUpdateGeneration))
//			}
//		}
//		else if let updateToDeliver: Update<Void> {
//			let deliverUpdate: DeliverUpdate? = self.deliverUpdate
//			 self.deliverUpdate = .none
//			 self.lock.unsafe_unlock()
//			 // deliver updates outside of lock
//			 deliverUpdate?(updateToDeliver)
//			 awaiter(updateToDeliver)
//		 }
//		else if case .none = self.runningUpdate {
//			assert(self.deliverUpdate == nil, "No one should wait if there is no update running!")
//			self.deliverUpdate = awaiter
//			let nextUpdateTime: ContinuousClock.Instant = self.nextUpdateTime
//			let period: Swift.Duration = self.period
//			self.runningUpdate = .detached { [weak self] in
//				let continuousClock: ContinuousClock = .init()
//				try? await continuousClock
//					.sleep(until: nextUpdateTime)
//
//				guard nextUpdateTime < .now
//				else { return } // drop cancelled
//
//				let update: Update<ContinuousClock.Instant> = .init(
//					generation: .next(),
//					nextUpdateTime.advanced(by: period)
//				)
//				self?.deliver(update)
//			}
//			return self.lock.unsafe_unlock()
//		}
//		// if update is in progress wait for it
//		else if let currentDeliver: DeliverUpdate = self.deliverUpdate {
//			self.deliverUpdate = { @Sendable(update:Update<Value>) in
//				currentDeliver(update)
//				awaiter(update)
//			}
//			self.lock.unsafe_unlock()
//		}
//		else {
//			assertionFailure("Update should not be running if no one is waiting!")
//			self.deliverUpdate = awaiter
//			self.lock.unsafe_unlock()
//		}
//	}
//
//	@Sendable private func deliver(
//		_ update: Update<ContinuousClock.Instant>
//	) {
//		self.lock.unsafe_lock()
//		guard self.lastUpdateGeneration < update.generation
//		else { // drop outdated updates but resume awaiters anyway
//			self.runningUpdate.clearIfCurrent()
//			let deliverUpdate: DeliverUpdate? = self.deliverUpdate
//			self.deliverUpdate = .none
//			self.lock.unsafe_unlock()
//			// deliver update outside of lock
//			deliverUpdate?(.init(generation: update.generation))
//			return Void()
//		}
//		// time update can't produce errors
//		self.nextUpdateTime = try! update.value
//		self.lastUpdateGeneration = update.generation
//		self.runningUpdate.clearIfCurrent()
//		let deliverUpdate: DeliverUpdate? = self.deliverUpdate
//		self.deliverUpdate = .none
//		self.lock.unsafe_unlock()
//		// deliver update outside of lock
//		deliverUpdate?(.init(generation: update.generation))
//	}
//}
