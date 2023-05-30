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

public final class MutableState<Value>
where Value: Sendable {

  public typealias ResolveValue = @Sendable () async throws -> Value
  public typealias ResolveMutation = @Sendable (inout Value) throws -> Void
  public typealias ResolveAsyncMutation = @Sendable (inout Value) async throws -> Void

  internal typealias Generation = UInt64

  fileprivate typealias ValueGeneration = (value: Value, generation: Generation)
  fileprivate typealias UpdateTask = Task<Value, Error>
  fileprivate typealias UpdateAwaiter = @Sendable (Result<ValueGeneration, Error>) -> Void

  fileprivate enum ValueState {
    // Value is up to date and nothing is pending.
    case current(Value)
    // Value has to be updated but it is resolved only when needed.
    case deferred(ResolveValue)
    // Value is being updated, further updates will be queued??.
    case pending(UpdateTask)
    // State is broken, no more updates possible.
    case failure(Error)
  }

  fileprivate struct State {

    fileprivate var value: ValueState {
      didSet {
        switch self.value {
        case .pending:
          let pendingAwaiters: Array<UpdateAwaiter> =
            self.updateAwaiters.removeValue(forKey: self.generation) ?? .init()
          self.generation &+= 1
          var updatedAwaiters: Array<UpdateAwaiter> = self.updateAwaiters[self.generation] ?? .init()
          updatedAwaiters.append(contentsOf: pendingAwaiters)
          self.updateAwaiters[self.generation] = updatedAwaiters

        case .current:
          self.generation &+= 1

        case .deferred, .failure:
          assert(self.updateAwaiters.isEmpty)
        }
      }
    }
    fileprivate private(set) var generation: Generation
    fileprivate private(set) var updateAwaiters: Dictionary<Generation, Array<UpdateAwaiter>> = .init()

    fileprivate init(
      value: ValueState,
      generation: Generation
    ) {
      self.value = value
      self.generation = generation
    }
  }

  private let state: CriticalState<State>

  public init(
    initial: Value
  ) {
    self.state = .init(
      .init(
        value: .current(initial),
        generation: 1
      )
    )
  }

  public init(
    failed error: Error
  ) {
    self.state = .init(
      .init(
        value: .failure(error),
        generation: 1
      )
    )
  }

  public init(
    lazy resolve: @escaping ResolveValue
  ) {
    // initial value is not there yet
    self.state = .init(
      .init(
        value: .deferred(resolve),
        generation: 0
      )
    )
  }

  deinit {
    self.state.access { (state: inout State) in
      // cancel all awaiters left
      for awaiter in state.updateAwaiters.values.flatMap({ $0 }) {
        awaiter(.failure(CancellationError()))
      }
    }
  }
}

extension MutableState: Sendable {}

extension MutableState {

  public var value: Value {
    get async throws {
      let valueGeneration: ValueGeneration = try await future { fulfill in
        self.state.access { (state: inout State) in
          switch state.value {
          case .current(let value):
            fulfill(.success((value: value, generation: state.generation)))

          case .pending:
            state.addAwaiter(fulfill)

          case .deferred(let resolve):
            let generation: Generation = state.generation + 1
            let updateTask: Task<Value, Error> = .detached { [weak self] in
              do {
                let resolvedValue: Value = try await resolve()
                try self?.update(to: resolvedValue, from: generation)
                return resolvedValue
              }
              catch {
                try self?.fail(with: error)
                throw error
              }
            }
            state.value = .pending(updateTask)
            state.addAwaiter(fulfill)

          case .failure(let error):
            fulfill(.failure(error))
          }
        }
      }

      return valueGeneration.value
    }
  }
}

extension MutableState {

  public func fail(
    with error: Error
  ) throws {
    try self.state.access { (state: inout State) throws in
      try state.fail(with: error)
    }
  }

  @discardableResult
  public func update(
    _ mutation: @escaping ResolveMutation
  ) async throws -> Value {
    try await future { fulfill in
      self.state.access { (state: inout State) in
        switch state.value {
        case .current(var value):
          state.addAwaiter(fulfill)
          do {
            try mutation(&value)
            try state.update(to: value, from: state.generation)
          }
          catch {
            // ignore error here, it can't throw when failing from a valid value
            try? state.fail(with: error)
          }

        case .deferred(let resolve):
          let generation: Generation = state.generation + 1
          let updateTask: Task<Value, Error> = .detached { [weak self] in
            do {
              var resolvedValue: Value = try await resolve()
              try mutation(&resolvedValue)
              try self?.update(to: resolvedValue, from: generation)
              return resolvedValue
            }
            catch {
              try self?.fail(with: error)
              throw error
            }
          }
          state.value = .pending(updateTask)
          state.addAwaiter(fulfill)

        case .pending(let task):
          let generation: Generation = state.generation + 1
          let updateTask: Task<Value, Error> = .detached { [weak self] in
            do {
              var resolvedValue: Value = try await task.value
              try mutation(&resolvedValue)
              try self?.update(to: resolvedValue, from: generation)
              return resolvedValue
            }
            catch {
              try self?.fail(with: error)
              throw error
            }
          }
          state.value = .pending(updateTask)
          state.addAwaiter(fulfill)

        case .failure(let error):
          fulfill(.failure(error))
        }
      }
    }
    .value
  }

