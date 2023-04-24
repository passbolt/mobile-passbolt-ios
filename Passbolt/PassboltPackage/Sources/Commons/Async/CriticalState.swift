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

import struct os.os_unfair_lock
import func os.os_unfair_lock_lock
import func os.os_unfair_lock_unlock

public final class CriticalState<State> {

  @usableFromInline internal let statePtr: UnsafeMutablePointer<State>
  @usableFromInline internal let lockPtr: UnsafeMutablePointer<os_unfair_lock>

  private let cleanup: @Sendable (State) -> Void

  public init(
    _ initial: State,
    cleanup: @escaping @Sendable (State) -> Void = { _ in }
  ) {
    assert(
      !(State.self is AnyObject),
      "Only value types are allowed."
    )
    self.statePtr = .allocate(capacity: 1)
    self.statePtr.initialize(to: initial)
    self.lockPtr = .allocate(capacity: 1)
    self.lockPtr.initialize(to: os_unfair_lock())
    self.cleanup = cleanup
  }

  deinit {
    self.cleanup(self.statePtr.pointee)
    self.statePtr.deinitialize(count: 1)
    self.statePtr.deallocate()
    self.lockPtr.deinitialize(count: 1)
    self.lockPtr.deallocate()
  }

  @inlinable @Sendable public func access<Value>(
    _ access: (inout State) throws -> Value
  ) rethrows -> Value {
    os_unfair_lock_lock(self.lockPtr)
    defer { os_unfair_lock_unlock(self.lockPtr) }
    return try access(&self.statePtr.pointee)
  }

  @inlinable @Sendable public func synchronize<Value>(
    _ access: () throws -> Value
  ) rethrows -> Value {
    os_unfair_lock_lock(self.lockPtr)
    defer { os_unfair_lock_unlock(self.lockPtr) }
    return try access()
  }

  @inlinable @Sendable public func get<Value>(
    _ keyPath: KeyPath<State, Value>
  ) -> Value {
    os_unfair_lock_lock(self.lockPtr)
    defer { os_unfair_lock_unlock(self.lockPtr) }
    return self.statePtr.pointee[keyPath: keyPath]
  }

  @inlinable @Sendable public func set<Value>(
    _ keyPath: WritableKeyPath<State, Value>,
    _ newValue: Value
  ) {
    os_unfair_lock_lock(self.lockPtr)
    defer { os_unfair_lock_unlock(self.lockPtr) }
    self.statePtr.pointee[keyPath: keyPath] = newValue
  }

  @inlinable @Sendable public func exchange<Value>(
    _ keyPath: WritableKeyPath<State, Value>,
    with newValue: Value
  ) -> Value {
    os_unfair_lock_lock(self.lockPtr)
    defer { os_unfair_lock_unlock(self.lockPtr) }
    let value: Value = self.statePtr.pointee[keyPath: keyPath]
    self.statePtr.pointee[keyPath: keyPath] = newValue
    return value
  }

  @discardableResult @inlinable @Sendable public func exchange<Value>(
    _ keyPath: WritableKeyPath<State, Value>,
    with newValue: Value,
    when expectedValue: Value
  ) -> Bool
  where Value: Equatable {
    os_unfair_lock_lock(self.lockPtr)
    defer { os_unfair_lock_unlock(self.lockPtr) }
    let value: Value = self.statePtr.pointee[keyPath: keyPath]

    guard value == expectedValue
    else { return false }

    self.statePtr.pointee[keyPath: keyPath] = newValue

    return true
  }
}

extension CriticalState: Sendable where State: Sendable {}
