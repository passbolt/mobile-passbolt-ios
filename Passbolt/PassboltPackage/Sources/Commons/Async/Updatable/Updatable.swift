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

public protocol Updatable<Value>: AnyObject, Sendable, AsyncSequence {

  associatedtype Value: Sendable

  nonisolated var generation: UpdateGeneration { @Sendable get }
  var value: Value { @Sendable get async throws }
  var lastUpdate: Update<Value> { @Sendable get async throws }

  @Sendable func update(
    _ awaiter: @escaping @Sendable (Update<Value>) -> Void,
    after generation: UpdateGeneration
  )
}

extension Updatable {

  public var value: Value {
    @_transparent @Sendable get async throws {
      try await self.lastUpdate.value
    }
  }

  public var lastUpdate: Update<Value> {
    @_transparent @Sendable get async throws {
      try await future { (fulfill: @escaping @Sendable (Update<Value>) -> Void) in
        // uninitialized will always deliver latest known
        self.update(fulfill, after: .uninitialized)
      }
    }
  }

	@_transparent @Sendable public func update(
		after generation: UpdateGeneration
	) async throws -> Update<Value> {
		try await future { (fulfill: @escaping @Sendable (Update<Value>) -> Void) in
			self.update(fulfill, after: generation)
		}
	}
}

extension Updatable {

  // despite the warning Swift 5.8 can't use type constraints properly
  // and it does not compile without typealiases
  public typealias Element = Update<Value>
  public typealias AsyncIterator = UpdatableIterator<Value>

  public func makeAsyncIterator() -> UpdatableIterator<Value> {
    UpdatableIterator(source: self)
  }
}

extension Updatable {

  public var publisher: UpdatablePublisher<Value> {
    .init(source: self)
  }
}

public final class PlaceholderUpdatable<Value>: Updatable
where Value: Sendable {

  public init() {}

  public let generation: UpdateGeneration = .uninitialized

  @Sendable public func update(
    _ awaiter: @escaping @Sendable (Update<Value>) -> Void,
    after generation: UpdateGeneration
  ) {
    // never
  }
}

public struct UpdatableIterator<Value>: AsyncIteratorProtocol
where Value: Sendable {

  public typealias Element = Update<Value>

  private var generation: UpdateGeneration
  private let source: any Updatable<Value>

  internal init(
    source: any Updatable<Value>
  ) {
    self.generation = .uninitialized
    self.source = source
  }

  public mutating func next() async -> Element? {
    do {
      let element: Element = try await future { (fulfill: @escaping @Sendable (Element) -> Void) in
        self.source.update(fulfill, after: self.generation)
      }
      self.generation = element.generation
      return element
    }
    catch is CancellationError {
      return .none
    }
    catch {
      unreachable("Future cant't fail here!")
    }
  }
}

public final class UpdatablePublisher<Value>: ConnectablePublisher
where Value: Sendable {

  public typealias Output = Update<Value>
  public typealias Failure = Never

  private let subject: PassthroughSubject<Output, Failure> = .init()
  private let iteratorNext: () async -> Output?

  @usableFromInline internal init(
    source: any Updatable<Value>
  ) {
    var iterator: UpdatableIterator<Value> = source.makeAsyncIterator()
    self.iteratorNext = { await iterator.next() }
  }

  public func receive<S>(
    subscriber: S
  ) where S: Subscriber, S.Input == Output, S.Failure == Failure {
    self.subject
      .receive(subscriber: subscriber)
  }

  public func connect() -> Cancellable {
    let task: Task<Void, Never> = .init {
      while case .some(let update) = await self.iteratorNext() {
        self.subject.send(update)
      }
      self.subject.send(completion: .finished)
    }

    return AnyCancellable(task.cancel)
  }
}
