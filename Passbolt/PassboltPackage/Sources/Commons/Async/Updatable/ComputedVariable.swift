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

public final class ComputedVariable<Value>: @unchecked Sendable
where Value: Sendable {

  @usableFromInline internal typealias Delivery = UpdateDelivery<Value>

  @usableFromInline @inline(__always) internal var lock: UnsafeLock
  @usableFromInline @inline(__always) internal var cachedUpdate: Update<Value>
  @usableFromInline @inline(__always) internal var runningUpdate: Task<Void, Never>?
  @usableFromInline @inline(__always) internal var updateDelivery: Delivery?

  @usableFromInline @inline(__always) internal let sourceGeneration: @Sendable () -> UpdateGeneration
  @usableFromInline @inline(__always) internal let compute: @Sendable (UpdateGeneration) async -> Update<Value>

  @inline(__always) private init(
    sourceGeneration: @escaping @Sendable () -> UpdateGeneration,
    compute: @escaping @Sendable (UpdateGeneration) async -> Update<Value>
  ) {
    self.lock = .init()
    self.cachedUpdate = .uninitialized()
    self.runningUpdate = .none
    self.updateDelivery = .none
    self.sourceGeneration = sourceGeneration
    self.compute = compute
  }

  deinit {
    // cancel running update
    self.runningUpdate?.cancel()
    // resume all waiting to avoid hanging
    self.updateDelivery?.deliver(.cancelled())
  }
}

extension ComputedVariable: Updatable {

  public var generation: UpdateGeneration {
    @_transparent @Sendable _read {
      yield self.sourceGeneration()
    }
  }

  @Sendable public func notify(
    _ awaiter: @escaping @Sendable (Update<Value>) -> Void,
    after generation: UpdateGeneration
  ) {
    self.lock.unsafe_lock()
    // load source generation
    let sourceGeneration: UpdateGeneration = self.sourceGeneration()

    // verify if cached is latest and can be used to fulfill immediately
    if sourceGeneration > generation, cachedUpdate.generation == sourceGeneration {
      // if cached is latest use it
      self.lock.unsafe_unlock()
      // deliver update outside of lock
      awaiter(cachedUpdate)
    }
    // otherwise if no update is running request a new one
    else if case .none = self.runningUpdate {
      assert(self.updateDelivery == nil, "No one should wait if there is no update running!")
      self.updateDelivery = .init(
        awaiter: awaiter,
        next: self.updateDelivery
      )
      let generationToUpdate: UpdateGeneration = cachedUpdate.generation
      self.runningUpdate = .detached { [weak self, compute] in
        await self?.deliver(compute(generationToUpdate))
      }
      return self.lock.unsafe_unlock()
    }
    // if update is in progress wait for it
    else {
      assert(self.updateDelivery != nil, "Update should not be running if no one is waiting!")
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
    guard update.generation >= self.cachedUpdate.generation
    // drop outdated values without any action
    else {
      self.runningUpdate = .none
      return self.lock.unsafe_unlock()
    }

    // check if update is the latest from source
    if update.generation == self.sourceGeneration() {
      // use the update
      self.cachedUpdate = update
      self.runningUpdate.clearIfCurrent()
      let updateDelivery: Delivery? = self.updateDelivery
      self.updateDelivery = .none
      self.lock.unsafe_unlock()
      // deliver update outside of lock
      updateDelivery?.deliver(update)
    }
    // if source has been updated request a new update dropping received
    else {
      // There is a risk of starvation in frequently updating
      // systems depending on workload and time of update
      // computation, updates more frequent than one per
      // 50 usec (ignoring update time) will likely cause starvation
      let generationToUpdate: UpdateGeneration = update.generation
      self.runningUpdate = .detached { [weak self, compute] in
        await self?.deliver(compute(generationToUpdate))
      }
      self.lock.unsafe_unlock()
    }
  }
}

extension ComputedVariable {

  public func invalidateCache() {
    self.lock.unsafe_lock()
    if case .none = self.runningUpdate {
      self.cachedUpdate = .uninitialized()
      self.lock.unsafe_unlock()
    }
    else {
      // ignore when update is running
      self.lock.unsafe_unlock()
    }
  }
}

extension ComputedVariable {

