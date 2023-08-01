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

public final class Updates: @unchecked Sendable {

  @usableFromInline internal typealias Delivery = UpdateDelivery<Value>

  @usableFromInline @inline(__always) internal var lock: UnsafeLock
  @usableFromInline @inline(__always) internal var currentUpdate: Update<Void>
  @usableFromInline @inline(__always) internal var updateDelivery: Delivery?

  public init() {
    self.lock = .init()
    self.currentUpdate = .init(generation: .next())
    self.updateDelivery = .none
  }

  deinit {
    // resume all waiting to avoid hanging
    self.updateDelivery?.deliver(.cancelled())
  }
}

extension Updates: Updatable {

  public var generation: UpdateGeneration {
    @_transparent @Sendable _read {
      self.lock.unsafe_lock()
      yield self.currentUpdate.generation
      self.lock.unsafe_unlock()
    }
  }

  public var value: Void {
    @_transparent @Sendable get { Void() }
  }

  public var lastUpdate: Update<Void> {
    @_transparent @Sendable _read {
      self.lock.unsafe_lock()
      yield self.currentUpdate
      self.lock.unsafe_unlock()
    }
  }

  @Sendable public func update() {
    // prepare update befor acquiring lock
    let updateGeneration: UpdateGeneration = .next()
    self.lock.unsafe_lock()
    // check if update is latest
    if updateGeneration > self.currentUpdate.generation {
      let update: Update<Value> = .init(
        generation: updateGeneration
      )
      self.currentUpdate = update
      let delivery: Delivery? = self.updateDelivery
      self.updateDelivery = .none
      self.lock.unsafe_unlock()
      // deliver update outside of lock
      delivery?.deliver(update)
    }
    else {
      // drop old value, newer value was already delivered
      self.lock.unsafe_unlock()
    }
  }

  @Sendable public func notify(
    _ awaiter: @escaping @Sendable (Update<Void>) -> Void,
    after generation: UpdateGeneration
  ) {
    self.lock.unsafe_lock()
    // check if current can be used to fulfill immediately
    if self.currentUpdate.generation > generation {
      let currentUpdate: Update<Void> = self.currentUpdate
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
