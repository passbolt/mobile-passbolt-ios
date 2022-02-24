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

public final class AnyAsyncThrowingSequence<Element> {

  private let makeIterator: () -> AsyncIterator
  private var token: Any?

  public init<Upstream: Publisher>(
    _ upstream: Upstream,
    bufferingPolicy: AsyncThrowingStream<Element, Error>.Continuation.BufferingPolicy = .unbounded
  )
  where Upstream.Output == Element {
    var cancellable: AnyCancellable? = nil
    let stream: AsyncThrowingStream<Element, Error> = .init(bufferingPolicy: bufferingPolicy) { continuation in
      cancellable =
        upstream
        .handleEvents(
          receiveOutput: { output in
            continuation.yield(output)
          },
          receiveCompletion: { completion in
            switch completion {
            case .finished:
              continuation.finish(throwing: nil)

            case let .failure(error):
              continuation.finish(throwing: error)
            }
          },
          receiveCancel: {
            continuation.finish(throwing: CancellationError())
          }
        )
        .sinkDrop()
    }
    self.makeIterator = {
      var iterator: AsyncThrowingStream<Element, Error>.AsyncIterator = stream.makeAsyncIterator()
      return AsyncIterator(
        nextElement: {
          try Task.checkCancellation()
          return try await iterator.next()
        }
      )
    }
    self.token = cancellable
  }

  public init<Content>(
    _ content: Content
  ) where Content: AsyncSequence, Content.Element == Element {
    self.makeIterator = {
      var iterator: Content.AsyncIterator = content.makeAsyncIterator()
      return AsyncIterator(
        nextElement: {
          try Task.checkCancellation()
          return try await iterator.next()
        }
      )
    }
    self.token = nil
  }

  public init<Content>(
    _ content: Content
  ) where Content: Sequence, Content.Element == Element {
    self.makeIterator = {
      var iterator: Content.Iterator = content.makeIterator()
      return AsyncIterator(
        nextElement: {
          try Task.checkCancellation()
          return iterator.next()
        }
      )
    }
    self.token = nil
  }
}

extension AnyAsyncThrowingSequence: AsyncSequence {

  public struct AsyncIterator: AsyncIteratorProtocol {

    private let nextElement: () async throws -> Element?

    fileprivate init(
      nextElement: @escaping () async throws -> Element?
    ) {
      self.nextElement = nextElement
    }

    public func next() async throws -> Element? {
      try await nextElement()
    }
  }

  public func makeAsyncIterator() -> AsyncIterator {
    self.makeIterator()
  }
}

extension AsyncSequence {

  public func asAnyAsyncThrowingSequence() -> AnyAsyncThrowingSequence<Element> {
    AnyAsyncThrowingSequence(self)
  }
}
