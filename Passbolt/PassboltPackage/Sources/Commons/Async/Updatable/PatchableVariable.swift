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

public final class PatchableVariable<Value>: @unchecked Sendable
where Value: Sendable {

  @usableFromInline internal typealias DeliverUpdate = @Sendable (Update<Value>) -> Void

  @usableFromInline @inline(__always) internal var lock: UnsafeLock
  @usableFromInline @inline(__always) internal var currentUpdate: Update<Value>
  @usableFromInline @inline(__always) internal var runningUpdate: Task<Void, Never>?
  @usableFromInline @inline(__always) internal var runningPatch: Task<Void, Never>?
  @usableFromInline @inline(__always) internal var deliverUpdate: DeliverUpdate?

  @usableFromInline @inline(__always) internal let sourceGeneration: @Sendable () -> UpdateGeneration?
  @usableFromInline @inline(__always) internal let computeUpdate: @Sendable (Update<Value>) async -> Update<Value>

  public init<SourceValue>(
    updatingFrom source: any Updatable<SourceValue>,
    _ update: @escaping @Sendable (Update<Value>, Update<SourceValue>) async throws -> Value
  ) where SourceValue: Sendable {
    self.lock = .init()
    self.currentUpdate = .uninitialized()
    self.runningUpdate = .none
    self.runningPatch = .none
    self.deliverUpdate = .none
    self.sourceGeneration = { [weak source] () -> UpdateGeneration? in
      source?.generation
    }
    self.computeUpdate = { @Sendable [weak source] (currentUpdate: Update<Value>) async in
      // skip updates if source was deallocated or does not produce update
      guard let sourceUpdate: Update<SourceValue> = try? await source?.update(after: currentUpdate.generation)
			else { return .cancelled() }  // no update to apply

			return await Update<Value>(
				generation: sourceUpdate.generation
			) {
				try await update(currentUpdate, sourceUpdate)
			}
    }
  }

  deinit {
    // cancel running update and patch
    self.runningUpdate?.cancel()
    self.runningPatch?.cancel()
    // resume all waiting to avoid hanging
    self.deliverUpdate?(.cancelled())
  }
}

extension PatchableVariable: Updatable {