  public convenience init(
    lazy compute: @escaping @Sendable () async throws -> Value
  ) {
    let resolvedGeneration: UpdateGeneration = .next()
    self.init(
      sourceGeneration: { resolvedGeneration },
      compute: { @Sendable (generation: UpdateGeneration) async -> Update<Value> in
        await Update<Value>(
          generation: resolvedGeneration
        ) {
          try await compute()
        }
      }
    )
  }

  public convenience init<Source>(
    transformed source: Source,
    _ transform: @escaping @Sendable (Update<Source.Value>) async throws -> Value
  ) where Source: Updatable {
    self.init(
      sourceGeneration: { [source] () -> UpdateGeneration in
        source.generation
      },
      compute: { @Sendable [source, transform] (generation: UpdateGeneration) async -> Update<Value> in
        do {
          let sourceUpdate: Update<Source.Value> = try await source.notify(after: generation)
          return await Update<Value>(
            generation: sourceUpdate.generation
          ) {
            try await transform(sourceUpdate)
          }
        }
        catch {
          assert(error is CancellationError)
          return .cancelled()
        }
      }
    )
  }

  public convenience init<SourceA, SourceB>(
    merged sourceA: SourceA,
    with sourceB: SourceB
  )
  where SourceA: Updatable, SourceA.Value == Value, SourceB: Updatable, SourceB.Value == Value {
    self.init(
      sourceGeneration: { [sourceA, sourceB] () -> UpdateGeneration in
        Swift.max(
          sourceA.generation,
          sourceB.generation
        )
      },
      compute: { @Sendable [sourceA, sourceB] (generation: UpdateGeneration) async -> Update<Value> in
        do {
          // race - ask both for the latest
          return try await future { (fulfill: @escaping @Sendable (Update<Value>) -> Void) in
            // request an update from the one with higher generation first
            // since it might be fulfilled immediately and cause a loop
            if sourceA.generation > sourceB.generation {
              sourceA.notify(fulfill, after: generation)
              sourceB.notify(fulfill, after: generation)
            }
            else {
              sourceB.notify(fulfill, after: generation)
              sourceA.notify(fulfill, after: generation)
            }
          }
        }
        catch {
          assert(error is CancellationError)
          return .cancelled()
        }
      }
    )
  }

  public convenience init<SourceA, SourceB>(
    merged sourceA: SourceA,
    with sourceB: SourceB,
    transform: @escaping @Sendable (Update<SourceA.Value>) async throws -> Value
  ) where SourceA: Updatable, SourceB: Updatable, SourceA.Value == SourceB.Value {
    self.init(
      sourceGeneration: { [sourceA, sourceB] () -> UpdateGeneration in
        Swift.max(
          sourceA.generation,
          sourceB.generation
        )
      },
      compute: { @Sendable [sourceA, sourceB, transform] (generation: UpdateGeneration) async -> Update<Value> in
        do {
          // race - ask both for the latest
          let sourceUpdate: Update<SourceA.Value> = try await future {
            (fulfill: @escaping @Sendable (Update<SourceA.Value>) -> Void) in
            // request an update from the one with higher generation first
            // since it might be fulfilled immediately and cause a loop
            if sourceA.generation > sourceB.generation {
              sourceA.notify(fulfill, after: generation)
              sourceB.notify(fulfill, after: generation)
            }
            else {
              sourceB.notify(fulfill, after: generation)
              sourceA.notify(fulfill, after: generation)
            }
          }

          return await Update<Value>(
            generation: sourceUpdate.generation
          ) {
            try await transform(sourceUpdate)
          }
        }
        catch {
          assert(error is CancellationError)
          return .cancelled()
        }
      }
    )
  }

