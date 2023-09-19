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

public struct EventList<Description>
where Description: EventDescription {

	@usableFromInline internal typealias Subscription = @Sendable (Description.Payload) -> Void

	@usableFromInline internal let subscriptions: CriticalState<Dictionary<IID, Subscription>>

	public init() {
		self.subscriptions = .init(.init())
	}
}

extension EventList: Sendable {}

extension EventList {

	@_transparent @usableFromInline internal func sendEvent(
		payload: consuming Description.Payload
	) {
		for subscription: Subscription in self.subscriptions.get(\.values) {
			subscription(payload)
		}
	}

	@_transparent @usableFromInline internal func nextEvent() async throws -> Description.Payload {
		try await future { (fulfill: @escaping (Result<Description.Payload, Error>) -> Void) in
			let id: IID = .init()
			self.subscriptions.set(
				\.[id],
				{ @Sendable [self, fulfill] (eventPayload: Description.Payload) in
					self.unsubscribe(id)
					fulfill(.success(eventPayload))
				}
			)
		}
	}

	@_transparent @usableFromInline internal func subscribe(
		bufferSize: Int
	) -> EventSubscription<Description> {
		let id: IID = .init()
		let subscription: EventSubscription<Description> = .init(
			bufferSize: bufferSize,
			unsubscribe: { [self] in
				self.unsubscribe(id)
			}
		)
		self.subscriptions.set(
			\.[id],
			 { @Sendable (eventPayload: Description.Payload) in
				 subscription.deliver(eventPayload)
			 }
		)
		return subscription
	}

	@_transparent @usableFromInline internal func unsubscribe(
		_ id: IID
	) {
		self.subscriptions.set(
			\.[id],
			 .none
		)
	}
}
