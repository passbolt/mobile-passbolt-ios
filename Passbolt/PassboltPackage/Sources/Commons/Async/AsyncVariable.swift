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

import Combine

@available(*, deprecated, message: "Please switch to `UpdatableValue` and/or `CriticalState` with `UpdatesSequence` if needed.")
public struct AsyncVariable<Value>: Sendable {

  internal typealias Generation = UInt64
  private struct State {

    fileprivate var value: Value
    fileprivate var generation: Generation
    fileprivate var awaiters: Set<Awaiter<(value: Value, generation: Generation)?>>
  }

  public var value: Value {
    self.state.get(\.value)
  }

  private let state: CriticalState<State>

  public init(
    initial: Value
  ) {
    self.state = .init(
      .init(
        value: initial,
        generation: 1,
        awaiters: .init()
      ),
      cleanup: { state in
        for awaiter: Awaiter in state.awaiters {
          awaiter.resume(returning: .none)
        }
      }
    )
  }
}

extension AsyncVariable {

  @Sendable public func send(
    _ newValue: Value
  ) {
    state.access { state in
      state.value = newValue
      state.generation &+= 1
      for awaiter: Awaiter in state.awaiters {
        awaiter.resume(
          returning: (
            state.value,
            state.generation
          )
        )
      }
      state.awaiters.removeAll(keepingCapacity: true)
    }
  }

  @Sendable public func withValue<Returned>(
    _ access: @escaping (inout Value) throws -> Returned
  ) rethrows -> Returned {
    try self.state.access { state in
      var modifiedState: Value = state.value
      let returned: Returned = try access(&modifiedState)
      state.value = modifiedState
      state.generation &+= 1
      for awaiter: Awaiter in state.awaiters {
        awaiter.resume(
          returning: (
            state.value,
            state.generation
          )
        )
      }
      state.awaiters.removeAll(keepingCapacity: true)
      return returned
    }
  }
}

extension AsyncVariable: AsyncSequence {

  public typealias Element = Value
  public struct AsyncIterator: AsyncIteratorProtocol {

    // initial generation is 1,
    // it should always return current value initially
    // only exception is Int64 overflow which will cause
    // single value not to be emmited properly
    // but it should not happen in a typical use anyway
    // ---
    // there is a risk of concurrent access to the generation
    // variable when the same instance of iterator is reused
    // across multiple threads, but it should be avoided anyway
    private var generation: Generation = 0
    private let update: @Sendable (Generation, Awaiter<(value: Value, generation: Generation)?>) -> Void
    private let cancel: @Sendable (IID) -> Void
    #if DEBUG
    private var pendingNext: Bool = false
    #endif

    fileprivate init(
      update: @escaping @Sendable (Generation, Awaiter<(value: Value, generation: Generation)?>) -> Void,
      cancel: @escaping @Sendable (IID) -> Void
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
      let update: @Sendable (Generation, Awaiter<(value: Value, generation: Generation)?>) -> Void = self.update
      let cancel: @Sendable (IID) -> Void = self.cancel
      let next: (value: Value, generation: Generation)? = try? await Awaiter<(value: Value, generation: Generation)?>
        .withCancelation(
          { id in
            cancel(id)
          },
          execute: { awaiter in
            update(lastGeneration, awaiter)
          }
        )

      if let next: (value: Value, generation: Generation) = next {
        self.generation = next.generation
        return next.value
      }
      else {
        return .none
      }
    }
  }

  public nonisolated func makeAsyncIterator() -> AsyncIterator {
    AsyncIterator(
      update: {
        @Sendable (generation: Generation, awaiter: Awaiter<(value: Value, generation: Generation)?>) in
        self.update(
          after: generation,
          using: awaiter
        )
      },
      cancel: { @Sendable (id: IID) -> Void in
        self.cancelAwaiter(withID: id)
      }
    )
  }
}

extension AsyncVariable {

  @Sendable fileprivate func update(
    after generation: Generation,
    using awaiter: Awaiter<(value: Value, generation: Generation)?>
  ) {
    guard !Task.isCancelled
    else {
      // cancellation breaks iteration
      return awaiter.resume(throwing: CancellationError())
    }
    self.state.access { (state: inout State) in
      if state.generation > generation {
        awaiter.resume(returning: (state.value, state.generation))
      }
      else {
        assert(
          !state.awaiters.contains(awaiter),
          "Awaiters cannot be reused."
        )
        state.awaiters.update(with: awaiter)?
          .resume(throwing: CancellationError())
      }
    }
  }

  @Sendable private func cancelAwaiter(
    withID id: IID
  ) {
    let canceledAwaiter: Awaiter<(value: Value, generation: Generation)?>? = self.state.access { (state: inout State) in
      state.awaiters
        .removeAwaiter(withID: id)
    }

    canceledAwaiter?
      .resume(throwing: CancellationError())
  }
}
