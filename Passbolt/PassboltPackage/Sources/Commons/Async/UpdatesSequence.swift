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

public final class UpdatesSequence: Sendable {

  internal typealias Generation = UInt64
  fileprivate struct Awaiter: Hashable {

    fileprivate let id: AwaiterID
    private let continuation: AwaiterContinuation

    fileprivate init(
      id: AwaiterID,
      continuation: AwaiterContinuation
    ) {
      self.id = id
      self.continuation = continuation
    }

    fileprivate func resume(
      with generation: Generation?
    ) {
      self.continuation.resume(returning: generation)
    }

    fileprivate static func == (
      _ lhs: Self,
      _ rhs: Self
    ) -> Bool {
      lhs.id == rhs.id
    }

    fileprivate func hash(
      into hasher: inout Hasher
    ) {
      hasher.combine(self.id)
    }
  }
  #if DEBUG
  fileprivate typealias AwaiterContinuation = CheckedContinuation<Generation?, Never>
  #else
  fileprivate typealias AwaiterContinuation = UnsafeContinuation<Generation?, Never>
  #endif
  fileprivate typealias AwaiterID = ObjectIdentifier

  fileprivate struct State {
    fileprivate var awaiters: Set<Awaiter> = .init()
    fileprivate var generation: Generation
  }

  private let state: CriticalState<State>

  public init() {
    // Generation starting from 1
    // means that sequence will
    // emit initial value without
    // manually triggering update
    // after creating new instance
    let initialGeneration: Generation = 1
    self.state = .init(
      .init(generation: initialGeneration)
    )
  }

  deinit {
    for awaiter: Awaiter in self.state.get(\.awaiters) {
      awaiter
        .resume(with: .none)
    }
  }
}

extension UpdatesSequence {

  public func sendUpdate() {
    self.state
      .access { (state: inout State) in
        state.generation &+= 1
        for awaiter: Awaiter in state.awaiters {
          awaiter
            .resume(with: state.generation)
        }
        state.awaiters
          .removeAll(keepingCapacity: true)
      }
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
    private let update: @Sendable (Generation, AwaiterContinuation) -> Void
    private let cancelAwaiter: @Sendable () -> Void

    fileprivate init(
      update: @escaping @Sendable (Generation, Awaiter) -> Void,
      cancelAwaiter: @escaping @Sendable (AwaiterID) -> Void
    ) {
      final class ID {}
      let id: AwaiterID = AwaiterID(ID())

      self.update = { (generation: Generation, continuation: AwaiterContinuation) -> Void in
        update(
          generation,
          .init(
            id: id,
            continuation: continuation
          )
        )
      }
      self.cancelAwaiter = { @Sendable () -> Void in
        cancelAwaiter(id)
      }
    }

    public mutating func next() async -> Element? {
      let lastGeneration: Generation = self.generation
      let rawUpdate: (Generation, AwaiterContinuation) -> Void = self.update
      let update: @Sendable (AwaiterContinuation) -> Void = { (continuation: AwaiterContinuation) -> Void in
        rawUpdate(lastGeneration, continuation)
      }
      let nextGeneration: Generation? = await withTaskCancellationHandler(
        operation: {
          #if DEBUG
          await withCheckedContinuation { (continuation: AwaiterContinuation) in
            update(continuation)
          }
          #else
          await withUnsafeContinuation { (continuation: AwaiterContinuation) in
            update(continuation)
          }
          #endif
        },
        onCancel: self.cancelAwaiter
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
      update: { @Sendable [weak self] (generation: Generation, awaiter: Awaiter) in
        if let self: UpdatesSequence = self {
          self.update(
            after: generation,
            using: awaiter
          )
        }
        else {
          awaiter.resume(with: .none)
        }
      },
      cancelAwaiter: { @Sendable [weak self] (id: AwaiterID) -> Void in
        self?.cancelAwaiter(withID: id)
      }
    )
  }
}

extension UpdatesSequence {

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

extension UpdatesSequence {

  fileprivate func update(
    after generation: Generation,
    using awaiter: Awaiter
  ) {
    self.state.access { (state: inout State) in
      if state.generation > generation {
        awaiter.resume(with: state.generation)
      }
      else {
        assert(
          !state.awaiters.contains(awaiter),
          "Async iterators cannot be reused."
        )
        state.awaiters.insert(awaiter)
      }
    }
  }

  private func cancelAwaiter(
    withID id: AwaiterID
  ) {
    self.state.access { (state: inout State) in
      if let index: Set<Awaiter>.Index = state.awaiters.firstIndex(where: { $0.id == id }) {
        state.awaiters
          .remove(at: index)
          // cancellation breaks iteration
          .resume(with: .none)
      }
      else {
        /* NOP */
      }
    }
  }
}
