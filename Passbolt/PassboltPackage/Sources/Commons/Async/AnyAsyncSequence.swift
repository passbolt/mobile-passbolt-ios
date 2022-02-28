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

public struct AnyAsyncSequence<Element> {

  private let makeIterator: () -> AsyncIterator

  public init<Upstream: Publisher>(
    _ upstream: Upstream,
    bufferingPolicy: AsyncStream<Element>.Continuation.BufferingPolicy = .unbounded
  ) where Upstream.Output == Element, Upstream.Failure == Never {
    if #available(iOS 15.0, *) {
      self.makeIterator = {
        var iterator: AsyncPublisher<Upstream>.Iterator = upstream.values.makeAsyncIterator()
        return AnyAsyncIterator<Element>(
          nextElement: {
            await iterator.next()
          }
        )
      }
    }
    else {
      let stream: AsyncStream<Element> =
        .init(
          bufferingPolicy: bufferingPolicy
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
                  continuation.finish()

                case .failure:
                  unreachable("Failure is Never")
                }
              },
              receiveCancel: {
                continuation.finish()  // just finishing on cancel
              }
            )
            .sinkDrop()
        }

      self.makeIterator = {
        var iterator: AsyncStream<Element>.AsyncIterator = stream.makeAsyncIterator()
        return AnyAsyncIterator<Element>(
          nextElement: {
            await iterator.next()
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
      return AnyAsyncIterator<Element>(
        nextElement: {
          do {
            return try await iterator.next()
          }
          catch _ as CancellationError {
            // treated as sequence end since we can't rethrow
            return nil
          }
          catch {
            // we can't get the details if Content sequence is throwing or not
            // so if it is it will be treated as sequence end since we can't rethrow
            error
              .asTheError()
              .asAssertionFailure(
                message:
                  "AnyAsyncSequence should not use throwing sequences, please use AnyAsyncThrowingSequence instead"
              )
            return nil
          }
        }
      )
    }
  }

  public init<Content>(
    _ content: Content
  ) where Content: Sequence, Content.Element == Element {
    self.makeIterator = {
      var iterator: Content.Iterator = content.makeIterator()
      return AnyAsyncIterator<Element>(
        nextElement: {
          iterator.next()
        }
      )
    }
  }
}

extension AnyAsyncSequence: AsyncSequence {

  public func makeAsyncIterator() -> AnyAsyncIterator<Element> {
    self.makeIterator()
  }
}

extension Sequence {

  public func asAnyAsyncSequence() -> AnyAsyncSequence<Element> {
    AnyAsyncSequence(self)
  }
}

extension AsyncSequence {

  public func asAnyAsyncSequence() -> AnyAsyncSequence<Element> {
    AnyAsyncSequence(self)
  }
}

extension Publisher where Failure == Never {

  public func asAnyAsyncSequence() -> AnyAsyncSequence<Output> {
    AnyAsyncSequence(self)
  }
}
