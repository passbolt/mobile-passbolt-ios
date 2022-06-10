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

  private typealias Awaiter = CheckedContinuation<(value: Value?, generation: UInt64), Never>

  public private(set) var value: Value
  private var generation: UInt64 = 1
  private var awaiters: Array<Awaiter> = .init()

  public init(
    initial: Value
  ) {
    self.value = initial
  }

  deinit {
    for awaiter: Awaiter in self.awaiters {
      awaiter.resume(
        returning: (
          .none,
          .max
        )
      )
    }
  }
}

extension AsyncVariable {

  public func send(
    _ newValue: Value
  ) {
    self.value = newValue
    self.generation &+= 1
    while let awaiter = self.awaiters.popLast() {
      awaiter.resume(
        returning: (
          self.value,
          self.generation
        )
      )
    }
  }

  public func withValue<Returned>(
    _ access: @escaping (inout Value) throws -> Returned
  ) throws -> Returned {
    var modifiedState: Value = self.value
    let returned: Returned = try access(&modifiedState)
    self.value = modifiedState
    self.generation &+= 1
    while let awaiter: Awaiter = self.awaiters.popLast() {
      awaiter.resume(
        returning: (
          self.value,
          self.generation
        )
      )
    }
    return returned
  }
}

extension AsyncVariable: AsyncSequence {

  public typealias AsyncIterator = AnyAsyncIterator<Value>
  public typealias Element = Value

  public nonisolated func makeAsyncIterator() -> AnyAsyncIterator<Value> {
    // initial generation is 1,
    // 0 should always return current value initially
    // only exception is Int64 overflow which will cause
    // single value to be not emmited initially
    // but it should not happen in a typical use anyway
    // ---
    // there is a risk of concurrent access to the generation
    // variable when the same instance of iterator is reused
    // across multiple threads, but it should be avoided anyway
    var generation: UInt64 = 0
    return AnyAsyncIterator<Value> { [weak self] in
      guard
        let next: (value: Value?, generation: UInt64) =
          await self?.next(after: generation)
      else { return nil }
      generation = next.generation
      return next.value
    }
  }
}

extension AsyncVariable {

  private func next(
    after generation: UInt64
  ) async -> (value: Value?, generation: UInt64) {
    await withCheckedContinuation { (continuation: Awaiter) in
      if self.generation > generation {
        continuation.resume(
          returning: (
            self.value,
            self.generation
          )
        )
      }
      else {
        self.awaiters.append(continuation)
      }
    }
  }
}
