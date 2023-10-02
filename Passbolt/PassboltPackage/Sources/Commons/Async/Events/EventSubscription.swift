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

public final class EventSubscription<Description>
where Description: EventDescription {

	@usableFromInline internal let criticalSection: CriticalState<Void>
	@usableFromInline internal let bufferSize: Int
	@usableFromInline internal var buffer: Array<Description.Payload>
	@usableFromInline internal var pendingContinuation: UnsafeContinuation<Description.Payload, Error>?
	private let unsubscribe: @Sendable () -> Void

	@usableFromInline internal init(
		bufferSize: Int,
		unsubscribe: @escaping @Sendable () -> Void
	) {
		precondition(bufferSize > 0, "Buffer can't be empty!")
		self.criticalSection = .init(Void())
		self.bufferSize = bufferSize
		self.buffer = .init()
		self.buffer.reserveCapacity(bufferSize)
		self.pendingContinuation = .none
		self.unsubscribe = unsubscribe
	}

	deinit {
		precondition(self.pendingContinuation == nil)
		self.unsubscribe()
	}
}

extension EventSubscription {

	@_transparent public func nextEvent() async throws -> Description.Payload {
		try await withTaskCancellationHandler(
			operation: {
				try await withUnsafeThrowingContinuation { (continuation: UnsafeContinuation<Description.Payload, Error>) in
					self.criticalSection.access { _ in
						assert(self.pendingContinuation == nil, "Reusing subscriptions is forbidden!")
						if self.buffer.isEmpty {
							self.pendingContinuation = continuation
						}
						else {
							continuation.resume(returning: self.buffer.removeFirst())
						}
					}
				}
			},
			onCancel: {
				self.criticalSection.access { _ in
					self.pendingContinuation?
						.resume(throwing: CancellationError())
					self.pendingContinuation = .none
				}
			}
		)
	}
}

extension EventSubscription {

	@usableFromInline @Sendable internal func deliver(
		_ payload: Description.Payload
	) {
		self.criticalSection.access { _ in
			if let pendingContinuation: UnsafeContinuation<Description.Payload, Error> = self.pendingContinuation {
				assert(self.buffer.isEmpty, "There should be no pending continuation if events are stored in buffer!")
				self.pendingContinuation = .none
				pendingContinuation.resume(returning: payload)
			}
			else if self.bufferSize > self.buffer.count {
				self.buffer.append(payload)
			}
			else {
				self.buffer.removeFirst()
				self.buffer.append(payload)
			}
		}
	}
}

extension EventSubscription: AsyncIteratorProtocol {

	public typealias Element = Description.Payload

	public func next() async throws -> Element? {
		try await self.nextEvent()
	}
}
extension EventSubscription: AsyncSequence {

	public typealias AsyncIterator = EventSubscription

	public func makeAsyncIterator() -> AsyncIterator {
		self
	}
}
