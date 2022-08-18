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

public struct UpdatesSequence: Sendable {

  internal typealias Generation = UInt64
  private struct State {

    fileprivate var active: Bool
    fileprivate var generation: Generation
    fileprivate var awaiters: Set<Awaiter<Generation?>>
  }

  private let state: CriticalState<State>

  internal init() {
    // Generation starting from 1
    // means that sequence will
    // emit initial value without
    // manually triggering update
    // after creating new instance
    let initialGeneration: Generation = 1
    self.state = .init(
      .init(
        active: true,
        generation: initialGeneration,
        awaiters: .init()
      ),
      cleanup: { state in
        for awaiter: Awaiter in state.awaiters {
          awaiter
            .resume(returning: .none)
        }
      }
    )
  }
}

extension UpdatesSequence {

  #if DEBUG
  public static var placeholder: Self {
    let sequence: Self = .init()
    sequence.endSequence()
    return sequence
  }
  #endif

  @Sendable internal func sendUpdate() {
    self.state
      .access { (state: inout State) in
        guard state.active else { return }
        state.generation &+= 1
        for awaiter: Awaiter in state.awaiters {
          awaiter
            .resume(returning: state.generation)
        }
        state.awaiters
          .removeAll(keepingCapacity: true)
      }
  }

  @Sendable internal func endSequence() {
    self.state
      .set(\.active, false)
  }
}

extension UpdatesSequence: AsyncSequence {

  public typealias Element = Void
  public struct AsyncIterator: AsyncIteratorProtocol {

    // initial generation is 1,
    // it should always return current value initially
    // only exception is Int64 overflow which will cause
    // single value to be not emmited properly
    // but it should not happen in a typical use anyway
    // ---
    // there is a risk of concurrent access to the generation
    // variable when the same instance of iterator is reused
    // across multiple threads, but it should be avoided anyway
    private var generation: Generation = 0
    private let update: @Sendable (Generation, Awaiter<Generation?>) -> Void
    private let cancel: @Sendable (PrivateID) -> Void
    #if DEBUG
    private var pendingNext: Bool = false
    #endif

    fileprivate init(
      update: @escaping @Sendable (Generation, Awaiter<Generation?>) -> Void,
      cancel: @escaping @Sendable (PrivateID) -> Void
    ) {
      self.update = update
      self.cancel = cancel
    }

    public mutating func next() async -> Element? {
      #if DEBUG
      assert(!pendingNext, "Cannot reuse iterators.")
      self.pendingNext = true
      defer { self.pendingNext = false }
      #endif
      let lastGeneration: Generation = self.generation

      let update: @Sendable (Generation, Awaiter<Generation?>) -> Void = self.update
      let cancel: @Sendable (PrivateID) -> Void = self.cancel

      let nextGeneration: Generation? = try? await Awaiter<Generation?>
        .withCancelation(
          cancel,
          execute: { awaiter in
            update(lastGeneration, awaiter)
          }
        )

      if let nextGeneration: Generation = nextGeneration {
        self.generation = nextGeneration
        return Element()
      }
      else {
        return .none
      }
    }
  }

  public nonisolated func makeAsyncIterator() -> AsyncIterator {
    AsyncIterator(
      update: { @Sendable (generation: Generation, awaiter: Awaiter) in
        self.update(
          after: generation,
          using: awaiter
        )
      },
      cancel: { @Sendable (id: PrivateID) -> Void in
        self.cancelAwaiter(withID: id)
      }
    )
  }
}

extension UpdatesSequence {

  internal func checkUpdate(
    after generation: Generation
  ) throws -> Generation {
    try self.state.access { (state: inout State) in
      guard state.active else { throw NoUpdate.error() }

      if state.generation > generation {
        return state.generation
      }
      else {
        throw NoUpdate.error()
      }
    }
  }
}

extension UpdatesSequence {

  fileprivate func update(
    after generation: Generation,
    using awaiter: Awaiter<Generation?>
  ) {
    self.state.access { (state: inout State) -> Void in
      guard state.active
      else { return awaiter.resume(returning: .none) }

      if state.generation > generation {
        awaiter
          .resume(returning: state.generation)
      }
      else {
        assert(
          !state.awaiters.contains(awaiter: awaiter),
          "Awaiters cannot be reused."
        )
        state.awaiters.update(with: awaiter)?
          .resume(throwing: CancellationError())
      }
    }
  }

  private func cancelAwaiter(
    withID id: PrivateID
  ) {
    let canceledAwaiter: Awaiter<Generation?>? = self.state.access { (state: inout State) in
      state.awaiters
        .removeAwaiter(withID: id)
    }
    canceledAwaiter?
      .resume(throwing: CancellationError())
  }
}