  public convenience init<SourceA, SourceB>(
    combined sourceA: SourceA,
    with sourceB: SourceB,
    combine: @escaping @Sendable ((Update<SourceA.Value>, Update<SourceB.Value>)) async throws -> Value
  ) where SourceA: Updatable, SourceB: Updatable {
    self.init(
      sourceGeneration: { [sourceA, sourceB] () -> UpdateGeneration in
        Swift.max(
          sourceA.generation,
          sourceB.generation
        )
      },
      compute: { @Sendable [sourceA, sourceB, combine] (generation: UpdateGeneration) async -> Update<Value> in
        let sourceUpdate: (left: Update<SourceA.Value>, right: Update<SourceB.Value>)
        let sourceGeneration: UpdateGeneration = Swift.max(
          sourceA.generation,
          sourceB.generation
        )

        do {
          // check if any of sources can be updated immediately
          if sourceGeneration > generation {
            // if so just grab the latest values from both
            async let sourceAUpdate: Update<SourceA.Value> = sourceA.lastUpdate
            async let sourceBUpdate: Update<SourceB.Value> = sourceB.lastUpdate
            sourceUpdate = try await (
              left: sourceAUpdate,
              right: sourceBUpdate
            )
          }
          // otherwise wait with race for the closest update
          else {
            sourceUpdate = try await withThrowingTaskGroup(
              of: (Update<SourceA.Value>, Update<SourceB.Value>).self
            ) { (group: inout ThrowingTaskGroup<(Update<SourceA.Value>, Update<SourceB.Value>), Error>) in
              group.addTask {
                async let sourceAUpdate: Update<SourceA.Value> = try await sourceA.notify(after: generation)
                async let sourceBUpdate: Update<SourceB.Value> = sourceB.lastUpdate
                return try await (
                  left: sourceAUpdate,
                  right: sourceBUpdate
                )
              }
              group.addTask {
                async let sourceBUpdate: Update<SourceB.Value> = try await sourceB.notify(after: generation)
                async let sourceAUpdate: Update<SourceA.Value> = sourceA.lastUpdate
                return try await (
                  left: sourceAUpdate,
                  right: sourceBUpdate
                )
              }

              // first finished wins
              if let first = try await group.next() {
                group.cancelAll()
                return first
              }
              // should not happen but just in case cancel otherwise
              else {
                throw Cancelled.error()
              }
            }
          }

          return await Update<Value>(
            generation: Swift.max(
              sourceUpdate.left.generation,
              sourceUpdate.right.generation
            )
          ) {
            try await combine(sourceUpdate)
          }
        }
        catch {
          assert(error is CancellationError)
          return .cancelled()
        }
      }
    )
  }

  public convenience init<SourceA, SourceB>(
    combined sourceA: SourceA,
    with sourceB: SourceB
  ) where SourceA: Updatable, SourceB: Updatable, Value == (SourceA.Value, SourceB.Value) {
    self.init(
      sourceGeneration: { [sourceA, sourceB] () -> UpdateGeneration in
        Swift.max(
          sourceA.generation,
          sourceB.generation
        )
      },
      compute: { @Sendable [sourceA, sourceB] (generation: UpdateGeneration) async -> Update<Value> in
        let sourceUpdate: (left: Update<SourceA.Value>, right: Update<SourceB.Value>)
        let sourceGeneration: UpdateGeneration = Swift.max(
          sourceA.generation,
          sourceB.generation
        )

        do {
          // check if any of sources can be updated immediately
          if sourceGeneration > generation {
            // if so just grab the latest values from both
            async let sourceAUpdate: Update<SourceA.Value> = sourceA.lastUpdate
            async let sourceBUpdate: Update<SourceB.Value> = sourceB.lastUpdate
            sourceUpdate = try await (
              left: sourceAUpdate,
              right: sourceBUpdate
            )
          }
          // otherwise wait with race for the closest update
          else {
            sourceUpdate = try await withThrowingTaskGroup(
              of: (Update<SourceA.Value>, Update<SourceB.Value>).self
            ) { (group: inout ThrowingTaskGroup<(Update<SourceA.Value>, Update<SourceB.Value>), Error>) in
              group.addTask {
                async let sourceAUpdate: Update<SourceA.Value> = try await sourceA.notify(after: generation)
                async let sourceBUpdate: Update<SourceB.Value> = sourceB.lastUpdate
                return try await (
                  left: sourceAUpdate,
                  right: sourceBUpdate
                )
              }
              group.addTask {
                async let sourceBUpdate: Update<SourceB.Value> = try await sourceB.notify(after: generation)
                async let sourceAUpdate: Update<SourceA.Value> = sourceA.lastUpdate
                return try await (
                  left: sourceAUpdate,
                  right: sourceBUpdate
                )
              }

              // first finished wins
              if let first = try await group.next() {
                group.cancelAll()
                return first
              }
              // should not happen but just in case cancel otherwise
              else {
                throw Cancelled.error()
              }
            }
          }

          return Update<Value>(
            generation: Swift.max(
              sourceUpdate.left.generation,
              sourceUpdate.right.generation
            )
          ) {
            try (
              left: sourceUpdate.left.value,
              right: sourceUpdate.right.value
            )
          }
        }
        catch {
          assert(error is CancellationError)
          return .cancelled()
        }
      }
    )
  }
}
