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

public final class ComputedVariable<DataType>: DataSource
where DataType: Sendable {

	public typealias Failure = Error

	private struct Storage: Sendable {

		fileprivate enum State: Sendable {

			case initial
			case cached(DataType)
			case terminal(Error)
		}

		fileprivate var state: State
		fileprivate var sourceUpdates: Updates
		fileprivate var runningUpdate: Task<Void, Never>?
		fileprivate var awaiters: Dictionary<IID, UnsafeContinuation<DataType, Error>>
	}

	public var updates: Updates { self.updatesSource.updates }

	private let updatesSource: UpdatesSource
	private let computeVariable: @Sendable () async throws -> DataType

	private let storage: CriticalState<Storage>

	public init(
		lazy compute: @escaping @Sendable () async throws -> DataType
	) {
		let lazySource: UpdatesSource = .init()
		self.storage = .init(
			.init(
				state: .initial,
				sourceUpdates: lazySource.updates,
				awaiters: .init()
			)
		)
		self.updatesSource = .init()
		self.computeVariable = {
			defer { lazySource.terminate() }
			return try await compute()
		}
	}

	public init(
		using updates: Updates,
		compute: @escaping @Sendable () async throws -> DataType
	) {
		self.storage = .init(
			.init(
				state: .initial,
				sourceUpdates: updates,
				awaiters: .init()
			)
		)
		self.updatesSource = .init()
		self.computeVariable = compute
	}

	public init<Source>(
		from source: Source,
		transform: @escaping @Sendable (Source.DataType) async throws -> DataType
	) where Source: DataSource {
		self.storage = .init(
			.init(
				state: .initial,
				sourceUpdates: source.updates,
				awaiters: .init()
			)
		)
		self.updatesSource = .init()
		self.computeVariable = { @Sendable [weak source] () async throws -> DataType in
			guard let source else { throw CancellationError() }
			return try await transform(source.value)
		}
	}

	public var value: DataType {
		get async throws {
			let iid: IID = .init()
			return try await withTaskCancellationHandler(
				operation: { () async throws -> DataType in
					try await withUnsafeThrowingContinuation { (continuation: UnsafeContinuation<DataType, Error>) in
						self.storage.access { (storage: inout Storage) in
							guard !Task.isCancelled
							else { return continuation.resume(throwing: CancellationError()) }

							switch storage.state {
							case .cached(let value):
								// there is a risk that between checking update
								// and receiving an update new value occurs in source,
								// it will trigger unnecessary recomputation of current
								// value but should not affect correctness of result
								if storage.sourceUpdates.checkUpdate() {
									storage.awaiters[iid] = continuation
									let runningUpdate: Task<Void, Never>? = storage.runningUpdate
									runningUpdate?.cancel()
									storage.runningUpdate = .detached { [computeVariable, weak self] in
										await runningUpdate?.waitForCompletion()
										do {
											let updated: DataType = try await computeVariable()
											self?.update(with: updated)
										}
										catch is CancellationError where Task.isCancelled {
											// task is cancelled, it will pass cancellation error
											// caused by missing source which is correct behavior
										}
										catch {
											self?.terminate(with: error)
										}
									}
								}
								else if case .some = storage.runningUpdate {
									storage.awaiters[iid] = continuation
								}
								else {
									return continuation.resume(returning: value)
								}

							case .terminal(let error):
								return continuation.resume(throwing: error)

							case .initial:
								storage.awaiters[iid] = continuation
								guard case .none = storage.runningUpdate
								else { return } // already scheduled, just wait
								// there is a risk that between checking update
								// and receiving an update new value occurs in source,
								// it will trigger unnecessary recomputation of current
								// value but should not affect correctness of result
								storage.sourceUpdates.checkUpdate() // called to update current generation
								storage.runningUpdate = .detached { [computeVariable, weak self] in
									do {
										let updated: DataType = try await computeVariable()
										self?.update(with: updated)
									}
									catch is CancellationError where Task.isCancelled {
										// task is cancelled, it will pass cancellation error
										// caused by missing source which is correct behavior
									}
									catch {
										self?.terminate(with: error)
									}
								}
							}
						}
					}
				},
				onCancel: {
					self.storage.exchange(\.awaiters[iid], with: .none)?
						.resume(throwing: CancellationError())
				}
			)
		}
	}

	private func update(
		with value: DataType
	) {
		let deliverUpdate: () -> Void = self.storage.access { (storage: inout Storage) -> () -> Void in
			defer {
				// cleanup running update after receiving value
				if !Task.isCancelled {
					storage.runningUpdate = .none
				} // else NOP
			}
			switch storage.state {
			case .cached, .initial:
				storage.state = .cached(value)

				let awaitersToResume: Dictionary<IID, UnsafeContinuation<DataType, Error>>.Values = storage.awaiters.values
				storage.awaiters.removeAll()

				return { () -> Void in
					self.updatesSource.sendUpdate()
					// we could check if there is any new update and schedule
					// it before notifying awaiters to ensure always latest value
					// on the other hand it could lead to starvation
					for continuation: UnsafeContinuation<DataType, Error> in awaitersToResume {
						continuation.resume(returning: value)
					}
				}

			case .terminal:
				assert(storage.awaiters.isEmpty)
				return {} // can't update terminated
			}
		}

		deliverUpdate()
	}

	private func terminate(
		with error: Error
	) {
		let deliverUpdate: () -> Void = self.storage.access { (storage: inout Storage) -> () -> Void in
			defer {
				// cleanup running update after terminating
				if !Task.isCancelled {
					storage.runningUpdate = .none
				} // else NOP
			}
			switch storage.state {
			case .cached, .initial:
				storage.state = .terminal(error)

				let awaitersToResume: Dictionary<IID, UnsafeContinuation<DataType, Error>>.Values = storage.awaiters.values
				storage.awaiters.removeAll()

				return { () -> Void in
					self.updatesSource.terminate()
					// we could check if there is any new update and schedule
					// it before notifying awaiters to ensure always latest value
					// on the other hand it could lead to starvation
					for continuation: UnsafeContinuation<DataType, Error> in awaitersToResume {
						continuation.resume(throwing: error)
					}
				}

			case .terminal:
				assert(storage.awaiters.isEmpty)
				return {} // can't update terminated
			}
		}

		deliverUpdate()
	}
}
