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

import struct Foundation.UUID
import let os.CLOCK_MONOTONIC_RAW
import func os.clock_gettime_nsec_np

public final class UpdatesSource: Sendable {

  public static var never: UpdatesSource = .init(generation: .max)

  @usableFromInline internal typealias Generation = UInt64
  @usableFromInline internal typealias Awaiter = @Sendable (Generation) -> Void

  @usableFromInline internal struct State: Sendable {

    @usableFromInline internal var generation: Generation
    @usableFromInline internal var awaiters: Array<Awaiter>
  }

  public var updates: Updates {
    if self.generation == .max {
      return .never
    }
    else {
      return Updates(for: self)
    }
  }
  @usableFromInline internal let state: CriticalState<State>

  public convenience init() {
    self.init(generation: 1)
  }

  @usableFromInline internal init(
    generation: Generation
  ) {
    // Generation `max` will be ended updates
    // (inactive) from the beginning.
    // Generation starting from 0
    // will wait for the initial update.
    // Generation starting from 1
    // means that sequence will
    // emit initial value without
    // manually triggering update
    // after creating new instance
    self.state = .init(
      .init(
        generation: generation,
        awaiters: .init()
      ),
      cleanup: { (state: State) in
        for resume: Awaiter in state.awaiters {
          resume(.max)
        }
      }
    )
  }
}

extension UpdatesSource {

  @inlinable
  @Sendable public func sendUpdate() {
    // using CLOCK_MONOTONIC_RAW allows monotonically
    // increasing value which has very low risk of duplication
    // across multiple instances, it is like very precise timestamp
    // of when update was sent, measured in CPU ticks
    // generation is prepared before accessing the lock
    // os_unfair_lock which is used here can result in non increasing
    // value (lower value assigned after higher), it also allows
    // skipping old pending updates during high rate updates
    let updateGeneration: Generation = clock_gettime_nsec_np(CLOCK_MONOTONIC_RAW)
    let deliverUpdate: () -> Void =
      self.state.access { (state: inout State) -> () -> Void in
        // do not deliver old updates - os_unfair_lock
        guard state.generation < updateGeneration
        else {
          // generation `max` is terminal, shouldn't have awaiters
          assert(state.generation != .max || state.awaiters.isEmpty)
          return {}
        }
        state.generation = updateGeneration
        let awaiters: Array<Awaiter> = state.awaiters
        state.awaiters = .init()
        return {
          for resume: Awaiter in awaiters {
            resume(updateGeneration)
          }
        }
      }

    deliverUpdate()
  }

  @inlinable
  @Sendable public func terminate() {
    let deliverUpdate: () -> Void =
      self.state.access { (state: inout State) -> () -> Void in
        guard state.generation != .max
        else {
          // generation `max` is terminal, shouldn't have awaiters
          assert(state.awaiters.isEmpty)
          return {}
        }
        state.generation = .max
        let awaiters: Array<Awaiter> = state.awaiters
        state.awaiters = .init()
        return {
          for resume: Awaiter in awaiters {
            resume(.max)
          }
        }
      }

    deliverUpdate()
  }
}

extension UpdatesSource {

  @_transparent
  @usableFromInline
  internal var generation: Generation {
    self.state.access(\.generation)
  }

  @_transparent
  @usableFromInline
  internal func update(
    after generation: Generation,
    deliver: @escaping Awaiter
  ) {
    assert(generation != .max, "Shouldn't ask if already finished")
    self.state.access { (state: inout State) in
      if state.generation > generation {
        return deliver(state.generation)
      }
      else {
        // awaiters are not removed when cancelled,
        // this makes them occupy memory until
        // update or terminate is delivered
        // despite occupying additional memory it requires
        // less computation since it asks for lock less frequent
        state.awaiters.append(deliver)
      }
    }
  }
}
