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

public struct Cancellables {

  private typealias Cancellation = () -> Void
  private typealias Cleanup = () -> Void

  private struct State {
    var cancellations: Array<Cancellation> = .init()
    var cleanups: Array<Cleanup> = .init()
  }

  private let state: CriticalState<State> = .init(
    .init(),
    cleanup: { state in
      for cancellation: Cancellation in state.cancellations {
        cancellation()
      }
      for cleanup: Cleanup in state.cleanups {
        cleanup()
      }
    }
  )

  public init() {}

  @Sendable public func cleanup() {
    let state: State = self.state
      .access { (state: inout State) in
        defer {
          state.cancellations = .init()
          state.cleanups = .init()
        }
        return state
      }
    state.cancellations.forEach { $0() }
    state.cleanups.forEach { $0() }
  }

  public func addCleanup(
    _ cleanup: @escaping () async throws -> Void
  ) {
    self.state.access { state in
      state.cleanups.append({
        Task.detached(priority: .utility) {
          try await cleanup()
        }
      })
    }
  }

  public func store(
    _ cancellable: AnyCancellable
  ) {
    self.state.access { state in
      state.cancellations.append(cancellable.cancel)
    }
  }

  public func task<Success>(
    _ operation: @Sendable @escaping () async throws -> Success
  ) {
    self.store(Task<Success, Error>(operation: operation))
  }

  public func store<Success, Failure: Error>(
    _ task: Task<Success, Failure>
  ) {
    self.state.access { state in
      state.cancellations.append(task.cancel)
    }
  }
}

extension AnyCancellable {

  public func store(
    in cancellables: Cancellables?
  ) {
    cancellables?.store(self)
  }
}

extension Task {

  public func store(
    in cancellables: Cancellables?
  ) {
    cancellables?.store(self)
  }
}

extension Cancellables {

  @discardableResult
  public nonisolated func executeAsync(
    priority: TaskPriority? = .none,
    _ operation: @Sendable @escaping () async throws -> Void
  ) -> Task<Void, Error> {
    let task: Task<Void, Error> = .init(
      priority: priority,
      operation: operation
    )
    task.store(in: self)
    return task
  }

  @discardableResult
  public nonisolated func executeAsyncDetached(
    priority: TaskPriority? = .none,
    _ operation: @Sendable @escaping () async throws -> Void
  ) -> Task<Void, Error> {
    let task: Task<Void, Error> = .detached(
      priority: priority,
      operation: operation
    )
    task.store(in: self)
    return task
  }

  public nonisolated func executeAsyncWithPublisher<Success>(
    _ operation: @escaping () async throws -> Success
  ) -> AnyPublisher<Success, Error> {
    let task = Task {
      try await operation()
    }
    task.store(in: self)
    return
      task
      .asPublisher()
  }

  @discardableResult
  public nonisolated func executeOnMainActor(
    _ operation: @MainActor @escaping () async throws -> Void
  ) -> Task<Void, Error> {
    let task = Task { @MainActor in
      try await operation()
    }
    task.store(in: self)
    return task
  }

  public nonisolated func executeOnMainActorWithPublisher<Success>(
    _ operation: @MainActor @escaping () async throws -> Success
  ) -> AnyPublisher<Success, Error> {
    let task = Task { @MainActor in
      try await operation()
    }
    task.store(in: self)
    return
      task
      .asPublisher()
  }

  @_disfavoredOverload
  public nonisolated func executeOnMainActorWithPublisher<Success>(
    _ operation: @MainActor @escaping () async throws -> Success
  ) -> AnyPublisher<Success.Output, Error>
  where Success: Publisher {
    let task = Task { @MainActor in
      try await operation()
        .eraseErrorType()
    }
    task.store(in: self)
    return
      task
      .asPublisher()
      .switchToLatest()
      .eraseToAnyPublisher()
  }
}
