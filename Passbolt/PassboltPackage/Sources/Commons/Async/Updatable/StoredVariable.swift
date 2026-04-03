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

import class Foundation.NSLock

/// An `Updatable` implementation that delegates storage to external fetch/store closures.
/// Unlike `Variable`, which holds state internally, `StoredVariable` reads from and writes to
/// an external storage backend (e.g., UserDefaults, Keychain, database).
///
/// This is implemented as a thin wrapper around `Variable` that adds storage side effects.
public final class StoredVariable<Value>: @unchecked Sendable
where Value: Sendable {

  private let lock = NSLock()
  private var internalVariable: Variable<Value>?

  public var variable: Variable<Value> {
    lock.lock()
    defer { lock.unlock() }
    if let existing = internalVariable { return existing }
    let newInstance: Variable<Value> = .init(initial: self.fetch())
    internalVariable = newInstance
    return newInstance
  }

  @usableFromInline
  internal private(set) var store: @Sendable (Value) -> Void
  private var fetch: @Sendable () -> Value

  public init(
    fetch: @escaping @Sendable () -> Value,
    store: @escaping @Sendable (Value) -> Void
  ) {
    self.fetch = fetch
    self.store = store
  }
}

extension StoredVariable: Updatable {

  public var generation: UpdateGeneration {
    @_transparent @Sendable _read {
      yield self.variable.generation
    }
  }

  public var value: Value {
    @_transparent _read {
      yield self.variable.value
    }
    @_transparent _modify {
      yield &self.variable.value
      // Store to backend after modification
      self.store(self.variable.value)
    }
  }

  public var lastUpdate: Update<Value> {
    @_transparent @Sendable _read {
      yield self.variable.lastUpdate
    }
  }

  /// Assign tries to update current value,
  /// new value can be ignored if in case of race condition
  /// becomes overriden by newer value.
  @Sendable public func assign(
    _ newValue: Value
  ) {
    self.variable.assign(newValue)
    // Store to backend after assignment
    self.store(newValue)
  }

  /// Update tries to update current value,
  /// new value can be ignored if in case of race condition
  /// becomes overriden by newer value.
  @Sendable public func assign<Assigned>(
    _ updated: Assigned,
    to keyPath: WritableKeyPath<Value, Assigned>
  ) {
    self.variable.assign(updated, to: keyPath)
    // Store to backend after assignment
    self.store(self.variable.value)
  }

  /// Access requests exclusive access to the value memory
  /// allowing to mutate it. Operation always succeeds but
  /// ordering of concurrent mutations is not guaranteed.
  /// Despite of actual mutation it will send and update afterwards.
  @discardableResult
  @Sendable public func mutate<Returned>(
    _ mutation: (inout Value) throws -> Returned
  ) rethrows -> Returned {
    let result = try self.variable.mutate(mutation)
    // Store to backend after mutation
    self.store(self.variable.value)
    return result
  }

  @Sendable public func notify(
    _ awaiter: @escaping @Sendable (Update<Value>) -> Void,
    after generation: UpdateGeneration
  ) {
    self.variable.notify(awaiter, after: generation)
  }
}

extension StoredVariable {

  @Sendable public func convert<ConvertedValue>(
    read: @escaping @Sendable (Value) -> ConvertedValue,
    write: @escaping @Sendable (ConvertedValue) -> Value
  ) -> StoredVariable<ConvertedValue> {
    StoredVariable<ConvertedValue>(
      fetch: { read(self.variable.value) },
      store: { (newValue: ConvertedValue) in
        let originalValue = write(newValue)
        self.assign(originalValue)
      }
    )
  }
}

extension StoredVariable {

  @Sendable public func notifying(
    _ updates: Updates
  ) -> StoredVariable<Value> {
    StoredVariable<Value>(
      fetch: { self.value },
      store: { (newValue: Value) in
        self.assign(newValue)
        updates.update()
      }
    )
  }
}

extension StoredVariable {

  #if DEBUG
  public static var placeholder: Self {
    .init(
      fetch: unimplemented0(),
      store: unimplemented1()
    )
  }
  #endif
}
