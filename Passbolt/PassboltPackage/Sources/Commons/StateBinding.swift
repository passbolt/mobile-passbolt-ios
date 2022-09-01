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

import struct Combine.AnyPublisher
import class Combine.CurrentValueSubject
import enum Combine.Publishers

@propertyWrapper
public struct StateBinding<Value>
where Value: Equatable {

  private let read: @Sendable () -> Value
  private let write: @Sendable (Value) -> Void
  private let updated: @Sendable () -> Void
  private let updatesPublisher: AnyPublisher<Value, Never>
  private let cancellables: Cancellables = .init()

  public static func variable(
    initial: Value
  ) -> Self {
    let valueSubject = CurrentValueSubject<Value, Never>(initial)

    return .init(
      read: { valueSubject.value },
      write: { (newValue: Value) in
        valueSubject.value = newValue
      },
      updated: {
        valueSubject.send(valueSubject.value)
      },
      updatesPublisher:
        valueSubject
        .dropFirst()
        .removeDuplicates()
        .eraseToAnyPublisher()
    )
  }

  public static func fromSource(
    read: @escaping @Sendable () -> Value,
    write: @escaping @Sendable (Value) -> Void
  ) -> Self {
    let valueSubject = PassthroughSubject<Value, Never>()

    return .init(
      read: read,
      write: { (newValue: Value) in
        write(newValue)
        valueSubject.send(newValue)
      },
      updated: {
        valueSubject.send(read())
      },
      updatesPublisher:
        valueSubject
        .removeDuplicates()
        .eraseToAnyPublisher()
    )
  }

  private init(
    read: @escaping @Sendable () -> Value,
    write: @escaping @Sendable (Value) -> Void,
    updated: @escaping @Sendable () -> Void,
    updatesPublisher: AnyPublisher<Value, Never>
  ) {
    self.read = read
    self.write = write
    self.updated = updated
    self.updatesPublisher = updatesPublisher
  }

  public var wrappedValue: Value {
    _read { yield self.read() }
    _modify {
      var value = self.read()
      yield &value
      self.write(value)
    }
  }

  public var projectedValue: Self {
    get { self }
    set { self = newValue }
  }
}

extension StateBinding {

  public func get<Property>(
    _ keyPath: KeyPath<Value, Property>
  ) -> Property {
    self.read()[keyPath: keyPath]
  }

  public func get() -> Value {
    self.read()
  }

  public func set<Property>(
    _ keyPath: WritableKeyPath<Value, Property>,
    to newValue: Property
  ) {
    self.mutate { (value: inout Value) in
      value[keyPath: keyPath] = newValue
    }
  }

  public func set(
    to newValue: Value
  ) {
    self.mutate { (value: inout Value) in
      value = newValue
    }
  }

  // mutate without triggering observers multiple times
  public func mutate<Returned>(
    _ mutation: (inout Value) throws -> Returned
  ) rethrows -> Returned {
    var value = self.read()
    do {
      defer { self.write(value) }
      return try mutation(&value)
    }
    catch {
      throw error
    }
  }
}

extension StateBinding {

  public func bind<Property>(
    _ keyPath: KeyPath<Value, StateBinding<Property>>
  ) {
    self.read()[keyPath: keyPath]
      .sink { (_: Property) in
        self.updated()
      }
      .store(in: self.cancellables)
  }

  public func bind<Property>(
    _ keyPath: KeyPath<Value, StateView<Property>>
  ) {
    self.read()[keyPath: keyPath]
      .sink { (_: Property) in
        self.updated()
      }
      .store(in: self.cancellables)
  }

  public func scope<ScopedValue>(
    _ keyPath: WritableKeyPath<Value, ScopedValue>
  ) -> StateBinding<ScopedValue> {
    StateBinding<ScopedValue>(
      read: { self.read()[keyPath: keyPath] },
      write: { (newValue: ScopedValue) in
        self.mutate { (value: inout Value) in
          value[keyPath: keyPath] = newValue
        }
      },
      updated: self.updated,
      updatesPublisher: self
        .updatesPublisher
        .map(keyPath)
        .removeDuplicates()
        .eraseToAnyPublisher()
    )
  }

  public func scopeView<ScopedValue>(
    _ keyPath: KeyPath<Value, ScopedValue>
  ) -> StateView<ScopedValue> {
    StateView<ScopedValue>(
      read: { self.read()[keyPath: keyPath] },
      updatesPublisher: self
        .updatesPublisher
        .map(keyPath)
        .removeDuplicates()
        .eraseToAnyPublisher()
    )
  }

