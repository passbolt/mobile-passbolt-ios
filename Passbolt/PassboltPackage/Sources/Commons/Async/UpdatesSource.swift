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

  @usableFromInline internal typealias Generation = UInt64

  @usableFromInline internal struct State: Sendable {

    @usableFromInline internal var generation: Generation
    @usableFromInline internal var awaiters: Dictionary<IID, UnsafeContinuation<Generation?, Never>>
  }

  @usableFromInline internal let state: CriticalState<State>

  public convenience init() {
    self.init(generation: 1)
  }

  @usableFromInline internal init(
    generation: Generation
  ) {
    // Generation `none` will be ended updates
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
        for continuation: UnsafeContinuation<Generation?, Never> in state.awaiters.values {
          continuation.resume(returning: .none)
        }
      }
    )
  }
}

extension UpdatesSource {

  @_transparent
  public static var placeholder: UpdatesSource {
    UpdatesSource(generation: .max)
  }

  public var updates: Updates { .init(for: self) }

  internal var generation: Generation? {
    self.state.access(\.generation)
  }

  @inlinable
  @Sendable public func sendUpdate() {
    // using CLOCK_MONOTONIC_RAW allows monotonically
    // increasing value which has very low risk of duplication
    // across multiple instances, it is like very precise timestamp
    // of when update was sent, measured in CPU ticks
    // generation is prepared before accessing the lock
    // os_unfair_lock which is used here can result in non increasing
    // valuse (lower value assigned after higher), it also allows
    // skipping old pending updates during high rate updates
    let updateGeneration: Generation = clock_gettime_nsec_np(CLOCK_MONOTONIC_RAW)
    let resumeAwaiters: () -> Void =
      self.state
      .access { (state: inout State) -> () -> Void in
        if state.generation != .max {
          guard state.generation < updateGeneration
          else { return {} }  // do not deliver old updates
          state.generation = updateGeneration
          let awaiters = state.awaiters.values
          state.awaiters.removeAll()
          return {
            for continuation: UnsafeContinuation<Generation?, Never> in awaiters {
              continuation.resume(returning: updateGeneration)
            }
          }
        }
        else {
          assert(state.awaiters.isEmpty)
          return {}  // generation `max` means terminated, nothing to resume
        }
      }

    resumeAwaiters()
  }

  @inlinable
  @Sendable public func terminate() {
    let resumeAwaiters: () -> Void =
      self.state
      .access { (state: inout State) -> () -> Void in
        if state.generation != .max {
          state.generation = .max
          let awaiters = state.awaiters.values
          state.awaiters.removeAll()
          return {
            for continuation: UnsafeContinuation<Generation?, Never> in awaiters {
              continuation.resume(returning: .none)
            }
          }
        }
        else {
          assert(state.awaiters.isEmpty)
          return {}  // generation `none` means terminated, nothing to resume
        }
      }

    resumeAwaiters()
  }
}

extension UpdatesSource {

  @_transparent @available(*, deprecated, message: "Please use `hasUpdate` instead")
  internal func checkUpdate(
    after generation: Generation
  ) throws -> Generation {
    try self.state.access { (state: inout State) in
      if state.generation > generation {
        return state.generation
      }
      else {
        throw NoUpdate.error()
      }
    }
  }
}

extension UpdatesSource {

  @_transparent
  @usableFromInline
  internal func hasUpdate(
    after generation: Generation
  ) -> Bool {
    self.state.access { (state: inout State) -> Bool in
      if state.generation != .max {
        return state.generation > generation
      }
      else {
        return false
      }
    }
  }

  @_transparent
  @usableFromInline
  internal func update(
    after generation: inout Generation
  ) async -> Void? {
    let iid: IID = .init()
    let updated: Generation? = await withTaskCancellationHandler(
      operation: { () async -> Generation? in
        await withUnsafeContinuation { (continuation: UnsafeContinuation<Generation?, Never>) in
          self.state.access { (state: inout State) in
            guard state.generation != .max, !Task.isCancelled
            else { return continuation.resume(returning: .none) }

            if state.generation > generation {
              return continuation.resume(returning: state.generation)
            }
            else {
              state.awaiters[iid] = continuation
            }
          }
        }
      },
      onCancel: {
        self.state.exchange(\.awaiters[iid], with: .none)?
          .resume(returning: .none)
      }
    )

    if Task.isCancelled {
      // do not update generation on cancelled
      return .none
    }
    else if let updated: Generation {
      generation = updated
      return Void()
    }
    else {
      generation = .max
      return .none
    }
  }
}
