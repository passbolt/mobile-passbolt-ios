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
  ) -> Publishers.ShareReplay<Self> {
    Publishers.ShareReplay(
      upstream: self,
      bufferSize: bufferSize
    )
  }
}

extension Publishers {

  public final class ShareReplay<Upstream: Publisher>: Publisher {

    public typealias Output = Upstream.Output
    public typealias Failure = Upstream.Failure

    private let downstream: Autoconnect<Multicast<Upstream, ReplaySubject<Upstream.Output, Upstream.Failure>>>

    fileprivate init(
      upstream: Upstream,
      bufferSize: Int
    ) {
      self.downstream = upstream
        .multicast {
          ReplaySubject<Upstream.Output, Upstream.Failure>(
            bufferSize: bufferSize
          )
        }
        .autoconnect()
    }

    public func receive<S: Subscriber>(
      subscriber: S
    ) where S.Failure == Failure, S.Input == Output {
      downstream.subscribe(subscriber)
    }
  }
}

extension Publishers.ShareReplay {

  fileprivate final class ReplaySubject<Output, Failure: Error>: Subject {

    private let bufferSize: Int
    private var buffer: Array<Output> = .init()
    private var subscriptions: Dictionary<CombineIdentifier, Inner<Output, Failure>> = .init()
    private var completion: Subscribers.Completion<Failure>?
    private let lock: NSRecursiveLock = .init()

    fileprivate init(
      bufferSize: Int
    ) {
      assert(bufferSize > 0, "Buffer size has to be greather than zero")
      self.bufferSize = bufferSize
      self.buffer.reserveCapacity(bufferSize + 1)
    }

    fileprivate func receive<S>(
      subscriber: S
    ) where S: Subscriber, Failure == S.Failure, Output == S.Input {
      let subscriberIdentifier: CombineIdentifier
        = subscriber.combineIdentifier
      let subscription: Inner
        = .init(
          downstream: subscriber,
          bufferSize: self.bufferSize,
          cleanup: { [weak self] in
            guard let self = self else { return }
            self.lock.lock()
            self.subscriptions.removeValue(forKey: subscriberIdentifier)
            self.lock.unlock()
          }
        )

      self.lock.lock()
      defer { self.lock.unlock() }
      self.subscriptions[subscriberIdentifier] = subscription
      subscriber.receive(subscription: subscription)
      subscription
        .replay(
          self.buffer,
          completion: self.completion
        )
    }

    fileprivate func send(
      _ value: Output
    ) {
      self.lock.lock()
      defer { self.lock.unlock() }
      guard self.completion == nil else { return }
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
      guard self.completion == nil else { return }
      self.completion = completion
      for (_, subscription) in self.subscriptions {
        subscription.receive(completion: completion)
      }
      self.subscriptions.removeAll(keepingCapacity: false)
    }

    fileprivate func send(
      subscription: Subscription
    ) {
      subscription.request(.unlimited)
    }
  }
}

extension Publishers.ShareReplay.ReplaySubject {

  fileprivate final class Inner<Input, Failure: Error>: Subscription {

    private var demand: Subscribers.Demand = .none
    private let bufferSize: Int
    private var buffer: Array<Input> = .init()
    private var downstream: AnySubscriber<Input, Failure>?
    private let cleanup: () -> Void
    private let lock: NSRecursiveLock = .init()

    fileprivate init<Downstream: Subscriber>(
      downstream: Downstream,
      bufferSize: Int,
      cleanup: @escaping () -> Void
    ) where Downstream.Input == Input, Downstream.Failure == Failure {
      assert(bufferSize > 0, "Buffer size has to be greather than zero")
      self.bufferSize = bufferSize
      self.buffer.reserveCapacity(bufferSize + 1)
      self.downstream = AnySubscriber(downstream)
      self.cleanup = cleanup
    }

    fileprivate func receive(
      _ input: Input
    ) {
      self.lock.lock()
      defer { self.lock.unlock() }

      guard let downstream = self.downstream
      else {
        return self.buffer.removeAll(keepingCapacity: false)
      }

      if self.demand > 0 {
        assert(
          self.buffer.isEmpty,
          "Invalid state, nonempty buffer with existing demand"
        )
        self.demand -= 1
        self.demand += downstream.receive(input)
      }
      else {
        self.buffer.append(input)
        self.buffer = self.buffer.suffix(self.bufferSize)
      }
    }

    fileprivate func receive(
      completion: Subscribers.Completion<Failure>
    ) {
      self.lock.lock()
      defer { self.lock.unlock() }

      guard let downstream = self.downstream
      else { return }

      self.downstream = nil
      self.buffer.removeAll(keepingCapacity: false)
      downstream.receive(completion: completion)
      self.cleanup()
    }

    fileprivate func request(
      _ demand: Subscribers.Demand
    ) {
      self.lock.lock()
      defer { self.lock.unlock() }

      guard let downstream = self.downstream
      else { return }

      self.demand += demand
      // It turns out that due to combine demand solution
      // we have to maintain buffer for each subscription
      // and replay it when demand occurs
      while self.demand > 0, !self.buffer.isEmpty {
        self.demand -= 1
        self.demand += downstream.receive(self.buffer.removeFirst())
      }
    }

    fileprivate func cancel() {
      self.lock.lock()
      defer { self.lock.unlock() }

      guard self.downstream != nil
      else { return }

      self.downstream = nil
      self.buffer.removeAll(keepingCapacity: false)
      self.cleanup()
    }

    fileprivate func replay(
      _ values: Array<Input>,
      completion: Subscribers.Completion<Failure>?
    ) {
      for value in values {
        self.receive(value)
      }
      guard let completion: Subscribers.Completion<Failure> = completion
      else { return }
      self.receive(completion: completion)
    }
  }
}
