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

import struct Foundation.UUID

public final class UpdatesSource: Sendable {

	@usableFromInline internal typealias Generation = UInt64

	@usableFromInline internal struct State: Sendable {

		@usableFromInline internal var generation: Generation?
		@usableFromInline internal var awaiters: Dictionary<IID, UnsafeContinuation<Generation?, Never>>
  }

  @usableFromInline internal let state: CriticalState<State>

	public convenience init() {
		self.init(generation: 1)
	}

	@usableFromInline internal init(
		generation: Generation?
	) {
		// Generation `none` will be ended updates
		// (inactive) from the beginning.
		// Generation starting from 0
		// will wait for the initial update.
    // Generation starting from 1
    // means that sequence will
    // emit initial value without
    // manually triggering update
    // after creating new instance
    self.state = .init(
      .init(
        generation: generation,
        awaiters: .init()
      ),
			cleanup: { (state: State) in
				for continuation: UnsafeContinuation<Generation?, Never> in state.awaiters.values {
					continuation.resume(returning: .none)
        }
      }
    )
  }
}

extension UpdatesSource {

	@_transparent
  public static var placeholder: UpdatesSource {
		UpdatesSource(generation: .none)
  }

	@_transparent @_semantics("constant_evaluable")
	public var updates: Updates { .init(for: self) }

	@_transparent
  @Sendable public func sendUpdate() {
		let resumeAwaiters: () -> Void =
    self.state
      .access { (state: inout State) -> () -> Void in
				if case .some(var generation) = state.generation {
					generation &+= 1
					state.generation = generation
					let awaiters = state.awaiters.values
					state.awaiters.removeAll()
					return {
						for continuation: UnsafeContinuation<Generation?, Never> in awaiters {
							continuation.resume(returning: generation)
						}
					}
				}
				else {
					assert(state.awaiters.isEmpty)
					return {} // generation `none` means terminated, nothing to resume
				}
      }

		resumeAwaiters()
  }

	@_transparent
  @Sendable public func terminate() {
		let resumeAwaiters: () -> Void =
		self.state
			.access { (state: inout State) -> () -> Void in
				if case .some = state.generation {
					state.generation = .none
					let awaiters = state.awaiters.values
					state.awaiters.removeAll()
					return {
						for continuation: UnsafeContinuation<Generation?, Never> in awaiters {
							continuation.resume(returning: .none)
						}
					}
				}
				else {
					assert(state.awaiters.isEmpty)
					return {} // generation `none` means terminated, nothing to resume
				}
			}

		resumeAwaiters()
  }
}

extension UpdatesSource: AsyncSequence {

  public typealias Element = Void

  public struct AsyncIterator: AsyncIteratorProtocol {

		@usableFromInline internal var generation: Generation
    @usableFromInline internal let nextElement: (inout Generation) async -> Void?

    fileprivate init(
			nextElement: @escaping (inout Generation) async -> Void?
    ) {
			self.generation = 0  // make sure all updates are picked
      self.nextElement = nextElement
    }

		@_transparent
    public mutating func next() async -> Element? {
			await self.nextElement(&self.generation)
    }
  }

  public nonisolated func makeAsyncIterator() -> AsyncIterator {
		AsyncIterator { [weak self] (generation: inout Generation) in
			await self?.update(after: &generation)
		}
  }
}

extension UpdatesSource {

	@_transparent @available(*, deprecated, message: "Please use `hasUpdate` instead")
  internal func checkUpdate(
    after generation: Generation
  ) throws -> Generation {
    try self.state.access { (state: inout State) in
      if let current = state.generation, current > generation {
        return current
      }
      else {
        throw NoUpdate.error()
      }
    }
  }
}

extension UpdatesSource {

	@_transparent
	@usableFromInline
	internal func hasUpdate(
		after generation: Generation
	) -> Bool {
		self.state.access { (state: inout State) -> Bool in
			if case .some(let currentGeneration) = state.generation {
				return currentGeneration > generation
			}
			else {
				return false
			}
		}
	}

	@_transparent
	@usableFromInline
  internal func update(
    after generation: inout Generation
  ) async -> Void? {
		let iid: IID = .init()
		let updated: Generation? = await withTaskCancellationHandler(
			operation: { () async -> Generation? in
				await withUnsafeContinuation { (continuation: UnsafeContinuation<Generation?, Never>) in
					self.state.access { (state: inout State) in
						guard case .some(let currentGeneration) = state.generation, !Task.isCancelled
						else { return continuation.resume(returning: .none) }

						if currentGeneration > generation {
							return continuation.resume(returning: currentGeneration)
						}
						else {
							state.awaiters[iid] = continuation
						}
					}
				}
			},
			onCancel: {
				self.state.exchange(\.awaiters[iid], with: .none)?
					.resume(returning: .none)
			}
		)

		if let updated: Generation {
			return generation = updated
		}
		else {
			generation = .max
			return .none
		}
  }
}
