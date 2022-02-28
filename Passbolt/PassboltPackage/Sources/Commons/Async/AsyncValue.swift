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

//import Combine
//
//public final actor AsyncValue<Value> {
//
//  public var value: Value {
//    get async {
//      self.currentValueSubject.value
//    }
////    set {
////      self.currentValueSubject.value = newValue
////    }
//  }
//  private let currentValueSubject: CurrentValueSubject<Value, Never>
//
//  public init(initial: Value) {
//    self.currentValueSubject = .init(initial)
//  }
//
////  deinit {
////    let iterators: Dictionary<AnyHashable, AsyncSharedIterator<Value>>.Values = iterators.values
////    Task {
////      for iterator in iterators {
////        await iterator.finish()
////      }
////    }
////  }
//
//  public func update(_ newValue: Value) async {
//    self.currentValueSubject.value = newValue
//  }
//
//  public func withValue<Returned>(
//    _ access: (inout Value) async -> Returned
//  ) async -> Returned {
//    var mutableValue = self.currentValueSubject.value
//    defer { self.currentValueSubject.value = mutableValue }
//    return await access(&mutableValue)
//  }
//}
//
//extension AsyncValue: AsyncSequence {
//
//  public typealias AsyncIterator = AnyAsyncIterator<Value>
//  public typealias Element = Value
//
//  public nonisolated func makeAsyncIterator() -> AnyAsyncIterator<Value> {
//    AnyAsyncSequence(
//      self.currentValueSubject,
//      bufferingPolicy: .bufferingNewest(1)
//    )
//    .makeAsyncIterator()
//  }
//}

public final actor AsyncValue<Value> {

  public fileprivate(set) var value: Value
  private var iterators: Dictionary<AnyHashable, AsyncSharedIterator<Value>> = .init()  // TODO: use WeakBox

  public init(initial: Value) {
    self.value = initial
  }

  deinit {
    let iterators: Dictionary<AnyHashable, AsyncSharedIterator<Value>>.Values = self.iterators.values
    Task {
      for iterator in iterators {
        await iterator.finish()
      }
    }
  }

  public func update(_ newValue: Value) async {
    self.value = newValue
    for iterator in self.iterators.values {
      await iterator.yield(newValue)
    }
  }

  public func withValue<Returned>(
    _ access: (inout Value) async throws -> Returned
  ) async rethrows -> Returned {
    var mutableValue = self.value
    defer { self.value = mutableValue }
    return try await access(&mutableValue)
  }
}

extension AsyncValue: AsyncSequence {

  public typealias AsyncIterator = AsyncSharedIterator<Value>
  public typealias Element = Value

  public nonisolated func makeAsyncIterator() -> AsyncSharedIterator<Value> {
    let iterator: AsyncSharedIterator<Value> = .init { identifier in
      Task {
        await self.remove(iteratorWithIdentifier: identifier)
      }
    }
    Task {
      await self.add(iterator: iterator)
    }
    return iterator
  }
}

extension AsyncValue {

  fileprivate func add(iterator: AsyncSharedIterator<Value>) async {
    self.iterators[iterator.identifier] = iterator
    await iterator.yield(self.value)
  }

  fileprivate func remove(iteratorWithIdentifier: AnyHashable) {
    self.iterators[iteratorWithIdentifier] = .none
  }
}
