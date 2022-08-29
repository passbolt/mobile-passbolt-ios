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

import class Combine.PassthroughSubject
import class Foundation.RunLoop

@propertyWrapper @dynamicMemberLookup
public final class DisplayViewState<State>: ObservableObject
where State: Hashable {

  #if DEBUG
  public static var placeholder: Self {
    .init(
      read: unimplemented(),
      write: unimplemented()
    )
  }

  public static func always(
    _ state: State
  ) -> Self {
    .init(
      read: { state },
      write: { _ in /* NOP */ }
    )
  }

  public var read: @Sendable () -> State
  public var write: @Sendable (State) -> Void
  #else
  private let read: @Sendable () -> State
  private let write: @Sendable (State) -> Void
  #endif
  private var cancellable: AnyCancellable?

  private init(
    read: @escaping @Sendable () -> State,
    write: @escaping @Sendable (State) -> Void
  ) {
    self.read = read
    self.write = write
  }

  public nonisolated init(
    initial: State
  ) {
    let updatesSubject: PassthroughSubject<Void, Never> = .init()
    let value: CriticalState<State> = .init(initial)
    self.read = { value.get(\.self) }
    self.write = { @Sendable (newValue: State) in
      let updated: Bool = value.access { (state: inout State) -> Bool in
        if newValue == state {
          return false
        }
        else {
          state = newValue
          return true
        }
      }
      // remove duplicates
      guard updated else { return }
      updatesSubject.send()
    }
    self.cancellable =
      updatesSubject
      .receive(on: RunLoop.main)
      .sink { [weak self] in
        self?.objectWillChange.send()
      }
  }

  public var wrappedValue: State {
    get { self.read() }
    set { self.write(newValue) }
  }

  public var projectedValue: ValueBinding<State> {
    .init(
      get: self.read,
      set: self.write
    )
  }

  @_disfavoredOverload
  public func binding<Value>(
    to keyPath: WritableKeyPath<State, Value>
  ) -> ValueBinding<Value> {
    .init(
      get: { self.get(keyPath) },
      set: { newValue in
        self.set(keyPath, newValue)
      }
    )
  }

  public func binding<Value>(
    to keyPath: WritableKeyPath<State, ValueBinding<Value>>
  ) -> ValueBinding<Value> {
    self.get(keyPath)
  }

  public func associate<Value>(
    binding: ValueBinding<Value>,
    with keyPath: WritableKeyPath<State, Value>
  ) {
    binding.onSet { [weak self] (value: Value) in
      self?.wrappedValue[keyPath: keyPath] = value
    }
  }

  public subscript<Value>(
    dynamicMember keyPath: KeyPath<State, Value>
  ) -> Value {
    get {
      self.wrappedValue[keyPath: keyPath]
    }
  }

  public subscript<Value>(
    dynamicMember keyPath: WritableKeyPath<State, Value>
  ) -> Value {
    get {
      self.wrappedValue[keyPath: keyPath]
    }
    set {
      self.wrappedValue[keyPath: keyPath] = newValue
    }
  }
}

extension DisplayViewState {

  public func get<Value>(
    _ keyPath: KeyPath<State, Value>
  ) -> Value {
    self.wrappedValue[keyPath: keyPath]
  }

  public func set<Value>(
    _ keyPath: WritableKeyPath<State, Value>,
    _ property: Value
  ) {
    self.wrappedValue[keyPath: keyPath] = property
  }

  public func with<Value>(
    _ access: (inout State) throws -> Value
  ) rethrows -> Value {
    try access(&self.wrappedValue)
  }
}

extension DisplayViewState: Hashable {

  public static func == (
    _ lhs: DisplayViewState,
    _ rhs: DisplayViewState
  ) -> Bool {
    // relaying on object reference equality
    lhs === rhs
  }

  public func hash(
    into hasher: inout Hasher
  ) {
    // relaying on object reference
    hasher.combine(ObjectIdentifier(self))
  }
}
