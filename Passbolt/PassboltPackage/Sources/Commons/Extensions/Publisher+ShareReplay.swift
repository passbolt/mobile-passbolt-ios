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

import class Foundation.NSRecursiveLock

extension Publisher {

  /// Behaves like share but replies given buffer size for new subscribers.
  ///
  /// - parameter bufferSize: size of buffer replied for new subscriptions, default is 1
  public func shareReplay(
    _ bufferSize: Int = 1
  ) -> AnyPublisher<Output, Failure> {
    multicast { ReplaySubject(bufferSize) }
      .autoconnect()
      .eraseToAnyPublisher()
  }
}

private final class ReplaySubject<Output, Failure: Error>: Subject {

  private var subscriptions: Dictionary<CombineIdentifier, ReplaySubjectSubscription<Output, Failure>> = .init()
  private var completion: Subscribers.Completion<Failure>?
  private var buffer: Array<Output> = .init()
  private let bufferSize: Int
  private let lock: NSRecursiveLock = .init()

  private var completed: Bool { completion != nil }

  fileprivate init(
    _ bufferSize: Int
  ) {
    assert(bufferSize >= 0, "Cannot use negative buffer size")
    self.bufferSize = bufferSize
    self.buffer.reserveCapacity(bufferSize + 1)
  }
}

extension ReplaySubject {

  fileprivate func receive<Downstream: Subscriber>(
    subscriber: Downstream
  ) where Downstream.Failure == Failure, Downstream.Input == Output {
    self.lock.lock()
    defer { self.lock.unlock() }
    let subscriberIdentifier: CombineIdentifier = subscriber.combineIdentifier
    let subscription: ReplaySubjectSubscription<Output, Failure> = .init(
      downstream: AnySubscriber(subscriber),
      bufferSize: bufferSize
    )
    self.subscriptions[subscriberIdentifier] = subscription
    subscription.completion = { [weak self] in
      guard let self = self else { return }
      self.lock.lock()
      self.subscriptions.removeValue(forKey: subscriberIdentifier)
      self.lock.unlock()
    }
    subscriber.receive(subscription: subscription)
    subscription.replay(self.buffer, completion: self.completion)
  }
}

extension ReplaySubject {

  fileprivate func send(
    subscription: Subscription
  ) {
    subscription.request(.unlimited)
  }

  fileprivate func send(
    _ value: Output
  ) {
    self.lock.lock()
    defer { self.lock.unlock() }
    guard !completed else { return }
    self.buffer.append(value)
    self.buffer = self.buffer.suffix(self.bufferSize)
    for (_, subscription) in self.subscriptions {
      subscription.receive(value)
    }
  }

  fileprivate func send(
    completion: Subscribers.Completion<Failure>
  ) {
    self.lock.lock()
    defer { self.lock.unlock() }
    guard !completed else { return }
    self.completion = completion
    for (_, subscription) in self.subscriptions {
      subscription.receive(completion: completion)
    }
    self.subscriptions.removeAll(keepingCapacity: false)
  }
}

private final class ReplaySubjectSubscription<Output, Failure: Error>: Subscription {

  private var downstream: AnySubscriber<Output, Failure>?
  private var demand: Subscribers.Demand = .none
  private var buffer: Array<Output> = .init()
  private let bufferSize: Int
  fileprivate var completion: (() -> Void)?

  fileprivate init(
    downstream: AnySubscriber<Output, Failure>,
    bufferSize: Int
  ) {
    assert(bufferSize >= 0, "Cannot use negative buffer size")
    self.downstream = downstream
    self.bufferSize = bufferSize
    self.buffer.reserveCapacity(bufferSize + 1)
  }

  fileprivate func request(
    _ newDemand: Subscribers.Demand
  ) {
    self.demand += newDemand
    while self.demand > 0, !self.buffer.isEmpty {
      self.demand += self.downstream?.receive(self.buffer.removeFirst()) ?? .none
    }
  }

  fileprivate func cancel() {
    self.downstream = nil
    self.demand = .none
    self.completion?()
  }

  fileprivate func receive(
    _ value: Output
  ) {
    if self.demand > 0 {
      self.buffer.removeAll(keepingCapacity: true)
      self.demand -= 1
      self.request(self.downstream?.receive(value) ?? .none)
    }
    else if downstream != nil {
      self.buffer.append(value)
      self.buffer = self.buffer.suffix(self.bufferSize)
    }
    else {
      self.buffer.removeAll(keepingCapacity: true)
    }
  }

  fileprivate func receive(
    completion: Subscribers.Completion<Failure>
  ) {
    self.downstream?.receive(completion: completion)
    self.downstream = nil
    self.demand = .none
    self.completion?()
  }

  fileprivate func replay(
    _ values: Array<Output>,
    completion: Subscribers.Completion<Failure>?
  ) {

    if let completion: Subscribers.Completion<Failure> = completion {
      self.receive(completion: completion)
    }
    else {
      for value in values {
        self.receive(value)
      }
    }
  }
}
