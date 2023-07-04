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

@dynamicMemberLookup
public final class Variable<DataValue>: DataSource
where DataValue: Sendable & Equatable {

  public typealias Failure = Never

  public let updates: Updates

  private let updatesSource: UpdatesSource
  private let storage: CriticalState<DataValue>

  public init(
    initial: DataValue
  ) {
    self.storage = .init(initial)
    self.updatesSource = .init()
    self.updates = self.updatesSource.updates
  }

  public var current: DataValue {
    get { self.storage.get() }
    set {
      let oldValue: DataValue = self.storage.exchange(with: newValue)
      guard oldValue != newValue else { return }
      self.updatesSource.sendUpdate()
    }
  }

  public subscript<Value>(
    dynamicMember keyPath: KeyPath<DataValue, Value>
  ) -> Value {
    get { self.current[keyPath: keyPath] }
  }

  public subscript<Value>(
    dynamicMember keyPath: WritableKeyPath<DataValue, Value>
  ) -> Value {
    get { self.current[keyPath: keyPath] }
    set { self.current[keyPath: keyPath] = newValue }
  }

  public func mutate<Returned>(
    _ mutation: (inout DataValue) throws -> Returned
  ) rethrows -> Returned {
    try mutation(&self.current)
  }
}