  public func scopeView<ScopedValue>(
    _ mapping: @escaping @Sendable (Value) -> ScopedValue
  ) -> StateView<ScopedValue> {
    StateView<ScopedValue>(
      read: { mapping(self.read()) },
      updatesPublisher: self
        .updatesPublisher
        .map(mapping)
        .removeDuplicates()
        .eraseToAnyPublisher()
    )
  }

  public func convert<ConvertedValue>(
    read: @escaping @Sendable (Value) -> ConvertedValue,
    write: @escaping @Sendable (ConvertedValue) -> Value
  ) -> StateBinding<ConvertedValue> {
    StateBinding<ConvertedValue>(
      read: { read(self.read()) },
      write: { (newValue: ConvertedValue) in
        self.mutate { (value: inout Value) in
          value = write(newValue)
        }
      },
      updated: self.updated,
      updatesPublisher: self
        .updatesPublisher
        .map(read)
        .removeDuplicates()
        .eraseToAnyPublisher()
    )
  }
}

extension StateBinding {

  public static func combined<ValueA, ValueB>(
    _ stateA: StateBinding<ValueA>,
    _ stateB: StateBinding<ValueB>,
    compose: @escaping @Sendable (ValueA, ValueB) -> Value,
    decompose: @escaping @Sendable (Value) -> (ValueA, ValueB)
  ) -> Self {
    Self(
      read: {
        compose(
          stateA.read(),
          stateB.read()
        )
      },
      write: { (newValue: Value) in
        let (valueA, valueB) = decompose(newValue)
        stateA.mutate { (value: inout ValueA) in
          value = valueA
        }
        stateB.mutate { (value: inout ValueB) in
          value = valueB
        }
      },
      updated: {
        stateA.updated()
        stateB.updated()
      },
      updatesPublisher:
        Publishers
        .CombineLatest(
          stateA.updatesPublisher,
          stateB.updatesPublisher
        )
        .map(compose)
        .removeDuplicates()
        .eraseToAnyPublisher()
    )
  }

  public static func combined<ValueA, ValueB, ValueC>(
    _ stateA: StateBinding<ValueA>,
    _ stateB: StateBinding<ValueB>,
    _ stateC: StateBinding<ValueC>,
    compose: @escaping @Sendable (ValueA, ValueB, ValueC) -> Value,
    decompose: @escaping @Sendable (Value) -> (ValueA, ValueB, ValueC)
  ) -> Self {
    Self(
      read: {
        compose(
          stateA.read(),
          stateB.read(),
          stateC.read()
        )
      },
      write: { (newValue: Value) in
        let (valueA, valueB, valueC) = decompose(newValue)
        stateA.mutate { (value: inout ValueA) in
          value = valueA
        }
        stateB.mutate { (value: inout ValueB) in
          value = valueB
        }
        stateC.mutate { (value: inout ValueC) in
          value = valueC
        }
      },
      updated: {
        stateA.updated()
        stateB.updated()
        stateC.updated()
      },
      updatesPublisher:
        Publishers
        .CombineLatest3(
          stateA.updatesPublisher,
          stateB.updatesPublisher,
          stateC.updatesPublisher
        )
        .map(compose)
        .removeDuplicates()
        .eraseToAnyPublisher()
    )
  }
}

extension StateBinding: Equatable
where Value: Equatable {

  public static func == (
    _ lhs: StateBinding,
    _ rhs: StateBinding
  ) -> Bool {
    lhs.read() == rhs.read()
  }
}

extension StateBinding: Hashable
where Value: Hashable {

  public func hash(
    into hasher: inout Hasher
  ) {
    hasher.combine(self.read())
  }
}

extension StateBinding: @unchecked Sendable
where Value: Sendable {}

extension StateBinding: Publisher {

  public typealias Output = Value
  public typealias Failure = Never

  public func receive<S>(
    subscriber: S
  ) where S: Subscriber, S.Input == Value, S.Failure == Never {
    self.updatesPublisher
      .receive(subscriber: subscriber)
  }
}

extension StateBinding {

  #if DEBUG
  public static var placeholder: Self {
    .init(
      read: unimplemented(),
      write: unimplemented(),
      updated: unimplemented(),
      updatesPublisher: Empty()
        .eraseToAnyPublisher()
    )
  }
  #endif
}
