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

import libkern

public struct CriticalState<State> {

  @usableFromInline internal let memory: Memory

  public init(
    _ initial: State
  ) {
    self.memory = .init(initial)
  }

  @inlinable public func access<Value>(
    _ access: (inout State) throws -> Value
  ) rethrows -> Value {
    while !atomic_flag_test_and_set(self.memory.flagPtr) {}
    defer { atomic_flag_clear(self.memory.flagPtr) }
    return try access(&self.memory.statePtr.pointee)
  }

  @inlinable public func get<Value>(
    _ keyPath: KeyPath<State, Value>
  ) -> Value {
    while !atomic_flag_test_and_set(self.memory.flagPtr) {}
    defer { atomic_flag_clear(self.memory.flagPtr) }
    return self.memory.statePtr.pointee[keyPath: keyPath]
  }

  @inlinable public func accessAsync<Value>(
    _ access: @escaping (inout State) async throws -> Value
  ) async throws -> Value {
    while !atomic_flag_test_and_set(self.memory.flagPtr) {
      await Task.yield()
      try Task.checkCancellation()
    }
    defer { atomic_flag_clear(self.memory.flagPtr) }
    return try await access(&self.memory.statePtr.pointee)
  }

  @inlinable public func shieldedAccessAsync<Value>(
    _ access: @escaping (inout State) async throws -> Value
  ) async rethrows -> Value {
    while !atomic_flag_test_and_set(self.memory.flagPtr) {
      await Task.yield()
    }
    defer { atomic_flag_clear(self.memory.flagPtr) }
    return try await access(&self.memory.statePtr.pointee)
  }

  @inlinable public func getAsync<Value>(
    _ keyPath: KeyPath<State, Value>
  ) async -> Value {
    while !atomic_flag_test_and_set(self.memory.flagPtr) {
      await Task.yield()
    }
    defer { atomic_flag_clear(self.memory.flagPtr) }
    return self.memory.statePtr.pointee[keyPath: keyPath]
  }
}

extension CriticalState {

  @usableFromInline internal final class Memory {

    @usableFromInline internal let statePtr: UnsafeMutablePointer<State>
    @usableFromInline internal let flagPtr: UnsafeMutablePointer<atomic_flag>

    fileprivate init(
      _ state: State
    ) {
      self.statePtr = .allocate(capacity: 1)
      self.statePtr.initialize(to: state)
      self.flagPtr = .allocate(capacity: 1)
      self.flagPtr.initialize(to: atomic_flag())
    }

    deinit {
      self.statePtr.deinitialize(count: 1)
      self.statePtr.deallocate()
      self.flagPtr.deinitialize(count: 1)
      self.flagPtr.deallocate()
    }
  }
}

extension CriticalState: Sendable where State: Sendable {}
extension CriticalState.Memory: Sendable where State: Sendable {}