  public func update<Property>(
    _ keyPath: WritableKeyPath<Value, Property>,
    to newValue: Property
  ) async throws {
    try await self.update { (value: inout Value) in
      value[keyPath: keyPath] = newValue
    }
  }

  public func deferredUpdate(
    _ mutation: @escaping ResolveAsyncMutation
  ) throws {
    try self.state.access { (state: inout State) throws in
      switch state.value {
      case .current(let value):
        if state.updateAwaiters.isEmpty {
          state.value = .deferred {
            var value: Value = value
            try await mutation(&value)
            return value
          }
        }
        else {
          let generation: Generation = state.generation + 1
          let updateTask: Task<Value, Error> = .detached { [weak self] in
            do {
              var resolvedValue: Value = value
              try await mutation(&resolvedValue)
              try self?.update(to: resolvedValue, from: generation)
              return resolvedValue
            }
            catch {
              try self?.fail(with: error)
              throw error
            }
          }
          state.value = .pending(updateTask)
        }

      case .deferred(let resolve):
        state.value = .deferred {
          var value: Value = try await resolve()
          try await mutation(&value)
          return value
        }

      case .pending(let task):
        let generation: Generation = state.generation + 1
        let updateTask: Task<Value, Error> = .detached { [weak self] in
          do {
            var resolvedValue: Value = try await task.value
            try await mutation(&resolvedValue)
            try self?.update(to: resolvedValue, from: generation)
            return resolvedValue
          }
          catch {
            try self?.fail(with: error)
            throw error
          }
        }
        state.value = .pending(updateTask)

      case .failure(let error):
        throw error
      }
    }
  }

  public func deferredAssign(
    _ resolve: @escaping ResolveValue
  ) throws {
    try self.state.access { (state: inout State) throws in
      switch state.value {
      case .current:
        if state.updateAwaiters.isEmpty {
          state.value = .deferred(resolve)
        }
        else {
          let generation: Generation = state.generation + 1
          let updateTask: Task<Value, Error> = .detached { [weak self] in
            do {
              let resolvedValue: Value = try await resolve()
              try self?.update(to: resolvedValue, from: generation)
              return resolvedValue
            }
            catch {
              try self?.fail(with: error)
              throw error
            }
          }
          state.value = .pending(updateTask)
        }

      case .deferred:
        state.value = .deferred(resolve)

      case .pending(let task):
        task.cancel()
        let generation: Generation = state.generation + 1
        let updateTask: Task<Value, Error> = .detached { [weak self] in
          do {
            let resolvedValue: Value = try await resolve()
            try self?.update(to: resolvedValue, from: generation)
            return resolvedValue
          }
          catch {
            try self?.fail(with: error)
            throw error
          }
        }
        state.value = .pending(updateTask)

      case .failure(let error):
        throw error
      }
    }
  }

  @discardableResult
  public func asyncUpdate(
    _ mutation: @escaping ResolveAsyncMutation
  ) async throws -> Value {
    try await future { (fulfill: @escaping @Sendable (Result<ValueGeneration, Error>) -> Void) in
      self.state.access { (state: inout State) in
        switch state.value {
        case .current(let value):
          let generation: Generation = state.generation + 1
          let updateTask: Task<Value, Error> = .detached { [weak self] in
            do {
              var resolvedValue: Value = value
              try await mutation(&resolvedValue)
              try self?.update(to: resolvedValue, from: generation)
              return resolvedValue
            }
            catch {
              try self?.fail(with: error)
              throw error
            }
          }
          state.value = .pending(updateTask)
          state.addAwaiter(fulfill)

        case .deferred(let resolve):
          let generation: Generation = state.generation + 1
          let updateTask: Task<Value, Error> = .detached { [weak self] in
            do {
              var resolvedValue: Value = try await resolve()
              try await mutation(&resolvedValue)
              try self?.update(to: resolvedValue, from: generation)
              return resolvedValue
            }
            catch {
              try self?.fail(with: error)
              throw error
            }
          }
          state.value = .pending(updateTask)
          state.addAwaiter(fulfill)

        case .pending(let task):
          let generation: Generation = state.generation + 1
          let updateTask: Task<Value, Error> = .detached { [weak self] in
            do {
              var resolvedValue: Value = try await task.value
              try await mutation(&resolvedValue)
              try self?.update(to: resolvedValue, from: generation)
              return resolvedValue
            }
            catch {
              try self?.fail(with: error)
              throw error
            }
          }
          state.value = .pending(updateTask)
          state.addAwaiter(fulfill)

        case .failure(let error):
          fulfill(.failure(error))
        }
      }
    }
    .value
  }
}

