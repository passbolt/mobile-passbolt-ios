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

public struct AnyAsyncSequence<Element>: Sendable
where Element: Sendable {

  private let makeIterator: @Sendable () -> AnyAsyncIterator<Element>

  public init<Upstream: Publisher>(
    _ upstream: Upstream,
    bufferingPolicy: AsyncStream<Element>.Continuation.BufferingPolicy = .unbounded
  ) where Upstream.Output == Element {
    let iteratorFactory: () -> AnyAsyncIterator<Element> = {
      upstream.values.makeAsyncIterator().asAnyAsyncIterator()
    }
    let box: UncheckedSendableBox<() -> AnyAsyncIterator<Element>> = UncheckedSendableBox(iteratorFactory)
    self.makeIterator = {
      box.value()
    }
  }

  public init<Content>(
    _ content: Content
  ) where Content: AsyncSequence, Content.Element == Element {
    let iteratorFactory: () -> AnyAsyncIterator<Element> = {
      content.makeAsyncIterator().asAnyAsyncIterator()
    }
    let box: UncheckedSendableBox<() -> AnyAsyncIterator<Element>> = UncheckedSendableBox(iteratorFactory)
    self.makeIterator = {
      box.value()
    }
  }

  public init<Content>(
    _ content: Content
  ) where Content: Sequence, Content.Element == Element {
    let iteratorFactory: () -> AnyAsyncIterator<Element> = {
      var iterator: Content.Iterator = content.makeIterator()
      return AnyAsyncIterator<Element>(
        nextElement: {
          iterator.next()
        }
      )
    }
    let box: UncheckedSendableBox<() -> AnyAsyncIterator<Element>> = UncheckedSendableBox(iteratorFactory)
    self.makeIterator = {
      box.value()
    }
  }

  public init(
    _ next: @escaping @Sendable () async throws -> Element?
  ) {
    self.makeIterator = {
      AnyAsyncIterator<Element>(
        nextElement: next
      )
    }
  }
}

extension AnyAsyncSequence: AsyncSequence {

  public func makeAsyncIterator() -> AnyAsyncIterator<Element> {
    self.makeIterator()
  }
}

extension Sequence
where Element: Sendable {

  public func asAnyAsyncSequence() -> AnyAsyncSequence<Element> {
    AnyAsyncSequence(self)
  }
}

extension AsyncSequence
where Element: Sendable {

  public func asAnyAsyncSequence() -> AnyAsyncSequence<Element> {
    if let sequence: AnyAsyncSequence<Element> = self as? AnyAsyncSequence<Element> {
      return sequence
    }
    else {
      return AnyAsyncSequence(self)
    }
  }

  public func asAnyValueAsyncSequence<Value>() -> AnyAsyncSequence<Value>
  where Self.Element == Update<Value> {
    if let sequence: AnyAsyncSequence<Value> = self as? AnyAsyncSequence<Value> {
      return sequence
    }
    else {
      return AnyAsyncSequence(self.map { try $0.value })
    }
  }
}

extension Publisher
where Output: Sendable {

  public func asAnyAsyncSequence() -> AnyAsyncSequence<Output> {
    AnyAsyncSequence(self)
  }
}
