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

  @usableFromInline internal typealias DeliverUpdate = @Sendable (Update<Value>) -> Void

  @usableFromInline @inline(__always) internal var lock: UnsafeLock
  @usableFromInline @inline(__always) internal var cachedUpdate: Update<Value>?
  @usableFromInline @inline(__always) internal var runningUpdate: Task<Void, Never>?
  @usableFromInline @inline(__always) internal var deliverUpdate: DeliverUpdate?

  @usableFromInline @inline(__always) internal let sourceGeneration: @Sendable () -> UpdateGeneration?
  @usableFromInline @inline(__always) internal let compute: @Sendable (UpdateGeneration) async -> Update<Value>

  @inline(__always) private init(
    sourceGeneration: @escaping @Sendable () -> UpdateGeneration?,
    cachedUpdate: Update<Value>?,
    compute: @escaping @Sendable (UpdateGeneration) async -> Update<Value>
  ) {
    self.lock = .init()
    self.cachedUpdate = .none
    self.runningUpdate = .none
    self.deliverUpdate = .none
    self.sourceGeneration = sourceGeneration
    self.compute = compute
  }

  deinit {
    // cancel running update
    self.runningUpdate?.cancel()
    // resume all waiting to avoid hanging
    self.deliverUpdate?(.cancelled())
  }
}

extension ComputedVariable: Updatable {

  public var generation: UpdateGeneration {
    @_transparent @Sendable _read {
      yield self.sourceGeneration()  // check source generation only
        ?? .uninitialized  // it is uninitialized if source is unavailable
    }
  }

  @Sendable public func update(
    _ awaiter: @escaping @Sendable (Update<Value>) -> Void,
    after generation: UpdateGeneration
  ) {
    self.lock.unsafe_lock()
    // load source generation - check if source is available
    guard let sourceGeneration: UpdateGeneration = self.sourceGeneration()
    // if the source is no longer available then end cancelled
    else {
      self.lock.unsafe_unlock()
      // deliver update outside of lock
      return awaiter(.cancelled())
    }
    // check the cache availability
    guard let cachedUpdate: Update<Value> = self.cachedUpdate
    // if there is nothing in cache request update
    else {
      // if no update is running, request a new one
      if case .none = self.runningUpdate {
        assert(self.deliverUpdate == nil, "No one should wait if there is no update running!")
        self.deliverUpdate = awaiter
        let generationToUpdate: UpdateGeneration = .uninitialized
        self.runningUpdate = .detached { [weak self, compute] in
          await self?.deliver(compute(generationToUpdate))
        }
        return self.lock.unsafe_unlock()
      }
      // if update is in progress wait for it
      else if let currentDeliver: DeliverUpdate = self.deliverUpdate {
        self.deliverUpdate = { @Sendable(update:Update<Value>) in
          currentDeliver(update)
          awaiter(update)
        }
        return self.lock.unsafe_unlock()
      }
      // just in case of running update without waiting
      else {
        assertionFailure("Update should not be running if no one is waiting!")
        self.deliverUpdate = awaiter
        return self.lock.unsafe_unlock()
      }
    }

    // verify if cached is latest and can be used to fulfill immediately
    if cachedUpdate.generation == sourceGeneration, cachedUpdate.generation > generation {
      // if cached is latest use it
      self.lock.unsafe_unlock()
      // deliver update outside of lock
      awaiter(cachedUpdate)
    }
    // otherwise if no update is running request a new one
    else if case .none = self.runningUpdate {
      assert(self.deliverUpdate == nil, "No one should wait if there is no update running!")
      self.deliverUpdate = awaiter
			let generationToUpdate: UpdateGeneration = cachedUpdate.generation
      self.runningUpdate = .detached { [weak self, compute] in
        await self?.deliver(compute(generationToUpdate))
      }
      return self.lock.unsafe_unlock()
    }
    // if update is in progress wait for it
    else if let currentDeliver: DeliverUpdate = self.deliverUpdate {
      self.deliverUpdate = { @Sendable(update:Update<Value>) in
        currentDeliver(update)
        awaiter(update)
      }
      self.lock.unsafe_unlock()
    }
    else {
      assertionFailure("Update should not be running if no one is waiting!")
      self.deliverUpdate = awaiter
      self.lock.unsafe_unlock()
    }
  }

