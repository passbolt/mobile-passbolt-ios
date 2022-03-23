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

public final class Cancellables {

  private typealias Cancelation = () -> Void

  private let state: CriticalState<Array<Cancelation>>

  public init() {
    self.state = .init(.init())
  }

  deinit {
    let cancellations: Array<Cancelation> = self.state.access { $0 }
    for cancel in cancellations {
      cancel()
    }
  }

  @discardableResult
  public func take(
    _ other: Cancellables
  ) -> Self {
    let otherCancellations: Array<Cancelation> = other.state.access { cancellations in
      defer { cancellations = .init() }
      return cancellations
    }
    self.state.access { cancellations in
      cancellations.append(contentsOf: otherCancellations)
    }
    return self
  }

  public func store(_ cancellable: AnyCancellable) {
    self.state.access { cancellations in
      cancellations.append(cancellable.cancel)
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
    self.state.access { cancellations in
      cancellations.append(task.cancel)
    }
  }

  public func cancelAll() {
    let cancellations: Array<Cancelation> = self.state.access { cancellations in
      defer { cancellations = .init() }
      return cancellations
    }
    for cancel in cancellations {
      cancel()
    }
  }

  private func privateClean() {
    self.state.access { cancellations in
      cancellations = .init()
    }
  }
}

extension AnyCancellable {

  public func store(in cancellables: Cancellables?) {
    cancellables?.store(self)
  }
}

extension Task {

  public func store(in cancellables: Cancellables?) {
    cancellables?.store(self)
  }
}

extension Cancellables {

  @discardableResult
  public nonisolated func executeOnMainActor(
    _ operation: @MainActor @escaping () async throws -> Void
  ) -> Task<Void, Error> {
    let task = Task { @MainActor in
      try await operation()
    }
    self.store(task)
    return task
  }

  public nonisolated func executeOnMainActorWithPublisher<Success>(
    _ operation: @MainActor @escaping () async throws -> Success
  ) -> AnyPublisher<Success, Error> {
    let task = Task { @MainActor in
      try await operation()
    }
    self.store(task)
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
    self.store(task)
    return
      task
      .asPublisher()
      .switchToLatest()
      .eraseToAnyPublisher()
  }
}

extension Cancellables {

  @discardableResult
  public nonisolated func executeOnAccountSessionActor(
    _ operation: @AccountSessionActor @escaping () async throws -> Void
  ) -> Task<Void, Error> {
    let task = Task { @AccountSessionActor in
      try await operation()
    }
    self.store(task)
    return task
  }

  public nonisolated func executeOnAccountSessionActorWithPublisher<Success>(
    _ operation: @AccountSessionActor @escaping () async throws -> Success
  ) -> AnyPublisher<Success, Error> {
    let task = Task { @AccountSessionActor in
      try await operation()
    }
    self.store(task)
    return
      task
      .asPublisher()
  }

  @_disfavoredOverload
  public nonisolated func executeOnAccountSessionActorWithPublisher<Success>(
    _ operation: @AccountSessionActor @escaping () async throws -> Success
  ) -> AnyPublisher<Success.Output, Error>
  where Success: Publisher {
    let task = Task { @AccountSessionActor in
      try await operation()
        .eraseErrorType()
    }
    self.store(task)
    return
      task
      .asPublisher()
      .switchToLatest()
      .eraseToAnyPublisher()
  }
}

extension Cancellables {

  @discardableResult
  public nonisolated func executeOnStorageAccessActor(
    _ operation: @StorageAccessActor @escaping () async throws -> Void
  ) -> Task<Void, Error> {
    let task = Task { @StorageAccessActor in
      try await operation()
    }
    self.store(task)
    return task
  }

  public nonisolated func executeOnStorageAccessActorWithPublisher<Success>(
    _ operation: @StorageAccessActor @escaping () async throws -> Success
  ) -> AnyPublisher<Success, Error> {
    let task = Task { @StorageAccessActor in
      try await operation()
    }
    self.store(task)
    return
      task
      .asPublisher()
  }

  @_disfavoredOverload
  public nonisolated func executeOnStorageAccessActorWithPublisher<Success>(
    _ operation: @StorageAccessActor @escaping () async throws -> Success
  ) -> AnyPublisher<Success.Output, Error>
  where Success: Publisher {
    let task = Task { @StorageAccessActor in
      try await operation()
        .eraseErrorType()
    }
    self.store(task)
    return
      task
      .asPublisher()
      .switchToLatest()
      .eraseToAnyPublisher()
  }
}

extension Cancellables {

  @discardableResult
  public nonisolated func executeOnFeaturesActor(
    _ operation: @FeaturesActor @escaping () async throws -> Void
  ) -> Task<Void, Error> {
    let task = Task { @FeaturesActor in
      try await operation()
    }
    self.store(task)
    return task
  }

  public nonisolated func executeOnFeaturesActorWithPublisher<Success>(
    _ operation: @FeaturesActor @escaping () async throws -> Success
  ) -> AnyPublisher<Success, Error> {
    let task = Task { @FeaturesActor in
      try await operation()
    }
    self.store(task)
    return
      task
      .asPublisher()
  }

  @_disfavoredOverload
  public nonisolated func executeOnFeaturesActorWithPublisher<Success>(
    _ operation: @FeaturesActor @escaping () async throws -> Success
  ) -> AnyPublisher<Success.Output, Error>
  where Success: Publisher {
    let task = Task { @FeaturesActor in
      try await operation()
        .eraseErrorType()
    }
    self.store(task)
    return
      task
      .asPublisher()
      .switchToLatest()
      .eraseToAnyPublisher()
  }
}
