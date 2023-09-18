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

public final class Variable<Value>: @unchecked Sendable
where Value: Sendable {

  @usableFromInline internal typealias Delivery = UpdateDelivery<Value>

  @usableFromInline @inline(__always) internal var lock: UnsafeLock
  @usableFromInline @inline(__always) internal var currentUpdate: Update<Value>
  @usableFromInline @inline(__always) internal var updateDelivery: Delivery?

  public init(
    initial: Value
  ) {
    self.lock = .init()
    self.currentUpdate = .init(
      generation: .next(),
      initial
    )
    self.updateDelivery = .none
  }

  deinit {
    // resume all waiting to avoid hanging
    self.updateDelivery?.deliver(.cancelled())
  }
}

extension Variable: Updatable {

  public var generation: UpdateGeneration {
    @_transparent @Sendable _read {
      self.lock.unsafe_lock()
      yield self.currentUpdate.generation
      self.lock.unsafe_unlock()
    }
  }

  public var value: Value {
    @_transparent _read {
      self.lock.unsafe_lock()
      // Variable can't produce errors
      let value: Value = try! self.currentUpdate.value
      yield value
      self.lock.unsafe_unlock()
    }
    @_transparent _modify {
      self.lock.unsafe_lock()
      // Variable can't produce errors
      var newValue: Value = try! self.currentUpdate.value
      yield &newValue
      let update: Update<Value> = .init(
        generation: .next(),
        newValue
      )
      self.currentUpdate = update
      let updateDelivery: Delivery? = self.updateDelivery
      self.updateDelivery = .none
      self.lock.unsafe_unlock()
      // deliver update outside of lock
      updateDelivery?.deliver(update)
    }
  }

  public var lastUpdate: Update<Value> {
    @_transparent @Sendable _read {
      self.lock.unsafe_lock()
      yield self.currentUpdate
      self.lock.unsafe_unlock()
    }
  }

  /// Assign tries to update current value,
  /// new value can be ignored if in case of race condition
  /// becomes overriden by newer value.
  @Sendable public func assign(
    _ newValue: Value
  ) {
    // prepare new update generation
    let updateGeneration: UpdateGeneration = .next()
    self.lock.unsafe_lock()
    // check if the update is latest after acquiring the lock
    if updateGeneration > self.currentUpdate.generation {
      let update: Update<Value> = .init(
        generation: updateGeneration,
        newValue
      )
      self.currentUpdate = update
      let updateDelivery: Delivery? = self.updateDelivery
      self.updateDelivery = .none
      self.lock.unsafe_unlock()
      // deliver update outside of lock
      updateDelivery?.deliver(update)
    }
    else {
      // drop old value, newer value was already delivered
      self.lock.unsafe_unlock()
    }
  }

  /// Update tries to update current value,
  /// new value can be ignored if in case of race condition
  /// becomes overriden by newer value.
  @Sendable public func assign<Assigned>(
    _ updated: Assigned,
    to keyPath: WritableKeyPath<Value, Assigned>
  ) {
    // prepare new update generation
    let updateGeneration: UpdateGeneration = .next()
    self.lock.unsafe_lock()
    // check if the update is latest after acquiring the lock
    if updateGeneration > self.currentUpdate.generation {
      // Variable can't produce errors
      var currentValue: Value = try! self.currentUpdate.value
      currentValue[keyPath: keyPath] = updated
      let update: Update<Value> = .init(
        generation: updateGeneration,
        currentValue
      )
      self.currentUpdate = update
      let updateDelivery: Delivery? = self.updateDelivery
      self.updateDelivery = .none
      self.lock.unsafe_unlock()
      // deliver update outside of lock
      updateDelivery?.deliver(update)
    }
    else {
      // drop old value, newer value was already delivered
      self.lock.unsafe_unlock()
    }
  }

  /// Access requests exclusive access to the value memory
  /// allowing to mutate it. Operation always succeeds but
  /// ordering of concurrent mutations is not guaranteed.
  /// Despite of actual mutation it will send and update afterwards.
  @discardableResult
  @Sendable public func mutate<Returned>(
    _ mutation: (inout Value) throws -> Returned
  ) rethrows -> Returned {
    self.lock.unsafe_lock()
    // Variable can't produce errors, get the current
    var updatedValue: Value = try! self.currentUpdate.value
    // mutate value and prepare result
    let returned: Returned
    do {
      returned = try mutation(&updatedValue)
    }
    catch {
      self.lock.unsafe_unlock()
      throw error
    }
    // prepare new generation update
    let update: Update<Value> = .init(
      generation: .next(),
      updatedValue
    )
    self.currentUpdate = update
    let updateDelivery: Delivery? = self.updateDelivery
    self.updateDelivery = .none
    self.lock.unsafe_unlock()
    // deliver update outside of lock
    updateDelivery?.deliver(update)
    return returned
  }

  @Sendable public func notify(
    _ awaiter: @escaping @Sendable (Update<Value>) -> Void,
    after generation: UpdateGeneration
  ) {
    self.lock.unsafe_lock()
    // check if current value can be used to fulfill immediately
    if self.currentUpdate.generation > generation {
      let currentUpdate: Update<Value> = self.currentUpdate
      self.lock.unsafe_unlock()
      // deliver update outside of lock
      awaiter(currentUpdate)
    }
    // otherwise go to the waiting queue

    else {
      self.updateDelivery = .init(
        awaiter: awaiter,
        next: self.updateDelivery
      )
      self.lock.unsafe_unlock()
    }
  }
}
