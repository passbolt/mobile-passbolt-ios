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

import struct SwiftUI.Binding

@frozen @dynamicMemberLookup @propertyWrapper
public struct ValueBinding<Value> {

  public let get: @Sendable () -> Value
  public let set: @Sendable (Value) -> Void
  private let observers: CriticalState<Dictionary<IID, @Sendable (Value) -> Void>>

  public init(
    get: @escaping @Sendable () -> Value,
    set: @escaping @Sendable (Value) -> Void
  ) {
    let observers: CriticalState<Dictionary<IID, @Sendable (Value) -> Void>> = .init(.init())
    self.get = get
    self.set = { @Sendable (newValue: Value) in
      set(newValue)
      let observers: Dictionary<IID, @Sendable (Value) -> Void> = observers.get(\.self)
      observers.values.forEach { (observer: @Sendable (Value) -> Void) in
        observer(newValue)
      }
    }
    self.observers = observers
  }

  public var wrappedValue: Value {
    get { self.get() }
    set { self.set(newValue) }
  }

  public var projectedValue: ValueBinding<Value> {
    get { self }
    set { self = newValue }
  }

  public var binding: Binding<Value> {
    .init(
      get: self.get,
      set: self.set
    )
  }
}

extension ValueBinding {

  public static func constant(
    _ value: Value
  ) -> Self {
    .init(
      get: { value },
      set: { _ in /* NOP */ }
    )
  }

  public static func variable(
    initial value: Value
  ) -> Self {
    let state: CriticalState<Value> = .init(value)
    return .init(
      get: {
        state.get(\.self)
      },
      set: { newValue in
        state.set(\.self, newValue)
      }
    )
  }

  @discardableResult
  public func onUpdate(
    _ execute: @escaping @Sendable (Value) -> Void
  ) -> IID {
    let id: IID = .init()
    self.observers.access { (observers: inout Dictionary<IID, @Sendable (Value) -> Void>) in
      observers[id] = execute
    }
    return id
  }

  public func convert<Mapped>(
    get getMapping: @escaping @Sendable (Value) -> Mapped,
    set setMapping: @escaping @Sendable (Mapped) -> Value
  ) -> ValueBinding<Mapped> {
    ValueBinding<Mapped>(
      get: {
        getMapping(self.get())
      },
      set: { updatedValue in
        self.set(setMapping(updatedValue))
      }
    )
  }

  public subscript<Property>(
    dynamicMember keyPath: KeyPath<Value, Property>
  ) -> Property {
    self.wrappedValue[keyPath: keyPath]
  }

  public subscript<Property>(
    dynamicMember keyPath: WritableKeyPath<Value, Property>
  ) -> Property {
    get {
      self.wrappedValue[keyPath: keyPath]
    }
    set {
      self.wrappedValue[keyPath: keyPath] = newValue
    }
  }

  @inlinable @Sendable public func set<Property>(
    _ keyPath: WritableKeyPath<Value, Property>,
    _ newValue: Property
  ) {
    var value: Value = self.get()
    value[keyPath: keyPath] = newValue
    self.set(value)
  }
}

extension ValueBinding: @unchecked Sendable where Value: Sendable {}

extension ValueBinding: Equatable where Value: Equatable {

  public static func == (
    _ lhs: ValueBinding<Value>,
    _ rhs: ValueBinding<Value>
  ) -> Bool {
    lhs.wrappedValue == rhs.wrappedValue
  }
}

extension ValueBinding: Hashable where Value: Hashable {

  public func hash(
    into hasher: inout Hasher
  ) {
    hasher.combine(self.wrappedValue)
  }
}

#if DEBUG

extension ValueBinding {

  public static var placeholder: Self {
    .init(
      get: unimplemented(),
      set: unimplemented()
    )
  }
}
#endif
