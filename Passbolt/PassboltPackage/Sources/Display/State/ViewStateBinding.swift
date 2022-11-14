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

@MainActor @propertyWrapper @dynamicMemberLookup
public final class ViewStateBinding<Value>: ObservableObject
where Value: Hashable {

  #if DEBUG
  public nonisolated static var placeholder: Self {
    .init(
      read: unimplemented(),
      write: unimplemented()
    )
  }

  public static func constant(
    _ value: Value
  ) -> Self {
    .init(
      read: { value },
      write: { _ in }
    )
  }
  #endif

  public nonisolated let objectDidChange: ObservableObjectPublisher
  public nonisolated let cancellables: Cancellables
  private let read: @MainActor () -> Value
  private let write: @MainActor (Value) -> Void

  public nonisolated convenience init(
    initial: Value
  ) {
    var value: Value = initial
    self.init(
      read: { value },
      write: { (newValue: Value) in
        value = newValue
      }
    )
  }

  private nonisolated init(
    read: @escaping @MainActor () -> Value,
    write: @escaping @MainActor (Value) -> Void
  ) {
    self.read = read
    self.write = write
    self.objectDidChange = .init()
    self.cancellables = .init()
  }

  public var wrappedValue: Value {
    get { self.read() }
    set {
      guard self.read() != newValue else { return }
      self.objectWillChange.send()
      self.write(newValue)
      self.objectDidChange.send()
    }
  }

  public var projectedValue: Binding<Value> {
    .init(
      get: { self.wrappedValue },
      set: { (newValue: Value) in
        self.wrappedValue = newValue
      }
    )
  }

  public subscript<Property>(
    dynamicMember keyPath: KeyPath<Value, Property>
  ) -> Property {
    get {
      self.wrappedValue[keyPath: keyPath]
    }
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
}

extension ViewStateBinding: Hashable {

  public nonisolated static func == (
    _ lhs: ViewStateBinding,
    _ rhs: ViewStateBinding
  ) -> Bool {
    lhs === rhs
  }

  public nonisolated func hash(
    into hasher: inout Hasher
  ) {
    hasher.combine(ObjectIdentifier(self))
  }
}

extension ViewStateBinding {

  public func mutate<Property>(
    _ access: (inout Value) throws -> Property
  ) rethrows -> Property {
    var copy: Value = self.wrappedValue
    defer { self.wrappedValue = copy }
    return try access(&copy)
  }

  @MainActor public func binding<Binded>(
    to keyPath: WritableKeyPath<Value, Binded>
  ) -> Binding<Binded> {
    .init(
      get: { self.wrappedValue[keyPath: keyPath] },
      set: { (newValue: Binded) in
        self.wrappedValue[keyPath: keyPath] = newValue
      }
    )
  }
}

extension ViewStateBinding
where Value == Never {

  public nonisolated convenience init() {
    self.init(
      read: { unreachable("Cannot read from Never") },
      write: { (_: Value) in
        unreachable("Cannot write to Never")
      }
    )
  }
}

extension ViewStateBinding {

  public nonisolated func view<State>(
    at keyPath: KeyPath<Value, State>
  ) -> ViewStateView<State> {
    .init(
      from: self,
      at: keyPath
    )
  }
}

extension ViewStateBinding {

  public nonisolated func valuesPublisher() -> some Combine.Publisher<Value, Never> {
    self.objectDidChange
      .compactMap { [weak self] in
        self
      }
      .asyncMap { (binding: ViewStateBinding) in
        await binding.wrappedValue
      }
  }
}
