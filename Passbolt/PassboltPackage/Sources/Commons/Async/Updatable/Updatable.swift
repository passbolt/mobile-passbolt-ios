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

  @Sendable func notify(
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
      // uninitialized will always deliver latest known
      try await self.notify(after: .uninitialized)
    }
  }

  @_transparent @Sendable public func notify(
    after generation: UpdateGeneration
  ) async throws -> Update<Value> {
    try await future { (awaiter: @escaping @Sendable (Update<Value>) -> Void) in
      self.notify(awaiter, after: generation)
    }
  }
}

extension Updatable {

  // despite the warning Swift 5.8 can't use type constraints properly
  // and it does not compile without typealiases
  public typealias Element = Update<Value>
  public typealias AsyncIterator = UpdatableIterator<Value>

  @Sendable public func makeAsyncIterator() -> UpdatableIterator<Value> {
    UpdatableIterator(source: self)
  }
}

extension Updatable {

  public var publisher: UpdatablePublisher<Self> {
    UpdatablePublisher(source: self)
  }
}

public struct UpdatableIterator<Value>: AsyncIteratorProtocol
where Value: Sendable {

  public typealias Element = Update<Value>

  private var generation: UpdateGeneration
  private let notifyAfter: @Sendable (@escaping @Sendable (Update<Value>) -> Void, UpdateGeneration) -> Void

  internal init<Source>(
    source: Source
  ) where Source: Updatable, Source.Value == Value {
    self.generation = .uninitialized
    self.notifyAfter = source.notify(_:after:)
  }

  public mutating func next() async -> Element? {
    do {
      let element: Element = try await future { (fulfill: @escaping @Sendable (Update<Value>) -> Void) in
        self.notifyAfter(fulfill, self.generation)
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

@usableFromInline internal final class UpdateDelivery<Value> where Value: Sendable {

  private let awaiter: @Sendable (Update<Value>) -> Void
  private var next: UpdateDelivery?

  @usableFromInline internal init(
    awaiter: @escaping @Sendable (Update<Value>) -> Void,
    next: UpdateDelivery?
  ) {
    self.awaiter = awaiter
    self.next = next
  }

  @usableFromInline @Sendable internal func deliver(
    _ update: Update<Value>
  ) {
    self.awaiter(update)
    self.next?.deliver(update)
  }
}
