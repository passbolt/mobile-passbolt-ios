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

public struct AnyAsyncThrowingSequence<Element> {

  private let makeIterator: () -> AsyncIterator

  public init<Upstream: Publisher>(
    _ upstream: Upstream
  ) where Upstream.Output == Element {
    if #available(iOS 15.0, *) {
      self.makeIterator = {
        var iterator: AsyncThrowingPublisher<Upstream>.Iterator = upstream.values.makeAsyncIterator()
        return AnyAsyncThrowingIterator<Element>(
          nextElement: {
            try await iterator.next()
          }
        )
      }
    }
    else {
      let stream: AsyncThrowingStream<Element, Error> =
        .init(
          bufferingPolicy: .unbounded  // trying to mimic combine
        ) { continuation in
          var cancellable: AnyCancellable?
          let termination = { cancellable?.cancel() }
          continuation.onTermination = { @Sendable _ in
            termination()
          }

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
        return AnyAsyncThrowingIterator<Element>(
          nextElement: {
            try await iterator.next()
          }
        )
      }
    }
  }

  public init<Content>(
    _ content: Content
  ) where Content: AsyncSequence, Content.Element == Element {
    self.makeIterator = {
      var iterator: Content.AsyncIterator = content.makeAsyncIterator()
      return AnyAsyncThrowingIterator<Element>(
        nextElement: {
          try await iterator.next()
        }
      )
    }
  }

  public init<Content>(
    _ content: Content
  ) where Content: Sequence, Content.Element == Element {
    self.makeIterator = {
      var iterator: Content.Iterator = content.makeIterator()
      return AnyAsyncThrowingIterator<Element>(
        nextElement: {
          iterator.next()
        }
      )
    }
  }
}

extension AnyAsyncThrowingSequence: AsyncSequence {

  public func makeAsyncIterator() -> AnyAsyncThrowingIterator<Element> {
    self.makeIterator()
  }
}

extension Sequence {

  public func asAnyAsyncThrowingSequence() -> AnyAsyncThrowingSequence<Element> {
    AnyAsyncThrowingSequence(self)
  }
}

extension AsyncSequence {

  public func asAnyAsyncThrowingSequence() -> AnyAsyncThrowingSequence<Element> {
    AnyAsyncThrowingSequence(self)
  }
}

extension Publisher {

  public func asAnyAsyncThrowingSequence() -> AnyAsyncThrowingSequence<Output> {
    AnyAsyncThrowingSequence(self)
  }
}
