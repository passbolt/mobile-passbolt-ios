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
public struct StateView<Value>
where Value: Equatable {

  private let read: @Sendable () -> Value
  private let updatesPublisher: AnyPublisher<Value, Never>

  internal init(
    read: @escaping @Sendable () -> Value,
    updatesPublisher: AnyPublisher<Value, Never>
  ) {
    self.read = read
    self.updatesPublisher = updatesPublisher
  }

  public var wrappedValue: Value {
    _read { yield self.read() }
  }

  public var projectedValue: Self {
    get { self }
    set { self = newValue }
  }
}

extension StateView {

  public func get<Property>(
    _ keyPath: KeyPath<Value, Property>
  ) -> Property {
    self.read()[keyPath: keyPath]
  }

  public func get() -> Value {
    self.read()
  }
}

extension StateView {

  public func scope<ScopedValue>(
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

  public func convert<ConvertedValue>(
    _ read: @escaping @Sendable (Value) -> ConvertedValue
  ) -> StateView<ConvertedValue> {
    StateView<ConvertedValue>(
      read: { read(self.read()) },
      updatesPublisher: self
        .updatesPublisher
        .map(read)
        .removeDuplicates()
        .eraseToAnyPublisher()
    )
  }
}

extension StateView: Equatable
where Value: Equatable {

  public static func == (
    _ lhs: StateView,
    _ rhs: StateView
  ) -> Bool {
    lhs.read() == rhs.read()
  }
}

extension StateView: Hashable
where Value: Hashable {

  public func hash(
    into hasher: inout Hasher
  ) {
    hasher.combine(self.read())
  }
}

extension StateView: @unchecked Sendable
where Value: Sendable {}

extension StateView: Publisher {

  public typealias Output = Value
  public typealias Failure = Never

  public func receive<S>(
    subscriber: S
  ) where S: Subscriber, S.Input == Value, S.Failure == Never {
    self.updatesPublisher
      .receive(subscriber: subscriber)
  }
}

extension StateView {

  #if DEBUG
  public static var placeholder: Self {
    .init(
      read: unimplemented(),
      updatesPublisher: Empty()
        .eraseToAnyPublisher()
    )
  }
  #endif
}
