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

@frozen @dynamicMemberLookup
public struct ValueBinding<Value>: Sendable {

  public var get: @Sendable () -> Value
  public var set: @Sendable (Value) -> Void

  public init(
    get: @escaping @Sendable () -> Value,
    set: @escaping @Sendable (Value) -> Void
  ) {
    self.get = get
    self.set = set
  }

  public var value: Value {
    get { self.get() }
    set { self.set(newValue) }
  }

  public var projectedValue: Binding<Value> {
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
    self.value[keyPath: keyPath]
  }

  public subscript<Property>(
    dynamicMember keyPath: WritableKeyPath<Value, Property>
  ) -> Property {
    get {
      self.value[keyPath: keyPath]
    }
    set {
      self.value[keyPath: keyPath] = newValue
    }
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
