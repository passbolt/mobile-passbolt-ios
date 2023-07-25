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

public final class FlattenedVariable<Value>: @unchecked Sendable
where Value: Sendable {

	@usableFromInline internal typealias DeliverUpdate = @Sendable (Update<Value>) -> Void

	@usableFromInline internal struct FlattenedUpdate {

		@usableFromInline internal var update: Update<Value>
		@usableFromInline internal var sourceGeneration: UpdateGeneration
		@usableFromInline internal var source: any Updatable<Value>

		@usableFromInline internal init(
			update: Update<Value>,
			sourceGeneration: UpdateGeneration,
			source: any Updatable<Value>
		) {
			self.update = update
			self.sourceGeneration = sourceGeneration
			self.source = source
		}

		@usableFromInline internal init(
			update: Update<Value>,
			sourceGeneration: UpdateGeneration
		) {
			self.update = update
			self.sourceGeneration = sourceGeneration
			// this can be just optional in iOS 16.0+
			self.source = PlaceholderUpdatable()
		}
	}

	@usableFromInline @inline(__always) internal var lock: UnsafeLock
	@usableFromInline @inline(__always) internal var cachedUpdate: FlattenedUpdate?
	@usableFromInline @inline(__always) internal var runningUpdate: Task<Void, Never>?
	@usableFromInline @inline(__always) internal var deliverUpdate: DeliverUpdate?
	@usableFromInline @inline(__always) internal let sourceGeneration: @Sendable () -> UpdateGeneration?
	@usableFromInline @inline(__always) internal let compute: @Sendable (FlattenedUpdate?) async -> FlattenedUpdate?

	@inline(__always) private init(
		sourceGeneration: @escaping @Sendable () -> UpdateGeneration?,
		cachedUpdate: Update<Value>?,
		compute: @escaping @Sendable (FlattenedUpdate?) async -> FlattenedUpdate?
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

extension FlattenedVariable: Updatable {

	public var generation: UpdateGeneration {
		@_transparent @Sendable _read {
			self.lock.unsafe_lock()
			// check source generation
			if let sourceGeneration: UpdateGeneration = self.sourceGeneration() {
				// if current nested source is the latest combine its generation
				if let lastUpdate: FlattenedUpdate = self.cachedUpdate, lastUpdate.sourceGeneration == sourceGeneration {
					yield Swift.max(
						sourceGeneration,
						lastUpdate.source.generation
					)
				}
				// otherwise use only source generation
				else {
					yield sourceGeneration
				}
			}
			else {
				// if source is unavailable then generation is unavailable
				yield UpdateGeneration.uninitialized
			}
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

		// check the cache availability
		guard let flattenedUpdate: FlattenedUpdate = self.cachedUpdate
		// if there is nothing in cache request update
		else {
			// if no update is running, request a new one
			if case .none = self.runningUpdate {
				assert(self.deliverUpdate == nil, "No one should wait if there is no update running!")
				self.deliverUpdate = awaiter
				self.runningUpdate = .detached { [weak self, compute] in
					await self?.deliver(compute(.none))
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

		// verify if current is latest and can be used to fulfill immediately
		if flattenedUpdate.sourceGeneration == sourceGeneration, flattenedUpdate.update.generation == flattenedUpdate.source.generation, flattenedUpdate.update.generation > generation {
			// if cached is latest use it
			self.lock.unsafe_unlock()
			// deliver update outside of lock
			awaiter(flattenedUpdate.update)
		}
		// otherwise if no update is running request a new one
		else if case .none = self.runningUpdate {
			assert(self.deliverUpdate == nil, "No one should wait if there is no update running!")
			self.deliverUpdate = awaiter
			self.runningUpdate = .detached { [weak self, compute] in
				await self?.deliver(compute(flattenedUpdate))
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
		_ flattenedUpdate: FlattenedUpdate?
	) {
		self.lock.unsafe_lock()
		// check if update was produced and the source availability
		guard let flattenedUpdate: FlattenedUpdate, let sourceGeneration: UpdateGeneration = self.sourceGeneration()
		// if source is no longer available drop the value with cancelled
		// if update was not produced then either source is unavailable
		// or updates are cancelled which leads to end of this variable lifetime
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
		guard flattenedUpdate.update.generation >= self.cachedUpdate?.update.generation ?? .uninitialized
		// drop outdated values without any action
		else {
			assert(self.deliverUpdate == nil, "verify - hanging due to cancelled not propagated")
			self.runningUpdate.clearIfCurrent()
			return self.lock.unsafe_unlock()
		}

		// check if update is the latest from source
		if flattenedUpdate.sourceGeneration == sourceGeneration, (flattenedUpdate.update.generation == flattenedUpdate.source.generation || flattenedUpdate.source.generation == .uninitialized) {
			// use the update
			self.cachedUpdate = flattenedUpdate
			self.runningUpdate.clearIfCurrent()
			let deliverUpdate: DeliverUpdate? = self.deliverUpdate
			self.deliverUpdate = .none
			self.lock.unsafe_unlock()
			// deliver update outside of lock
			deliverUpdate?(flattenedUpdate.update)
		}
		// if source has been updated request a new update dropping received
		else {
			// There is a risk of starvation in frequently updating
			// systems depending on workload and time of update
			// computation, updates more frequent than one per
			// 50 usec (ignoring update time) will likely cause starvation
			self.runningUpdate = .detached { [weak self, compute] in
				await self?.deliver(compute(flattenedUpdate))
			}
			self.lock.unsafe_unlock()
		}
	}
}

extension FlattenedVariable {

	public convenience init<NestedSource>(
		from source: any Updatable<NestedSource>
	) where NestedSource: Updatable, NestedSource.Value == Value {
		self.init(
			sourceGeneration: { [weak source] () -> UpdateGeneration? in
				source?.generation
			},
			cachedUpdate: .none,
			compute: { @Sendable [weak source] (lastUpdate: FlattenedUpdate?) async -> FlattenedUpdate? in
				guard let source else { return .none }
				do {
					let sourceGeneration: UpdateGeneration = source.generation
					// check if last nested source is still the current
					if let lastUpdate: FlattenedUpdate, lastUpdate.sourceGeneration == sourceGeneration {
						// if it has an update use it immediately
						if lastUpdate.source.generation > lastUpdate.update.generation {
							let update: Update<Value> = try await lastUpdate.source.lastUpdate
							return FlattenedUpdate(
								update: update,
								sourceGeneration: sourceGeneration,
								source: lastUpdate.source
							)
						}
						// otherwise wait for update from either source or nested source
						else {
							return try await withThrowingTaskGroup(
								of: FlattenedUpdate.self
							) { (group: inout ThrowingTaskGroup<FlattenedUpdate, Error>) in
								group.addTask {
									let sourceUpdate: Update<NestedSource> = try await source.update(after: lastUpdate.update.generation)
									switch sourceUpdate.content {
									case .value(let nestedSource):
										let update: Update<Value> = try await nestedSource.lastUpdate
										return FlattenedUpdate(
											update: .init(
												generation: Swift.max(
													sourceUpdate.generation,
													// nested can have older generation
													// but overall be a newer when combined
													update.generation
												),
												update.content
											),
											sourceGeneration: sourceUpdate.generation,
											source: nestedSource
										)

									case .issue(let error):
										return FlattenedUpdate(
											update: Update<Value>(
												generation: sourceUpdate.generation,
												error
											),
											sourceGeneration: sourceUpdate.generation
										)
									}
								}
								group.addTask {
									let update: Update<Value> = try await lastUpdate.source.update(after: lastUpdate.update.generation)
									return FlattenedUpdate(
										update: update,
										sourceGeneration: sourceGeneration,
										source: lastUpdate.source
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
					}
					// otherwise request a new nested source
					else {
						let sourceUpdate: Update<NestedSource> = try await source.lastUpdate
						switch sourceUpdate.content {
						case .value(let nestedSource):
							let update: Update<Value> = try await nestedSource.lastUpdate
							return FlattenedUpdate(
								update: .init(
									generation: Swift.max(
										sourceUpdate.generation,
										// nested can have older generation
										// but overall be a newer when combined
										update.generation
									),
									update.content
								),
								sourceGeneration: sourceUpdate.generation,
								source: nestedSource
							)

						case .issue(let error):
							return FlattenedUpdate(
								update: Update<Value>(
									generation: sourceUpdate.generation,
									error
								),
								sourceGeneration: sourceUpdate.generation
							)
						}
					}
				}
				catch is Cancelled {
					return .none
				}
				catch {
					error
						.asTheError()
						.asAssertionFailure(message: "Only Cancelled is expected!")
					return .none
				}
			}
		)
	}

	public convenience init<SourceValue, NestedSource>(
		transformed source: any Updatable<SourceValue>,
		_ transform: @escaping @Sendable (Update<SourceValue>) async throws -> NestedSource
	) where SourceValue: Sendable, NestedSource: Updatable, NestedSource.Value == Value {
		self.init(
			sourceGeneration: { [weak source] () -> UpdateGeneration? in
				source?.generation
			},
			cachedUpdate: .none,
			compute: { @Sendable [weak source] (lastUpdate: FlattenedUpdate?) async -> FlattenedUpdate? in
				guard let source else { return .none }
				do {
					let sourceGeneration: UpdateGeneration = source.generation
					// check if last nested source is still the current
					if let lastUpdate: FlattenedUpdate, lastUpdate.sourceGeneration == sourceGeneration {
						// if it has an update use it immediately
						if lastUpdate.source.generation > lastUpdate.update.generation {
							let update: Update<Value> = try await lastUpdate.source.lastUpdate
							return FlattenedUpdate(
								update: update,
								sourceGeneration: sourceGeneration,
								source: lastUpdate.source
							)
						}
						// otherwise wait for update from either source or nested source
						else {
							return try await withThrowingTaskGroup(
								of: FlattenedUpdate.self
							) { (group: inout ThrowingTaskGroup<FlattenedUpdate, Error>) in
								group.addTask {
									let sourceUpdate: Update<SourceValue> =  try await source.update(after: lastUpdate.update.generation)
									let transformedUpdate: Update<NestedSource>
									do {
										transformedUpdate = try await .init(
											generation: sourceUpdate.generation,
											transform(sourceUpdate)
										)
									}
									catch {
										transformedUpdate = .init(
											generation: sourceUpdate.generation,
											error
										)
									}
									switch transformedUpdate.content {
									case .value(let nestedSource):
										let update: Update<Value> = try await nestedSource.lastUpdate
										return FlattenedUpdate(
											update: .init(
												generation: Swift.max(
													transformedUpdate.generation,
													// nested can have older generation
													// but overall be a newer when combined
													update.generation
												),
												update.content
											),
											sourceGeneration: transformedUpdate.generation,
											source: nestedSource
										)

									case .issue(let error):
										return FlattenedUpdate(
											update: Update<Value>(
												generation: transformedUpdate.generation,
												error
											),
											sourceGeneration: transformedUpdate.generation
										)
									}
								}
								group.addTask {
									let update: Update<Value> = try await lastUpdate.source.update(after: lastUpdate.update.generation)
									return FlattenedUpdate(
										update: update,
										sourceGeneration: sourceGeneration,
										source: lastUpdate.source
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
					}
					// otherwise request a new nested source
					else {
						let sourceUpdate: Update<SourceValue> =  try await source.lastUpdate
						let transformedUpdate: Update<NestedSource>
						do {
							transformedUpdate = try await .init(
								generation: sourceUpdate.generation,
								transform(sourceUpdate)
							)
						}
						catch {
							transformedUpdate = .init(
								generation: sourceUpdate.generation,
								error
							)
						}
						switch transformedUpdate.content {
						case .value(let nestedSource):
							let update: Update<Value> = try await nestedSource.lastUpdate
							return FlattenedUpdate(
								update: .init(
									generation: Swift.max(
										transformedUpdate.generation,
										// nested can have older generation
										// but overall be a newer when combined
										update.generation
									),
									update.content
								),
								sourceGeneration: transformedUpdate.generation,
								source: nestedSource
							)

						case .issue(let error):
							return FlattenedUpdate(
								update: Update<Value>(
									generation: transformedUpdate.generation,
									error
								),
								sourceGeneration: transformedUpdate.generation
							)
						}
					}
				}
				catch is Cancelled {
					return .none
				}
				catch {
					error
						.asTheError()
						.asAssertionFailure(message: "Only Cancelled is expected!")
					return .none
				}
			}
		)
	}
}
