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

import SwiftUI

@MainActor
public final class ViewStateView<Value>: ObservableObject
where Value: Hashable {

#if DEBUG
  public nonisolated static var placeholder: Self {
    .init(
      read: unimplemented(),
      objectWillChange: .init(),
      objectDidChange: .init()
    )
  }

  public static func constant(
    _ value: Value
  ) -> Self {
    .init(
      read: { value },
      objectWillChange: .init(),
      objectDidChange: .init()
    )
  }
#endif

  public nonisolated let cancellables: Cancellables
  public nonisolated let objectWillChange: ObservableObjectPublisher
  public nonisolated let objectDidChange: ObservableObjectPublisher
  private let read: @MainActor () -> Value

  public nonisolated convenience init<BindingValue>(
    from binding: ViewStateBinding<BindingValue>,
    at keyPath: KeyPath<BindingValue, Value>
  ) {
    self.init(
      read: { binding[dynamicMember: keyPath] },
      objectWillChange: binding.objectWillChange,
      objectDidChange: binding.objectDidChange
    )
  }

  public nonisolated convenience init<ViewValue>(
    from view: ViewStateView<ViewValue>,
    at keyPath: KeyPath<ViewValue, Value>
  ) {
    self.init(
      read: { view[dynamicMember: keyPath] },
      objectWillChange: view.objectWillChange,
      objectDidChange: view.objectDidChange
    )
  }

  private nonisolated init(
    read: @escaping @MainActor () -> Value,
    objectWillChange: ObservableObjectPublisher,
    objectDidChange: ObservableObjectPublisher
  ) {
    self.read = read
    self.objectWillChange = objectWillChange
    self.objectDidChange = objectDidChange
    self.cancellables = .init()
  }

  public var wrappedValue: Value {
    self.read()
  }

  public subscript<Property>(
    dynamicMember keyPath: KeyPath<Value, Property>
  ) -> Property {
    get {
      self.wrappedValue[keyPath: keyPath]
    }
  }
}

extension ViewStateView: Hashable {

  public nonisolated static func == (
    _ lhs: ViewStateView,
    _ rhs: ViewStateView
  ) -> Bool {
    lhs === rhs
  }

  public nonisolated func hash(
    into hasher: inout Hasher
  ) {
    hasher.combine(ObjectIdentifier(self))
  }
}

extension ViewStateView
where Value == Never {

  public nonisolated convenience init(
    cleanup: @escaping @Sendable () -> Void = {}
  ) {
    self.init(
      read: { unreachable("Cannot read from Never") },
      objectWillChange: .init(),
      objectDidChange: .init()
    )
  }
}

extension ViewStateView {

  public nonisolated func view<State>(
    at keyPath: KeyPath<Value, State>
  ) -> ViewStateView<State> {
    .init(
      from: self,
      at: keyPath
    )
  }

  public nonisolated func map<Mapped>(
    _ mapping: @escaping @Sendable (Value) -> Mapped
  ) -> ViewStateView<Mapped> {
    .init(
      read: { mapping(self.wrappedValue) },
      objectWillChange: self.objectWillChange,
      objectDidChange: self.objectDidChange
    )
  }

  public nonisolated func valuesPublisher() -> some Combine.Publisher<Value, Never> {
    self.objectDidChange
      .compactMap { [weak self] in
        self
      }
      .asyncMap { (view: ViewStateView) in
        await view.wrappedValue
      }
  }
}
