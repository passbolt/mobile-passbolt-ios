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

import Commons
import CoreTest

// swift-format-ignore: AlwaysUseLowerCamelCase
final class EventListTests: TestCase {

  func test_nextEvent_deliversLatestEventAfterWaiting() async throws {
    enum TestEvent: EventDescription {

      typealias Payload = Int

      nonisolated static let eventList: EventList<TestEvent> = .init()
    }

    withSerialTaskExecutor {
      TestEvent.send(0)
      Task.detached {
        await Task.yield()
        TestEvent.send(42)
      }
      Task.detached {
        try await self.verifyIf(
          await TestEvent.next(),
          isEqual: 42
        )
      }
    }
  }

  func test_subscription_nextEvent_deliversLatestEventAfterWaiting() async throws {
    enum TestEvent: EventDescription {

      typealias Payload = Int

      nonisolated static let eventList: EventList<TestEvent> = .init()
    }

    try await withSerialTaskExecutor {
      TestEvent.send(0)
      let subscription: EventSubscription = TestEvent.subscribe()
      Task.detached {
        await Task.yield()
        TestEvent.send(42)
      }
      try await verifyIf(
        await subscription.nextEvent(),
        isEqual: 42
      )
    }
  }

  func test_subscription_nextEvent_deliversLatestEventAfterSubscribing() async throws {
    enum TestEvent: EventDescription {

      typealias Payload = Int

      nonisolated static let eventList: EventList<TestEvent> = .init()
    }

    try await withSerialTaskExecutor {
      TestEvent.send(0)
      let subscription: EventSubscription = TestEvent.subscribe()
      TestEvent.send(42)
      try await verifyIf(
        await subscription.nextEvent(),
        isEqual: 42
      )
    }
  }

  func test_subscription_nextEvent_deliversAllEventsAfterSubscribing() async throws {
    enum TestEvent: EventDescription {

      typealias Payload = Int

      nonisolated static let eventList: EventList<TestEvent> = .init()
    }

    try await withSerialTaskExecutor {
      TestEvent.send(0)
      let subscription: EventSubscription = TestEvent.subscribe(bufferSize: 100)
      for i in 1 ..< 100 {
        TestEvent.send(i)
      }
      for i in 1 ..< 100 {
        try await verifyIf(
          await subscription.nextEvent(),
          isEqual: i
        )
      }
    }
  }

  func test_continuousAccess_executesWithoutIssues_concurrently() async throws {
    enum TestEvent: EventDescription {

      typealias Payload = Int

      nonisolated static let eventList: EventList<TestEvent> = .init()
    }

    await withTaskGroup(of: Void.self) { group in
      for i in 0 ..< 1_000 {
        if i.isMultiple(of: 3) {
          if i.isMultiple(of: 2) {
            group.addTask {
              let _: TestEvent.Subscription =
                TestEvent
                .subscribe()
            }
          }
          else {
            group.addTask {
              try? await TestEvent.subscribe { _ in }
            }
          }
        }
        else if i.isMultiple(of: 2) {
          group.addTask {
            _ = try? await TestEvent.next()
          }
        }
        else {
          group.addTask {
            let subscription: TestEvent.Subscription =
              TestEvent
              .subscribe()
            while !Task.isCancelled {
              _ = try? await subscription.nextEvent()
            }
          }
        }
      }
      await Task {
        for i in 0 ..< 10_000 {
          try await Task.sleep(nanoseconds: 100)
          TestEvent.send(i)
        }
      }
      .waitForCompletion()
      group.cancelAll()
      await group.waitForAll()
    }
  }

  func test_subscription_nextEvent_deliversAllEventsToAllSubscriptions() async throws {
    enum TestEvent: EventDescription {

      typealias Payload = Int

      nonisolated static let eventList: EventList<TestEvent> = .init()
    }

    try await withSerialTaskExecutor {
      TestEvent.send(0)
      var subscriptions: Array<TestEvent.Subscription> = .init()
      for _ in 0 ..< 100 {
        subscriptions.append(TestEvent.subscribe(bufferSize: 100))
      }

      for i in 1 ..< 100 {
        TestEvent.send(i)
      }
      for subscription in subscriptions {
        for i in 1 ..< 100 {
          try await verifyIf(
            await subscription.nextEvent(),
            isEqual: i
          )
        }
      }
    }
  }
}