extension MutableState: AsyncSequence {

  public typealias Element = Value

  public struct AsyncIterator: AsyncIteratorProtocol {

    private var requestNext: () async throws -> Value?

    fileprivate init(
      _ state: MutableState<Value>
    ) {
      var generation: Generation = 0
      self.requestNext = { [weak state] () async throws -> Value? in
        return try await state?.next(after: &generation)
      }
    }

    @Sendable public mutating func next() async throws -> Value? {
      try await self.requestNext()
    }
  }

  public nonisolated func makeAsyncIterator() -> AsyncIterator {
    .init(self)
  }

  internal func next(
    after generation: inout Generation
  ) async throws -> Value {
    let nextValueGeneration: ValueGeneration = try await future { fulfill in
      self.state.access { (state: inout State) in
        switch state.value {
        case .current(let value):
          if state.generation > generation {
            fulfill(.success((value: value, generation: state.generation)))
          }
          else {
            state.addAwaiter(fulfill)
          }

        case .pending:
          state.addAwaiter(fulfill)

        case .deferred(let resolve):
          let generation: Generation = state.generation + 1
          let updateTask: Task<Value, Error> = .detached { [weak self] in
            do {
              let resolvedValue: Value = try await resolve()
              try self?.update(to: resolvedValue, from: generation)
              return resolvedValue
            }
            catch {
              try self?.fail(with: error)
              throw error
            }
          }
          state.value = .pending(updateTask)
          state.addAwaiter(fulfill)

        case .failure(let error):
          fulfill(.failure(error))
        }
      }
    }
    generation = nextValueGeneration.generation
    return nextValueGeneration.value
  }
}

extension MutableState {

  @discardableResult
  fileprivate func update(
    to newValue: Value,
    from generation: MutableState.Generation
  ) throws -> MutableState.Generation {
    try self.state.access { (state: inout State) throws in
      try state.update(to: newValue, from: generation)
    }
  }
}

extension MutableState.State {

  @discardableResult
  fileprivate mutating func update(
    to newValue: Value,
    from generation: MutableState.Generation
  ) throws -> MutableState.Generation {
    // it it already failed throw an error, awaiters should be already resumed
    if case .failure(let error) = self.value {
      throw error
    }
    // if there is new update triggered don't mess up with internal state
    else if self.generation != generation {
      // find awaiters for that generation
      let awaiters: Array<MutableState.UpdateAwaiter> = self.updateAwaiters.removeValue(forKey: generation) ?? .init()
      for awaiter in awaiters {
        awaiter(.success((value: newValue, generation: generation)))
      }
      return generation
    }
    else {
      assert(self.updateAwaiters.count == 1)
      // find awaiters for that generation
      let awaiters: Array<MutableState.UpdateAwaiter> = self.updateAwaiters.removeValue(forKey: generation) ?? .init()
      self.value = .current(newValue)
      for awaiter in awaiters {
        awaiter(.success((value: newValue, generation: self.generation)))
      }
      return self.generation
    }
  }

  fileprivate mutating func fail(
    with error: Error
  ) throws {
    switch self.value {
    // if it already failed just ignore it and throw previous error
    case .failure(let error):
      throw error

    case .pending(let task):
      // cancel pending task, it won't deliver value anyway
      task.cancel()
      fallthrough

    case .current, .deferred:
      // pick all awaiters since it is terminal state
      let awaiters: Array<MutableState.UpdateAwaiter> = self.updateAwaiters.values.flatMap { $0 }
      self.updateAwaiters = .init()
      self.value = .failure(error)
      for awaiter in awaiters {
        awaiter(.failure(error))
      }
    }
  }

  fileprivate mutating func addAwaiter(
    _ awaiter: @escaping MutableState.UpdateAwaiter,
    forGeneration generation: MutableState.Generation? = .none
  ) {
    // can't add awaiter if already failed
    if case .failure(let error) = self.value {
      awaiter(.failure(error))  // finish it immediately with error
    }
    else {
      let generation: MutableState.Generation = generation ?? self.generation
      var awaiters: Array<MutableState.UpdateAwaiter> = self.updateAwaiters[generation] ?? .init()
      awaiters.append(awaiter)
      self.updateAwaiters[generation] = awaiters
    }
  }
}

extension MutableState {

  #if DEBUG
  public static var placeholder: Self {
    .init(lazy: unimplemented0())
  }
  #endif
}