  @Sendable private func deliver(
    _ update: Update<Value>
  ) {
    self.lock.unsafe_lock()
    // check the source availability
    guard let sourceGeneration: UpdateGeneration = self.sourceGeneration()
    // if source is no longer available drop the value with cancelled
    else {
			self.cachedUpdate = .none
      self.runningUpdate.clearIfCurrent()
      let deliverUpdate: DeliverUpdate? = self.deliverUpdate
      self.deliverUpdate = .none
      self.lock.unsafe_unlock()
      // deliver update outside of lock
			deliverUpdate?(.cancelled())
      return Void()
    }
    // check if the update is newer than currently stored
    guard update.generation >= self.cachedUpdate?.generation ?? .uninitialized
    // drop outdated values without any action
    else {
      assert(self.deliverUpdate == nil, "verify - hanging due to cancelled not propagated")
      self.runningUpdate.clearIfCurrent()
      return self.lock.unsafe_unlock()
    }

    // check if update is the latest from source
    if update.generation == sourceGeneration {
      // use the update
      self.cachedUpdate = update
      self.runningUpdate.clearIfCurrent()
      let deliverUpdate: DeliverUpdate? = self.deliverUpdate
      self.deliverUpdate = .none
      self.lock.unsafe_unlock()
      // deliver update outside of lock
      deliverUpdate?(update)
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

  public convenience init(
    lazy compute: @escaping @Sendable () async throws -> Value
  ) {
    let resolvedGeneration: UpdateGeneration = .next()
    self.init(
      sourceGeneration: { resolvedGeneration },
      cachedUpdate: .none,
      compute: { @Sendable(generation:UpdateGeneration) async -> Update<Value> in
				return await Update<Value>(
					generation: resolvedGeneration
				) {
					try await compute()
				}
      }
    )
  }

  public convenience init<SourceValue>(
    transformed source: any Updatable<SourceValue>,
    _ transform: @escaping @Sendable (Update<SourceValue>) async throws -> Value
  ) where SourceValue: Sendable {
    self.init(
      sourceGeneration: { [weak source] () -> UpdateGeneration? in
        source?.generation
      },
      cachedUpdate: .none,
      compute: { @Sendable [weak source] (generation: UpdateGeneration) async -> Update<Value> in
        guard let source else { return .cancelled() }
        do {
          let sourceUpdate: Update<SourceValue> = try await source.update(after: generation)
					return await Update<Value>(
						generation: sourceUpdate.generation
					) {
						try await transform(sourceUpdate)
					}
        }
        catch is Cancelled {
          return .cancelled()
        }
        catch {
          return Update<Value>(
            generation: .next(),
            error
              .asTheError()
              .asAssertionFailure(message: "Errors shouldn't occur here!")
          )
        }
      }
    )
  }

  public convenience init(
    merged sourceA: any Updatable<Value>,
    with sourceB: any Updatable<Value>
  ) {
    self.init(
      sourceGeneration: { [weak sourceA, weak sourceB] () -> UpdateGeneration? in
        if let sourceA, let sourceB {
          return Swift.max(
            sourceA.generation,
            sourceB.generation
          )
        }
        else {
          return .none
        }
      },
      cachedUpdate: .none,
      compute: { @Sendable [weak sourceA, weak sourceB] (generation: UpdateGeneration) async -> Update<Value> in
        do {
          guard let sourceA, let sourceB
          else { return .cancelled() }
          // race - ask both for the latest
          return try await future { (fulfill: @escaping @Sendable (Update<Value>) -> Void) in
            // request an update from the one with higher generation first
            // since it might be fulfilled immediately and cause a loop
            if sourceA.generation > sourceB.generation {
              sourceA.update(fulfill, after: generation)
              sourceB.update(fulfill, after: generation)
            }
            else {
              sourceB.update(fulfill, after: generation)
              sourceA.update(fulfill, after: generation)
            }
          }
        }
        catch is Cancelled {
          return .cancelled()
        }
        catch {
          return Update<Value>(
            generation: .next(),
            error
              .asTheError()
              .asAssertionFailure(message: "Errors shouldn't occur here!")
          )
        }
      }
    )
  }

  public convenience init<SourceValue>(
    merged sourceA: any Updatable<SourceValue>,
    with sourceB: any Updatable<SourceValue>,
    transform: @escaping @Sendable (Update<SourceValue>) async throws -> Value
  ) where SourceValue: Sendable {
    self.init(
      sourceGeneration: { [weak sourceA, weak sourceB] () -> UpdateGeneration? in
        if let sourceA, let sourceB {
          return Swift.max(
            sourceA.generation,
            sourceB.generation
          )
        }
        else {
          return .none
        }
      },
      cachedUpdate: .none,
      compute: { @Sendable [weak sourceA, weak sourceB] (generation: UpdateGeneration) async -> Update<Value> in
        do {
          guard let sourceA, let sourceB
          else { return .cancelled() }
          // race - ask both for the latest
          let sourceUpdate: Update<SourceValue> = try await future {
            (fulfill: @escaping @Sendable (Update<SourceValue>) -> Void) in
            // request an update from the one with higher generation first
            // since it might be fulfilled immediately and cause a loop
            if sourceA.generation > sourceB.generation {
              sourceA.update(fulfill, after: generation)
              sourceB.update(fulfill, after: generation)
            }
            else {
              sourceB.update(fulfill, after: generation)
              sourceA.update(fulfill, after: generation)
            }
          }

					return await Update<Value>(
						generation: sourceUpdate.generation
					) {
						try await transform(sourceUpdate)
					}
        }
        catch is Cancelled {
          return .cancelled()
        }
        catch {
          return Update<Value>(
            generation: .next(),
            error
              .asTheError()
              .asAssertionFailure(message: "Errors shouldn't occur here!")
          )
        }
      }
    )
  }

  public convenience init<SourceAValue, SourceBValue>(
    combined sourceA: any Updatable<SourceAValue>,
    with sourceB: any Updatable<SourceBValue>,
    combine: @escaping @Sendable ((Update<SourceAValue>, Update<SourceBValue>)) async throws -> Value
  ) where SourceAValue: Sendable, SourceBValue: Sendable {
    self.init(
      sourceGeneration: { [weak sourceA, weak sourceB] () -> UpdateGeneration? in
        if let sourceA, let sourceB {
          return Swift.max(
            sourceA.generation,
            sourceB.generation
          )
        }
        else {
          return .none
        }
      },
      cachedUpdate: .none,
      compute: { @Sendable [weak sourceA, weak sourceB] (generation: UpdateGeneration) async -> Update<Value> in
        guard let sourceA, let sourceB
        else { return .cancelled() }
        do {
          let sourceGeneration: UpdateGeneration = Swift.max(
            sourceA.generation,
            sourceB.generation
          )
          let sourceUpdate:
            (
              left: Update<SourceAValue>,
              right: Update<SourceBValue>
            )
          if sourceGeneration > generation {
            async let sourceAUpdate: Update<SourceAValue> = sourceA.lastUpdate
            async let sourceBUpdate: Update<SourceBValue> = sourceB.lastUpdate
            sourceUpdate = try await (
              left: sourceAUpdate,
              right: sourceBUpdate
            )
          }
          else {
            sourceUpdate = try await withThrowingTaskGroup(
              of: (Update<SourceAValue>, Update<SourceBValue>).self
            ) { (group: inout ThrowingTaskGroup<(Update<SourceAValue>, Update<SourceBValue>), Error>) in
              group.addTask {
                async let sourceAUpdate: Update<SourceAValue> = try await sourceA.update(after: generation)
                async let sourceBUpdate: Update<SourceBValue> = sourceB.lastUpdate
                return try await (
                  left: sourceAUpdate,
                  right: sourceBUpdate
                )
              }
              group.addTask {
                async let sourceBUpdate: Update<SourceBValue> = try await sourceB.update(after: generation)
                async let sourceAUpdate: Update<SourceAValue> = sourceA.lastUpdate
                return try await (
                  left: sourceAUpdate,
                  right: sourceBUpdate
                )
              }
              if let first = try await group.next() {
                group.cancelAll()
                return first
              }
              else if let second = try await group.next() {
                return second
              }
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
        catch is Cancelled {
          return .cancelled()
        }
        catch {
          return Update<Value>(
            generation: .next(),
            error
              .asTheError()
              .asAssertionFailure(message: "Errors shouldn't occur here!")
          )
        }
      }
    )
  }

  public convenience init<SourceAValue, SourceBValue>(
    combined sourceA: any Updatable<SourceAValue>,
    with sourceB: any Updatable<SourceBValue>
  ) where SourceAValue: Sendable, SourceBValue: Sendable, Value == (SourceAValue, SourceBValue) {
    self.init(
      sourceGeneration: { [weak sourceA, weak sourceB] () -> UpdateGeneration? in
        if let sourceA, let sourceB {
          return Swift.max(
            sourceA.generation,
            sourceB.generation
          )
        }
        else {
          return .none
        }
      },
      cachedUpdate: .none,
      compute: { @Sendable [weak sourceA, weak sourceB] (generation: UpdateGeneration) async -> Update<Value> in
        guard let sourceA, let sourceB
        else { return .cancelled() }
        do {
          let sourceGeneration: UpdateGeneration = Swift.max(
            sourceA.generation,
            sourceB.generation
          )
          let sourceUpdate:
            (
              left: Update<SourceAValue>,
              right: Update<SourceBValue>
            )
          if sourceGeneration > generation {
            async let sourceAUpdate: Update<SourceAValue> = sourceA.lastUpdate
            async let sourceBUpdate: Update<SourceBValue> = sourceB.lastUpdate
            sourceUpdate = try await (
              left: sourceAUpdate,
              right: sourceBUpdate
            )
          }
          else {
            sourceUpdate = try await withThrowingTaskGroup(
              of: (Update<SourceAValue>, Update<SourceBValue>).self
            ) { (group: inout ThrowingTaskGroup<(Update<SourceAValue>, Update<SourceBValue>), Error>) in
              group.addTask {
                async let sourceAUpdate: Update<SourceAValue> = try await sourceA.update(after: generation)
                async let sourceBUpdate: Update<SourceBValue> = sourceB.lastUpdate
                return try await (
                  left: sourceAUpdate,
                  right: sourceBUpdate
                )
              }
              group.addTask {
                async let sourceBUpdate: Update<SourceBValue> = try await sourceB.update(after: generation)
                async let sourceAUpdate: Update<SourceAValue> = sourceA.lastUpdate
                return try await (
                  left: sourceAUpdate,
                  right: sourceBUpdate
                )
              }
              if let first = try await group.next() {
                group.cancelAll()
                return first
              }
              else if let second = try await group.next() {
                return second
              }
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
        catch is Cancelled {
          return .cancelled()
        }
        catch {
          return Update<Value>(
            generation: .next(),
            error
              .asTheError()
              .asAssertionFailure(message: "Errors shouldn't occur here!")
          )
        }
      }
    )
  }
}
