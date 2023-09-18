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

public final class PatchableVariable<Source, Value>: @unchecked Sendable
where Source: Updatable, Value: Sendable {

  @usableFromInline internal typealias Delivery = UpdateDelivery<Value>

  @usableFromInline @inline(__always) internal var lock: UnsafeLock
  @usableFromInline @inline(__always) internal var currentUpdate: Update<Value>
  @usableFromInline @inline(__always) internal var runningUpdate: Task<Void, Never>?
  @usableFromInline @inline(__always) internal var updateDelivery: Delivery?

  @usableFromInline @inline(__always) internal let sourceGeneration: @Sendable () -> UpdateGeneration
  @usableFromInline @inline(__always) internal let computeUpdate: @Sendable (Update<Value>) async -> Update<Value>

  public init(
    updatingFrom source: Source,
    _ update: @escaping @Sendable (Update<Value>, Update<Source.Value>) async throws -> Value
  ) {
    self.lock = .init()
    self.currentUpdate = .uninitialized()
    self.runningUpdate = .none
    self.updateDelivery = .none
    self.sourceGeneration = { [source] () -> UpdateGeneration in
      source.generation
    }
    self.computeUpdate = { @Sendable [source, update] (currentUpdate: Update<Value>) async -> Update<Value> in
      do {
        let sourceUpdate: Update<Source.Value> = try await source.notify(after: currentUpdate.generation)
        return await Update<Value>(
          generation: sourceUpdate.generation
        ) {
          try await update(currentUpdate, sourceUpdate)
        }
      }
      catch {
        assert(error is CancellationError)
        return .cancelled()
      }
    }
  }

  deinit {
    // cancel running update and patch
    self.runningUpdate?.cancel()
    // resume all waiting to avoid hanging
    self.updateDelivery?.deliver(.cancelled())
  }
}

extension PatchableVariable: Updatable {

  public var generation: UpdateGeneration {
    @_transparent @Sendable _read {
      self.lock.unsafe_lock()
      yield Swift.max(  // higher between local and source
        self.currentUpdate.generation,
        self.sourceGeneration()
      )
      self.lock.unsafe_unlock()
    }
  }

  @Sendable public func notify(
    _ awaiter: @escaping @Sendable (Update<Value>) -> Void,
    after generation: UpdateGeneration
  ) {
    self.lock.unsafe_lock()

    // load source generation
    let sourceGeneration: UpdateGeneration = self.sourceGeneration()

    // verify if current is latest and can be used to fulfill immediately
    if self.currentUpdate.generation >= sourceGeneration, self.currentUpdate.generation > generation {
      let currentUpdate: Update<Value> = self.currentUpdate
      // if current is latest use it
      self.lock.unsafe_unlock()
      // deliver update outside of lock
      return awaiter(currentUpdate)
    }
    // if not and if no update is running request an update
    else if case .none = self.runningUpdate {
      assert(self.updateDelivery == nil, "No one should wait if there is no update running!")
      self.updateDelivery = .init(
        awaiter: awaiter,
        next: self.updateDelivery
      )
      let currentUpdate: Update<Value> = self.currentUpdate
      self.runningUpdate = .detached { [weak self, computeUpdate] in
        await self?.deliver(computeUpdate(currentUpdate))
      }
      return self.lock.unsafe_unlock()
    }
    // if update is in progress wait for it
    else {
      self.updateDelivery = .init(
        awaiter: awaiter,
        next: self.updateDelivery
      )
      self.lock.unsafe_unlock()
    }
  }

  @Sendable private func deliver(
    _ update: Update<Value>
  ) {
    self.lock.unsafe_lock()

    // check if the update is newer than currently stored
    guard update.generation >= self.currentUpdate.generation
    // drop outdated values without any action
    else {
      self.runningUpdate = .none
      return self.lock.unsafe_unlock()
    }

    // check if update is the latest from source
    if update.generation == self.sourceGeneration() {
      // use the update
      self.currentUpdate = update
      self.runningUpdate = .none
      let updateDelivery: Delivery? = self.updateDelivery
      self.updateDelivery = .none
      self.lock.unsafe_unlock()
      // deliver update outside of lock
      updateDelivery?.deliver(update)
    }
    // if source has been updated request new update dropping received
    else {
      // There is a risk of starvation in frequently updating
      // systems depending on workload and time of update
      // computation, updates more frequent than one per
      // 50 usec (ignoring update time) will likely cause starvation
      let currentUpdate: Update<Value> = update
      self.runningUpdate = .detached { [weak self, computeUpdate] in
        await self?.deliver(computeUpdate(currentUpdate))
      }
      self.lock.unsafe_unlock()
    }
  }

  @Sendable public func patch(
    _ patchUpdate: @escaping @Sendable (Update<Value>) async throws -> Value?
  ) async {
    // prepare patched value before accessing lock
    let patchGeneration: UpdateGeneration = .next()
    let patchedUpdate: Update<Value>
    do {
      let patched: Value? = try await patchUpdate(self.lastUpdate)
      // if not patch is needed then skip it
      guard let patched: Value else { return }
      patchedUpdate = .init(
        generation: patchGeneration,
        patched
      )
    }
    catch is CancellationError {
      return  // if not patch is needed then skip it
    }
    catch {
      patchedUpdate = .init(
        generation: patchGeneration,
        error
      )
    }

    self.lock.unsafe_lock()

    // load source generation
    let sourceGeneration: UpdateGeneration = self.sourceGeneration()
    // check if patch can be applied
    if patchGeneration > sourceGeneration, patchGeneration > self.currentUpdate.generation {
      self.currentUpdate = patchedUpdate
      let updateDelivery: Delivery? = self.updateDelivery
      self.updateDelivery = .none
      self.lock.unsafe_unlock()
      // deliver update outside of lock
      updateDelivery?.deliver(patchedUpdate)
    }
    // drop outdated patches
    else {
      self.lock.unsafe_unlock()
    }
  }
}
