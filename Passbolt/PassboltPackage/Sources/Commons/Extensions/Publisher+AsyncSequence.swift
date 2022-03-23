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

extension Publisher {

  public func asAsyncThrowingSequence() -> AnyAsyncThrowingSequence<Output> {
    AnyAsyncThrowingSequence(self)
  }
}

extension Publisher where Failure == Never {

  public func asAsyncSequence() -> AnyAsyncSequence<Output> {
    AnyAsyncSequence(self)
  }
}

extension AsyncSequence {

  public func asPublisher() -> AnyPublisher<Element, Never> {
    let subject: PassthroughSubject<Element, Never> = .init()
    let recurringTask: RecurringTask = .init {
      do {
        for try await element in self {
          subject.send(element)
        }
        subject.send(completion: .finished)
      }
      catch {
        error
          .asTheError()
          .asAssertionFailure(
            message: "Assuming nonthrowing sequence, plese use throwing publisher conversion instead"
          )
        subject.send(completion: .finished)
      }
    }
    return
      subject
      .handleEvents(
        receiveSubscription: { _ in
          Task.detached {
            await recurringTask.run(replacingCurrent: false)
          }
        },
        receiveCancel: {
          Task.detached {
            await recurringTask.cancel()
          }
        }
      )
      .eraseToAnyPublisher()
  }
}

extension AsyncSequence {

  public func asThrowingPublisher() -> AnyPublisher<Element, Error> {
    let subject: PassthroughSubject<Element, Error> = .init()
    let recurringTask: RecurringTask = .init {
      do {
        for try await element in self {
          subject.send(element)
        }
        subject.send(completion: .finished)
      }
      catch {
        subject.send(completion: .failure(error))
      }
    }
    return
      subject
      .handleEvents(
        receiveSubscription: { _ in
          Task.detached {
            await recurringTask.run(replacingCurrent: false)
          }
        },
        receiveCancel: {
          Task.detached {
            await recurringTask.cancel()
          }
        }
      )
      .eraseToAnyPublisher()
  }
}

// swift-format-ignore: AlwaysUseLowerCamelCase
public func AsyncPublisher<Value>(
  _ operation: @escaping (@escaping (Value) -> Void) async throws -> Void
) -> AnyPublisher<Value, Never> {
  let subject: PassthroughSubject<Value, Never> = .init()
  let recurringTask: RecurringTask = .init {
    do {
      try await operation(subject.send)
      subject.send(completion: .finished)
    }
    catch {
      error
        .asTheError()
        .asAssertionFailure(
          message: "Assuming nonthrowing sequence, plese use throwing publisher conversion instead"
        )
      subject.send(completion: .finished)
    }
  }
  Task { await recurringTask.run() }
  return
    subject
    .handleEvents(
      receiveSubscription: { _ in
        Task.detached {
          await recurringTask.run(replacingCurrent: false)
        }
      },
      receiveCancel: {
        Task.detached {
          await recurringTask.cancel()
        }
      }
    )
    .eraseToAnyPublisher()
}

// swift-format-ignore: AlwaysUseLowerCamelCase
public func AsyncThrowingPublisher<Value>(
  _ operation: @escaping (@escaping (Value) -> Void) async throws -> Void
) -> AnyPublisher<Value, Error> {
  let subject: PassthroughSubject<Value, Error> = .init()
  let recurringTask: RecurringTask = .init {
    do {
      try await operation(subject.send)
      subject.send(completion: .finished)
    }
    catch {
      subject.send(completion: .failure(error))
    }
  }
  Task { await recurringTask.run() }
  return
    subject
    .handleEvents(
      receiveSubscription: { _ in
        Task.detached {
          await recurringTask.run(replacingCurrent: false)
        }
      },
      receiveCancel: {
        Task.detached {
          await recurringTask.cancel()
        }
      }
    )
    .eraseToAnyPublisher()
}
