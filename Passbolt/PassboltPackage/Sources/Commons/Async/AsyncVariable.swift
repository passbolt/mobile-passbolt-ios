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

public final actor AsyncVariable<Value> {

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
      with value: (Value, Generation)?
    ) {
      self.continuation.resume(returning: value)
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
  fileprivate typealias AwaiterContinuation = CheckedContinuation<(value: Value, generation: Generation)?, Never>
  #else
  fileprivate typealias AwaiterContinuation = UnsafeContinuation<(value: Value, generation: Generation)?, Never>
  #endif
  fileprivate typealias AwaiterID = ObjectIdentifier

  public private(set) var value: Value
  private var generation: Generation = 1
  private var awaiters: Set<Awaiter> = .init()

  public init(
    initial: Value
  ) {
    self.value = initial
  }

  deinit {
    for awaiter: Awaiter in self.awaiters {
      awaiter.resume(with: .none)
    }
  }
}

extension AsyncVariable {

  public func send(
    _ newValue: Value
  ) {
    self.value = newValue
    self.generation &+= 1
    for awaiter in self.awaiters {
      awaiter.resume(
        with: (
          self.value,
          self.generation
        )
      )
    }
    self.awaiters.removeAll(keepingCapacity: true)
  }

  public func withValue<Returned>(
    _ access: @escaping (inout Value) throws -> Returned
  ) rethrows -> Returned {
    var modifiedState: Value = self.value
    let returned: Returned = try access(&modifiedState)
    self.send(modifiedState)
    return returned
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
    private let update: @Sendable (Generation, AwaiterContinuation) async -> Void
    private let cancelAwaiter: @Sendable () -> Void
    final class ID {}
    fileprivate init(
      update: @escaping @Sendable (Generation, Awaiter) async -> Void,
      cancelAwaiter: @escaping @Sendable (AwaiterID) async -> Void
    ) {

      let id: AwaiterID = AwaiterID(ID())
      self.update = { (generation: Generation, continuation: AwaiterContinuation) async -> Void in
        await update(
          generation,
          .init(
            id: id,
            continuation: continuation
          )
        )
      }
      self.cancelAwaiter = { @Sendable () -> Void in
        Task { await cancelAwaiter(id) }
      }
    }

    public mutating func next() async -> Element? {
      let lastGeneration: Generation = self.generation
      let rawUpdate: (Generation, AwaiterContinuation) async -> Void = self.update
      let update: @Sendable (AwaiterContinuation) async -> Void = { (continuation: AwaiterContinuation) async -> Void in
        await rawUpdate(lastGeneration, continuation)
      }
      let next: (value: Value, generation: Generation)? = await withTaskCancellationHandler(
        operation: {
          #if DEBUG
          await withCheckedContinuation { (continuation: AwaiterContinuation) in
            Task {
              await update(continuation)
            }
          }
          #else
          await withUnsafeContinuation { (continuation: AwaiterContinuation) in
            Task {
              await update(continuation)
            }
          }
          #endif
        },
        onCancel: self.cancelAwaiter
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
      update: { @Sendable [weak self] (generation: Generation, awaiter: Awaiter) in
        if let self: AsyncVariable = self {
          await self.update(
            after: generation,
            using: awaiter
          )
        }
        else {
          awaiter.resume(with: .none)
        }
      },
      cancelAwaiter: { @Sendable [weak self] (id: AwaiterID) async -> Void in
        await self?.cancelAwaiter(withID: id)
      }
    )
  }
}

extension AsyncVariable {

  fileprivate func update(
    after generation: Generation,
    using awaiter: Awaiter
  ) {
    guard !Task.isCancelled
    else {
      // cancellation breaks iteration
      return awaiter.resume(with: .none)
    }
    if self.generation > generation {
      awaiter.resume(with: (self.value, self.generation))
    }
    else {
      self.insertAwaiter(awaiter)
    }
  }

  private func insertAwaiter(
    _ awaiter: Awaiter
  ) {
    precondition(
      !self.awaiters.contains(awaiter),
      "Async iterators cannot be reused."
    )
    guard !Task.isCancelled
    else {
      // cancellation breaks iteration
      return awaiter.resume(with: .none)
    }
    self.awaiters.insert(awaiter)
  }

  private func cancelAwaiter(
    withID id: AwaiterID
  ) {
    if let index: Set<Awaiter>.Index = self.awaiters.firstIndex(where: { $0.id == id }) {
      self.awaiters
        .remove(at: index)
        // cancellation breaks iteration
        .resume(with: .none)
    }
    else {
      /* NOP */
    }
  }
}
