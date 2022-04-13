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

public final class AsyncVariable<Value> {

  private typealias Awaiter = CheckedContinuation<(value: Value?, generation: UInt64), Never>

  private struct State {

    fileprivate var value: Value
    fileprivate var generation: UInt64 = 1
    fileprivate var awaiters: Array<Awaiter> = .init()
  }

  public var value: Value {
    get {
      self.state.access(\.value)
    }
    set {
      self.state.access { state in
        state.value = newValue
        state.generation &+= 1
        while let awaiter = state.awaiters.popLast() {
          awaiter.resume(returning: (state.value, state.generation))
        }
      }
    }
  }

  private let state: CriticalState<State>

  public init(initial: Value) {
    self.state = .init(.init(value: initial))
  }

  deinit {
    let awaiters: Array<Awaiter> = self.state.access(\.awaiters)
    for awaiter in awaiters {
      awaiter.resume(returning: (.none, .max))
    }
  }

  private func next(
    after generation: UInt64
  ) async -> (value: Value?, generation: UInt64) {
    return await withCheckedContinuation { (continuation: Awaiter) in
      self.state.access { state in
        if state.generation > generation {
          continuation.resume(returning: (state.value, state.generation))
        }
        else {
          state.awaiters.append(continuation)
        }
      }
    }
  }

  public func withValue<Returned>(
    _ access: (inout Value) throws -> Returned
  ) rethrows -> Returned {
    try self.state.access { state in
      try access(&state.value)
    }
  }

  public func withValueAsync<Returned>(
    _ access: @escaping (inout Value) async throws -> Returned
  ) async throws -> Returned {
    try await self.state.accessAsync { state in
      try await access(&state.value)
    }
  }
}

extension AsyncVariable: AsyncSequence {

  public typealias AsyncIterator = AnyAsyncIterator<Value>
  public typealias Element = Value

  public func makeAsyncIterator() -> AnyAsyncIterator<Value> {
    var generation: UInt64 = self.state.access { $0.generation } &- 1
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
