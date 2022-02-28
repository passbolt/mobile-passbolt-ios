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

public final actor AsyncThrowingSharedIterator<Element> {

  private var state: State = .waiting
  private var awaiters: Array<CheckedContinuation<Element?, Error>> = .init()
  private let cleanup: (AnyHashable) -> Void

  // internal use only
  internal init(
    cleanup: @escaping (AnyHashable) -> Void = { _ in }
  ) {
    self.cleanup = cleanup
  }

  deinit {
    for awaiter in self.awaiters {
      awaiter.resume(returning: .none)
    }
    self.cleanup(self.identifier)
  }
}

extension AsyncThrowingSharedIterator: AsyncIteratorProtocol {

  public func next() async throws -> Element? {
    try await self.requestValue()
  }
}

extension AsyncThrowingSharedIterator {

  internal nonisolated var identifier: AnyHashable {
    ObjectIdentifier(self)
  }

  internal func yield(
    _ element: Element
  ) async {
    switch self.state {
    case .waiting where self.awaiters.isEmpty:
      self.state = .buffered(element)

    case .waiting:
      while let awaiter = self.awaiters.popLast() {
        awaiter.resume(returning: element)
      }

    case .buffered:
      self.state = .buffered(element)

    case .finished:
      break
    }
  }

  public func finish(
    throwing: Error? = .none
  ) async {
    switch self.state {
    case .waiting, .buffered:
      self.state = .finished(throwing)
      if let error: Error = throwing {
        while let awaiter = self.awaiters.popLast() {
          awaiter.resume(throwing: error)
        }
      }
      else {
        while let awaiter = self.awaiters.popLast() {
          awaiter.resume(returning: .none)
        }
      }

    case .finished:
      break
    }
  }
}

extension AsyncThrowingSharedIterator {

  fileprivate func requestValue() async throws -> Element? {
    try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Element?, Error>) in
      switch self.state {
      case .waiting:
        self.awaiters.append(continuation)

      case let .buffered(element):
        self.state = .waiting
        continuation.resume(returning: element)

      case .finished(.none):
        continuation.resume(returning: .none)

      case let .finished(.some(error)):
        continuation.resume(throwing: error)
      }
    }
  }
}

extension AsyncThrowingSharedIterator {

  private enum State {
    case waiting
    case buffered(Element)
    case finished(Error?)
  }
}
