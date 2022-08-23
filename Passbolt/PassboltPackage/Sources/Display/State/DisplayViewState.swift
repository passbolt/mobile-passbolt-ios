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
      get: unimplemented(),
      set: unimplemented()
    )
  }

  public static func always(
    _ state: State
  ) -> Self {
    .init(
      get: { state },
      set: { _ in /* NOP */ }
    )
  }

  public var get: @Sendable () -> State
  public var set: @Sendable (State) -> Void
  #else
  private let get: @Sendable () -> State
  private let set: @Sendable (State) -> Void
  #endif
  private var cancellable: AnyCancellable?

  private init(
    get: @escaping @Sendable () -> State,
    set: @escaping @Sendable (State) -> Void
  ) {
    self.get = get
    self.set = set
  }

  public nonisolated init(
    initial: State
  ) {
    let updatesSubject: PassthroughSubject<Void, Never> = .init()
    let value: CriticalState<State> = .init(initial)
    self.get = { value.get(\.self) }
    self.set = { @Sendable newValue in
      let updated: Bool = value.access { (state: inout State) in
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
      .sink(receiveValue: self.objectWillChange.send)
  }

  public var wrappedValue: State {
    get { self.get() }
    set { self.set(newValue) }
  }

  public var projectedValue: Binding<State> {
    .init(
      get: self.get,
      set: self.set
    )
  }

  public subscript<Property>(
    dynamicMember keyPath: KeyPath<State, Property>
  ) -> Property {
    get {
      self.wrappedValue[keyPath: keyPath]
    }
  }

  public subscript<Property>(
    dynamicMember keyPath: WritableKeyPath<State, Property>
  ) -> Property {
    get {
      self.wrappedValue[keyPath: keyPath]
    }
    set {
      self.wrappedValue[keyPath: keyPath] = newValue
    }
  }
}

extension DisplayViewState {

  public func set<Property>(
    _ keyPath: WritableKeyPath<State, Property>,
    _ property: Property
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