  public var generation: UpdateGeneration {
    @_transparent @Sendable _read {
      self.lock.unsafe_lock()
      yield self.sourceGeneration()
        .map { (sourceGeneration: UpdateGeneration) -> UpdateGeneration in
          Swift.max(  // higher between local and source
            self.currentUpdate.generation,
            sourceGeneration
          )
        } ?? .uninitialized  // ignore local if source unavailable
			self.lock.unsafe_unlock()
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

    // check for running patches
    if case .some = self.runningPatch {
      // always wait for the result of running patch
      if let currentDeliver: DeliverUpdate = self.deliverUpdate {
        self.deliverUpdate = { @Sendable (update: Update<Value>) in
          currentDeliver(update)
          awaiter(update)
        }
        self.lock.unsafe_unlock()
      }
      else {
        self.deliverUpdate = awaiter
        self.lock.unsafe_unlock()
      }
    }
    // othewise verify if current is latest and can be used to fulfill immediately
    else if self.currentUpdate.generation >= sourceGeneration, self.currentUpdate.generation > generation {
      let currentUpdate: Update<Value> = self.currentUpdate
      // if current is latest use it
      self.lock.unsafe_unlock()
      // deliver update outside of lock
      return awaiter(currentUpdate)
    }
    // if not and if no update is running request an update
    else if case .none = self.runningUpdate {
      assert(self.deliverUpdate == nil, "No one should wait if there is no update running!")
      self.deliverUpdate = awaiter
      let currentUpdate: Update<Value> = self.currentUpdate
      self.runningUpdate = .detached { [weak self, computeUpdate] in
        await self?.deliver(computeUpdate(currentUpdate))
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
      self.currentUpdate = .cancelled()
      self.runningUpdate.clearIfCurrent()
      let deliverUpdate: DeliverUpdate? = self.deliverUpdate
      self.deliverUpdate = .none
      self.lock.unsafe_unlock()
      // deliver update outside of lock
      deliverUpdate?(update)
      return Void()
    }

		// check if the update is newer than currently stored
		guard update.generation >= self.currentUpdate.generation
		// drop outdated values without any action
		else {
			assert(self.deliverUpdate == nil, "verify - hanging due to cancelled not propagated")
			self.runningUpdate.clearIfCurrent()
			return self.lock.unsafe_unlock()
		}

    // check if update is the latest from source
    if update.generation == sourceGeneration {
      // use the update
      self.currentUpdate = update
      self.runningUpdate.clearIfCurrent()
      let deliverUpdate: DeliverUpdate? = self.deliverUpdate
      self.deliverUpdate = .none
      self.lock.unsafe_unlock()
      // deliver update outside of lock
      deliverUpdate?(update)
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
    // prepare new patch generation
    let patchGeneration: UpdateGeneration = .next()
    self.lock.unsafe_lock()
    // check the source availability
    guard let sourceGeneration: UpdateGeneration = self.sourceGeneration()
    // if source is no longer available drop the update
    else { return self.lock.unsafe_unlock() }

    // drop outdated patches
    guard patchGeneration > sourceGeneration, patchGeneration > self.currentUpdate.generation
    else { return self.lock.unsafe_unlock() }

    // check if any update is running and required
    if let runningUpdate: Task<Void, Never> = self.runningUpdate, self.currentUpdate.generation < sourceGeneration {
      assert(self.runningPatch == nil, "TODO: to verify")
      // if there is update running wait for it and then apply mutation
      let runningPatchUpdate: Task<Void, Never> = .detached { [weak self] in
        await runningUpdate.waitForCompletion()
        let patch: Update<Value>?
        do {
          let currentUpdate: Update<Value>? = {
            guard let self else { return .none }
            self.lock.unsafe_lock()
            defer { self.lock.unsafe_unlock() }
            return self.currentUpdate
          }()
          // can't update if self is no longer available or newer
          guard let currentUpdate, patchGeneration > currentUpdate.generation
          else { return self?.apply(.none) ?? Void() }
          let patchedValue: Value? = try await patchUpdate(currentUpdate)
          patch =
            patchedValue
            .map {
              .init(
                generation: patchGeneration,
                $0
              )
            }
        }
        catch {
          patch = .init(
            generation: patchGeneration,
            error
          )
        }
        self?.apply(patch)
      }
      self.runningPatch = runningPatchUpdate
      self.lock.unsafe_unlock()
      return await runningPatchUpdate.value
    }
    // if no update is running
    else {
      // check if current is up to date and can be used immediately
      if self.currentUpdate.generation >= sourceGeneration {
        // check for other running patches
        if let runningPatch: Task<Void, Never> = self.runningPatch {
          let newPatchUpdate: Task<Void, Never> = .detached { [weak self] in
            await runningPatch.waitForCompletion()
            let patch: Update<Value>?
            do {
              let currentUpdate: Update<Value>? = {
                guard let self else { return .none }
                self.lock.unsafe_lock()
                defer { self.lock.unsafe_unlock() }
                return self.currentUpdate
              }()
              // can't update if self is no longer available or newer
              guard let currentUpdate, patchGeneration > currentUpdate.generation
              else { return self?.apply(.none) ?? Void() }
              let patchedValue: Value? = try await patchUpdate(currentUpdate)
              patch =
                patchedValue
                .map {
                  .init(
                    generation: patchGeneration,
                    $0
                  )
                }
            }
            catch {
              patch = .init(
                generation: patchGeneration,
                error
              )
            }
            self?.apply(patch)
          }
          self.runningPatch = newPatchUpdate
          self.lock.unsafe_unlock()
          return await newPatchUpdate.value
        }
        else {
          // if current is latest run the update
          let runningPatchUpdate: Task<Void, Never> = .detached { [weak self] in
            let patch: Update<Value>?
            do {
              let currentUpdate: Update<Value>? = {
                guard let self else { return .none }
                self.lock.unsafe_lock()
                defer { self.lock.unsafe_unlock() }
                return self.currentUpdate
              }()
              // can't update if self is no longer available or newer
              guard let currentUpdate, patchGeneration > currentUpdate.generation
              else { return self?.apply(.none) ?? Void() }
              let patchedValue: Value? = try await patchUpdate(currentUpdate)
              patch =
                patchedValue
                .map {
                  .init(
                    generation: patchGeneration,
                    $0
                  )
                }
            }
            catch {
              patch = .init(
                generation: patchGeneration,
                error
              )
            }
            self?.apply(patch)
          }
          self.runningPatch = runningPatchUpdate
          self.lock.unsafe_unlock()
          return await runningPatchUpdate.value
        }
      }
      // otherwise request current update first
      else {
        let currentUpdate: Update<Value> = self.currentUpdate
        let sourceUpdate: Task<Void, Never> = .detached { [weak self, computeUpdate] in
          await self?.deliver(computeUpdate(currentUpdate))
        }
        self.runningUpdate = sourceUpdate
        let runningPatchUpdate: Task<Void, Never> = .detached { [weak self] in
          await sourceUpdate.waitForCompletion()
          let patch: Update<Value>?
          do {
            let currentUpdate: Update<Value>? = {
              guard let self else { return .none }
              self.lock.unsafe_lock()
              defer { self.lock.unsafe_unlock() }
              return self.currentUpdate
            }()
            // can't update if self is no longer available or newer
            guard let currentUpdate, patchGeneration > currentUpdate.generation
            else { return self?.apply(.none) ?? Void() }
            let patchedValue: Value? = try await patchUpdate(currentUpdate)
            patch =
              patchedValue
              .map {
                .init(
                  generation: patchGeneration,
                  $0
                )
              }
          }
          catch {
            patch = .init(
              generation: patchGeneration,
              error
            )
          }
          self?.apply(patch)
        }
        self.runningPatch = runningPatchUpdate
        self.lock.unsafe_unlock()
        return await runningPatchUpdate.value
      }
    }
  }

  @Sendable private func apply(
    _ patch: Update<Value>?
  ) {
    self.lock.unsafe_lock()
    guard let patch: Update<Value> = patch, !Task.isCancelled  // skip cancelled patches
    else {
      self.runningPatch.clearIfCurrent()
      // check if shouldn't request an update
      if case .some = self.deliverUpdate, case .none = self.runningUpdate {
        let currentUpdate: Update<Value> = self.currentUpdate
        self.runningUpdate = .detached { [weak self, computeUpdate] in
          await self?.deliver(computeUpdate(currentUpdate))
        }
        return self.lock.unsafe_unlock()
      }
      else {
        return self.lock.unsafe_unlock()
      }
    }
    // check the source availability
    guard let sourceGeneration: UpdateGeneration = self.sourceGeneration()
    // if source is no longer available drop the patch without action
    else {
      self.runningPatch.clearIfCurrent()
      return self.lock.unsafe_unlock()
    }
    // check if the patch is newer than currently stored
    guard patch.generation > self.currentUpdate.generation
    // drop outdated values without action
    else {
      self.runningPatch.clearIfCurrent()
      return self.lock.unsafe_unlock()
    }

    // check if patch is later than source
    if patch.generation > sourceGeneration {
      // use the update if it is
      self.currentUpdate = patch
      self.runningPatch.clearIfCurrent()
      let deliverUpdate: DeliverUpdate? = self.deliverUpdate
      self.deliverUpdate = .none
      self.lock.unsafe_unlock()
      // deliver update outside of lock
      deliverUpdate?(patch)
    }
    // if source has been updated request new update dropping patch
    else if case .none = self.runningUpdate {
      let currentUpdate: Update<Value> =
        patch.generation > self.currentUpdate.generation
        ? patch
        : self.currentUpdate
      self.runningUpdate = .detached { [weak self, computeUpdate] in
        await self?.deliver(computeUpdate(currentUpdate))
      }
      self.lock.unsafe_unlock()
    }
    // if it is already running just drop the patch
    else {
      self.runningPatch.clearIfCurrent()
      self.lock.unsafe_unlock()
    }
  }
}
