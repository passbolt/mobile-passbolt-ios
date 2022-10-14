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
public final class ViewStateBinding<Value>: ObservableObject
where Value: Equatable {

  #if DEBUG
  public static var placeholder: Self {
    .init(
      stateSource: .placeholder
    )
  }
  #endif

  public let cancellables: Cancellables
  private let stateSource: StateBinding<Value>

  public init(
    stateSource: StateBinding<Value>,
    cleanup: @escaping () -> Void = {}
  ) {
    self.stateSource = stateSource
    self.cancellables = .init()
    self.cancellables.addCleanup(cleanup)
    stateSource
      .receive(on: RunLoop.main)
      .sink { [weak self] _ in
        self?.objectWillChange.send()
      }
      .store(in: cancellables)
  }

  public convenience init(
    initial: Value,
    cleanup: @escaping () async -> Void = {}
  ) {
    self.init(
      stateSource: .variable(initial: initial)
    )
    self.cancellables.addCleanup(cleanup)
  }

  public var wrappedValue: Value {
    get { self.stateSource.get(\.self) }
    set { self.stateSource.set(to: newValue) }
  }

  public var projectedValue: StateBinding<Value> {
    self.stateSource
  }

  public subscript<Property>(
    dynamicMember keyPath: KeyPath<Value, Property>
  ) -> Property {
    get {
      self.stateSource.get(keyPath)
    }
  }

  public subscript<Property>(
    dynamicMember keyPath: WritableKeyPath<Value, Property>
  ) -> Property {
    get {
      self.stateSource.get(keyPath)
    }
    set {
      self.stateSource.set(keyPath, to: newValue)
    }
  }
}

extension ViewStateBinding {

  public func get<Property>(
    _ keyPath: KeyPath<Value, Property>
  ) -> Property {
    self.stateSource.get(keyPath)
  }

  public func set<Property>(
    _ keyPath: WritableKeyPath<Value, Property>,
    to newValue: Property
  ) {
    self.stateSource.set(keyPath, to: newValue)
  }

  public func mutate<Property>(
    _ access: (inout Value) throws -> Property
  ) rethrows -> Property {
    try self.stateSource
      .mutate { (value: inout Value) -> Property in
        try access(&value)
      }
  }

  public func binding<BindingValue>(
    to keyPath: WritableKeyPath<Value, BindingValue>
  ) -> Binding<BindingValue> {
    Binding<BindingValue>(
      get: { self.get(keyPath) },
      set: { (newValue: BindingValue) in
        self.set(keyPath, to: newValue)
      }
    )
  }
}
