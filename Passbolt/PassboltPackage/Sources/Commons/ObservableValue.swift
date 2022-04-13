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

import Combine

import class Foundation.RunLoop

@MainActor @dynamicMemberLookup
public final class ObservableValue<Value>: ObservableObject
where Value: Hashable {

  @MainActor public var value: Value {
    get { self.valueGetter() }
    set { self.valueSetter(newValue) }
  }

  public let valuePublisher: AnyPublisher<Value, Never>
  private let valueGetter: () -> Value
  private let valueSetter: (Value) -> Void
  private var cancellable: AnyCancellable?

  private nonisolated init(
    valueGetter: @escaping () -> Value,
    valueSetter: @escaping (Value) -> Void,
    valuePublisher: AnyPublisher<Value, Never>
  ) {
    self.valueGetter = valueGetter
    self.valueSetter = valueSetter
    self.valuePublisher = valuePublisher
    self.cancellable =
      valuePublisher
      .sink { [weak self] _ in
        self?.objectWillChange.send()
      }
  }

  public nonisolated convenience init(
    initial: Value
  ) {
    let updatesSubject: CurrentValueSubject<Value, Never> = .init(initial)
    var value: Value = initial {
      didSet { updatesSubject.send(value) }
    }
    self.init(
      valueGetter: { value },
      valueSetter: { newValue in value = newValue },
      valuePublisher:
        updatesSubject
        // we don't want to refresh screen too often, 60 Hz is enough
        .debounce(for: .seconds(1.0 / 60.0), scheduler: RunLoop.main)
        .removeDuplicates()
        .eraseToAnyPublisher()
    )
  }

  public subscript<Property>(
    dynamicMember keyPath: WritableKeyPath<Value, Property>
  ) -> Property {
    get { self.value[keyPath: keyPath] }
    set { self.value[keyPath: keyPath] = newValue }
  }
}

extension ObservableValue {

  public func scope<Property>(
    _ keyPath: WritableKeyPath<Value, Property>
  ) -> ObservableValue<Property> {
    .init(
      valueGetter: {
        self.value[keyPath: keyPath]
      },
      valueSetter: { newValue in
        self.value[keyPath: keyPath] = newValue
      },
      valuePublisher: self.valuePublisher
        .map(keyPath)
        .removeDuplicates()
        .eraseToAnyPublisher()
    )
  }

  public func withValue(
    _ access: @MainActor (inout Value) -> Void
  ) {
    var value: Value = self.value
    access(&value)
    self.value = value
  }

  public nonisolated func asAnyAsyncSequence() -> AnyAsyncSequence<Value> {
    .init(self.valuePublisher)
  }
}
