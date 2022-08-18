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

// source from https://github.com/apple/swift-async-algorithms/blob/main/Sources/AsyncAlgorithms/AsyncRemoveDuplicatesSequence.swift
// to be removed after adding swift-async-algorithms
// as a dependency (requires swift 5.7)

extension AsyncSequence where Element: Equatable {
  /// Creates an asynchronous sequence that omits repeated elements.
  public func removeDuplicates() -> AsyncRemoveDuplicatesSequence<Self> {
    AsyncRemoveDuplicatesSequence(self) { lhs, rhs in
      lhs == rhs
    }
  }
}

extension AsyncSequence {
  /// Creates an asynchronous sequence that omits repeated elements by testing them with a predicate.
  public func removeDuplicates(by predicate: @escaping @Sendable (Element, Element) async -> Bool)
    -> AsyncRemoveDuplicatesSequence<Self>
  {
    return AsyncRemoveDuplicatesSequence(self, predicate: predicate)
  }

  /// Creates an asynchronous sequence that omits repeated elements by testing them with an error-throwing predicate.
  public func removeDuplicates(by predicate: @escaping @Sendable (Element, Element) async throws -> Bool)
    -> AsyncThrowingRemoveDuplicatesSequence<Self>
  {
    return AsyncThrowingRemoveDuplicatesSequence(self, predicate: predicate)
  }
}

/// An asynchronous sequence that omits repeated elements by testing them with a predicate.
public struct AsyncRemoveDuplicatesSequence<Base: AsyncSequence>: AsyncSequence {
  public typealias Element = Base.Element

  /// The iterator for an `AsyncRemoveDuplicatesSequence` instance.
  public struct Iterator: AsyncIteratorProtocol {

    @usableFromInline
    var iterator: Base.AsyncIterator

    @usableFromInline
    let predicate: @Sendable (Element, Element) async -> Bool

    @usableFromInline
    var last: Element?

    @inlinable
    init(iterator: Base.AsyncIterator, predicate: @escaping @Sendable (Element, Element) async -> Bool) {
      self.iterator = iterator
      self.predicate = predicate
    }

    @inlinable
    public mutating func next() async rethrows -> Element? {
      guard let last = last else {
        last = try await iterator.next()
        return last
      }
      while let element = try await iterator.next() {
        if await !predicate(last, element) {
          self.last = element
          return element
        }
      }
      return nil
    }
  }

  @usableFromInline
  let base: Base

  @usableFromInline
  let predicate: @Sendable (Element, Element) async -> Bool

  init(_ base: Base, predicate: @escaping @Sendable (Element, Element) async -> Bool) {
    self.base = base
    self.predicate = predicate
  }

  @inlinable
  public func makeAsyncIterator() -> Iterator {
    Iterator(iterator: base.makeAsyncIterator(), predicate: predicate)
  }
}

extension AsyncRemoveDuplicatesSequence: Sendable
where Base: Sendable, Base.Element: Sendable, Base.AsyncIterator: Sendable {}
extension AsyncRemoveDuplicatesSequence.Iterator: Sendable
where Base: Sendable, Base.Element: Sendable, Base.AsyncIterator: Sendable {}

/// An asynchronous sequence that omits repeated elements by testing them with an error-throwing predicate.
public struct AsyncThrowingRemoveDuplicatesSequence<Base: AsyncSequence>: AsyncSequence {
  public typealias Element = Base.Element

  /// The iterator for an `AsyncThrowingRemoveDuplicatesSequence` instance.
  public struct Iterator: AsyncIteratorProtocol {

    @usableFromInline
    var iterator: Base.AsyncIterator

    @usableFromInline
    let predicate: @Sendable (Element, Element) async throws -> Bool

    @usableFromInline
    var last: Element?

    @inlinable
    init(iterator: Base.AsyncIterator, predicate: @escaping @Sendable (Element, Element) async throws -> Bool) {
      self.iterator = iterator
      self.predicate = predicate
    }

    @inlinable
    public mutating func next() async throws -> Element? {
      guard let last = last else {
        last = try await iterator.next()
        return last
      }
      while let element = try await iterator.next() {
        if try await !predicate(last, element) {
          self.last = element
          return element
        }
      }
      return nil
    }
  }

  @usableFromInline
  let base: Base

  @usableFromInline
  let predicate: @Sendable (Element, Element) async throws -> Bool

  init(_ base: Base, predicate: @escaping @Sendable (Element, Element) async throws -> Bool) {
    self.base = base
    self.predicate = predicate
  }

  @inlinable
  public func makeAsyncIterator() -> Iterator {
    Iterator(iterator: base.makeAsyncIterator(), predicate: predicate)
  }
}

extension AsyncThrowingRemoveDuplicatesSequence: Sendable
where Base: Sendable, Base.Element: Sendable, Base.AsyncIterator: Sendable {}
extension AsyncThrowingRemoveDuplicatesSequence.Iterator: Sendable
where Base: Sendable, Base.Element: Sendable, Base.AsyncIterator: Sendable {}
