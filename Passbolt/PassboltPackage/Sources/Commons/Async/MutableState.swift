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

public final actor MutableState<Value> {

  private enum State {

    case current(Value)
    case deferred(@Sendable () async throws -> Value)
    case pending(Task<Value, Error>)
    case error(Error)
  }

  internal typealias Generation = UInt64
  private typealias Awaiter = @Sendable (Result<Value, Error>) -> Void

  private var state: State
  private var generation: Generation
  private var awaiters: Array<Awaiter>

  public init(
    initial: Value
  ) {
    self.state = .current(initial)
    self.generation = 1
    self.awaiters = .init()
  }

  public init(
    failed error: Error
  ) {
    self.state = .error(error)
    self.generation = 1
    self.awaiters = .init()
  }

  public init(
    lazy resolve: @escaping @Sendable () async throws -> Value
  ) {
    self.state = .deferred(resolve)
    self.generation = 0
    self.awaiters = .init()
  }
}

extension MutableState: Sendable {}

extension MutableState {

  public var value: Value {
    get async throws {
      switch self.state {
      case .current(let value):
        return value

      case .deferred(let resolve):
        let resolveTask: Task<Value, Error> = .detached(operation: resolve)
        self.state = .pending(resolveTask)
        let result: Result<Value, Error> = await resolveTask.result
        switch result {
        case .success(let value):
          self.generation &+= 1
          self.state = .current(value)
          self.resumeAwaiters(with: .success(value))
          return value

        case .failure(let error):
          self.generation &+= 1
          self.state = .error(error)
          self.resumeAwaiters(with: .failure(error))
          throw error
        }

      case .pending(let task):
        return try await task.value

      case .error(let error):
        throw error
      }
    }
  }

  public func update<Returned>(
    _ update: (inout Value) throws -> Returned
  ) async throws -> Returned {
    var value: Value = try await self.value
    do {
      let returned: Returned = try update(&value)
      self.generation &+= 1
      self.state = .current(value)
      self.resumeAwaiters(with: .success(value))
      return returned
    }
    catch {
      self.generation &+= 1
      self.state = .error(error)
      self.resumeAwaiters(with: .failure(error))
      throw error
    }
  }

  public func update<Property>(
    _ keyPath: WritableKeyPath<Value, Property>,
    to newValue: Property
  ) async throws {
    var value: Value = try await self.value
    value[keyPath: keyPath] = newValue
    self.generation &+= 1
    self.state = .current(value)
    self.resumeAwaiters(with: .success(value))
  }

  public func lazyUpdate(
    _ resolve: @escaping @Sendable () async throws -> Value
  ) async throws {
    // wait for current value if needed
    switch self.state {
    case .current where self.awaiters.isEmpty:
      self.state = .deferred(resolve)

    case .current:
      let resolveTask: Task<Value, Error> = .detached(operation: resolve)
      self.state = .pending(resolveTask)
      let result: Result<Value, Error> = await resolveTask.result
      switch result {
      case .success(let value):
        self.generation &+= 1
        self.state = .current(value)
        self.resumeAwaiters(with: .success(value))

      case .failure(let error):
        self.generation &+= 1
        self.state = .error(error)
        self.resumeAwaiters(with: .failure(error))
      }

    case .deferred:
      // skip to new update
      assert(self.awaiters.isEmpty)
      self.state = .deferred(resolve)

    case .pending(let task):
      // wait for finishing current update in progress
      _ = try await task.value
      assert(self.awaiters.isEmpty)
      self.state = .deferred(resolve)

    case .error(let error):
      // if there was already an error it will prevent future updates
      throw error
    }
  }
}

extension MutableState: AsyncSequence {

  public typealias Element = Value
  public struct AsyncIterator: AsyncIteratorProtocol {

    public typealias Element = Value

    // initial value generation is 0,
    // it should always return initial value when resolved
    // only exception is Int64 overflow which will cause
    // single value to be not emmited properly
    // but it should not happen in a typical use anyway
    // ---
    // there is a risk of concurrent access to the generation
    // variable when the same instance of iterator is reused
    // across multiple threads, but it should be avoided anyway
    private var generation: Generation = 0
    private var requestNext: @Sendable (inout Generation) async throws -> Element

    fileprivate init(
      _ state: MutableState<Element>
    ) {
      self.requestNext = state.next(after:)
    }

    public mutating func next() async throws -> Value? {
      try await self.requestNext(&self.generation)
    }
  }

  public nonisolated func makeAsyncIterator() -> AsyncIterator {
    .init(self)
  }

  @Sendable internal func next(
    after generation: inout Generation
  ) async throws -> Element {
    defer { generation = self.generation }
    if self.generation > generation {
      return try await self.value
    }
    else {
      return try await future { (fulfill: @escaping Awaiter) in
        self.awaiters.append(fulfill)
      }
    }
  }

  @Sendable internal func current(
    including generation: inout Generation
  ) async throws -> Element {
    defer { generation = self.generation }
    if self.generation >= generation {
      return try await self.value
    }
    else {
      return try await future { (fulfill: @escaping Awaiter) in
        self.awaiters.append(fulfill)
      }
    }
  }

  @inline(__always) @_transparent
  private func resumeAwaiters(
    with result: Result<Value, Error>
  ) {
    for awaiter in self.awaiters {
      awaiter(result)
    }
    self.awaiters.removeAll(keepingCapacity: true)
  }
}

extension MutableState {

  #if DEBUG
  public static var placeholder: Self {
    .init(lazy: { try await Task.never() })
  }
  #endif
}
