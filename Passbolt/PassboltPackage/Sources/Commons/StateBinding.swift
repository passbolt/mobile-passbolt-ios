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

@available(*, deprecated, message: "Use Updatable instead")
@propertyWrapper
public struct StateBinding<Value> {

  public let updates: any Updatable<Void>
  private let read: @Sendable () -> Value
  private let write: @Sendable (Value) -> Void
  private let updatesSource: Updates

  public static func variable(
    initial: Value
  ) -> Self
  where Value: Equatable {
    Self.variable(
      initial: initial,
      removeDuplicates: ==
    )
  }

  public static func variable(
    initial: Value,
    removeDuplicates isDuplicate: @escaping (Value, Value) -> Bool
  ) -> Self {
    let state: CriticalState<Value> = .init(initial)
    let updatesSource: Updates = .init()

    return .init(
      updates: updatesSource,
      read: { state.get() },
      write: { (newValue: Value) in
        let updated: Bool = state.access { (value: inout Value) in
          if isDuplicate(value, newValue) {
            return false
          }
          else {
            value = newValue
            return true
          }
        }
        guard updated else { return }
        updatesSource.update()
      },
      updatesSource: updatesSource
    )
  }

  public static func fromSource(
    read: @escaping @Sendable () -> Value,
    write: @escaping @Sendable (Value) -> Void
  ) -> Self {
    let updatesSource: Updates = .init()

    return .init(
      updates: updatesSource,
      read: read,
      write: { (newValue: Value) in
        write(newValue)
        updatesSource.update()
      },
      updatesSource: updatesSource
    )
  }

  // make sure that proper duplicates filtering is applied
  private init(
    updates: any Updatable<Void>,
    read: @escaping @Sendable () -> Value,
    write: @escaping @Sendable (Value) -> Void,
    updatesSource: Updates
  ) {
    self.updates = updates
    self.read = read
    self.write = write
    self.updatesSource = updatesSource
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

  @Sendable public func get<Property>(
    _ keyPath: KeyPath<Value, Property>
  ) -> Property {
    self.read()[keyPath: keyPath]
  }

  @Sendable public func get() -> Value {
    self.read()
  }

  @Sendable public func set<Property>(
    _ keyPath: WritableKeyPath<Value, Property>,
    to newValue: Property
  ) {
    self.mutate { (value: inout Value) in
      value[keyPath: keyPath] = newValue
    }
  }

  @Sendable public func set(
    to newValue: Value
  ) {
    self.mutate { (value: inout Value) in
      value = newValue
    }
  }

  // mutate without triggering observers multiple times
  @Sendable public func mutate<Returned>(
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

  public func convert<ConvertedValue>(
    read: @escaping @Sendable (Value) -> ConvertedValue,
    write: @escaping @Sendable (ConvertedValue) -> Value
  ) -> StateBinding<ConvertedValue> {
    StateBinding<ConvertedValue>(
      updates: self.updates,
      read: { read(self.read()) },
      write: { (newValue: ConvertedValue) in
        self.write(write(newValue))
      },
      updatesSource: .init()
    )
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
    self.updatesSource.publisher
      .map { _ in self.get() }
      .receive(subscriber: subscriber)
  }
}

extension StateBinding {

  #if DEBUG
  public static var placeholder: Self {
    .init(
      updates: PlaceholderUpdatable(),
      read: unimplemented0(),
      write: unimplemented1(),
      updatesSource: .init()
    )
  }
  #endif
}
