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

extension Publisher
where Failure == Never {

  public func asAsyncSequence() -> AnyAsyncSequence<Output> {
    AnyAsyncSequence(self)
  }
}

extension Publisher {

  @_disfavoredOverload
  public func asAsyncSequence() -> AnyAsyncSequence<Output> {
    AnyAsyncSequence(self)
  }
}

extension AsyncSequence {

  // file:line captured only for diagnostics
  public func asThrowingPublisher() -> AnyPublisher<Element, Error> {
    ThrowingSequencePublisher(sequence: self)
      .autoconnect()
      .eraseToAnyPublisher()
  }
}

private struct ThrowingSequencePublisher<PublishedSequence>: ConnectablePublisher
where PublishedSequence: AsyncSequence {

  fileprivate typealias Output = PublishedSequence.Element
  fileprivate typealias Failure = Error

  private let subject: CurrentValueSubject<Output?, Failure> = .init(.none)
  private let sequence: PublishedSequence

  fileprivate init(
    sequence: PublishedSequence
  ) {
    self.sequence = sequence
  }

  public func receive<S>(
    subscriber: S
  ) where S: Subscriber, S.Input == Output, S.Failure == Failure {
    self.subject
      .compactMap({ $0 })
      .receive(subscriber: subscriber)
  }

  public func connect() -> Cancellable {
    let task: Task<Void, Never> = .init {
      do {
        for try await element: Output in self.sequence {
          try Task.checkCancellation()
          self.subject.send(element)
        }
        self.subject.send(completion: .finished)
      }
      catch is Cancelled {
        self.subject.send(completion: .finished)
      }
      catch {
        self.subject.send(completion: .failure(error))
      }
    }

    return AnyCancellable(task.cancel)
  }
}
