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

public protocol EventDescription: Sendable {

	associatedtype Payload: Sendable = Void

	static nonisolated var eventList: EventList<Self> { @Sendable get }
}

extension EventDescription {

	public typealias Subscription = EventSubscription<Self>

	@_transparent @Sendable public nonisolated static func send(
		_ payload: consuming Self.Payload
	) {
		Self.eventList.sendEvent(payload: payload)
	}

	@_transparent @Sendable public nonisolated static func send()
	where Payload == Void {
		Self.eventList.sendEvent(payload: Void())
	}

	@_transparent @Sendable public nonisolated static func next() async throws -> Self.Payload {
		try await Self.eventList.nextEvent()
	}

	@_transparent @Sendable public nonisolated static func subscribe(
		bufferSize: UInt = 1
	) -> EventSubscription<Self> {
		Self.eventList.subscribe()
	}

	@_transparent @Sendable public nonisolated static func subscribe(
		_ handler: @escaping @Sendable (Self.Payload) async -> Void
	) async throws {
		var subscription: EventSubscription<Self> = Self.eventList.subscribe()
		while true {
			try Task.checkCancellation()
			try await handler(subscription.nextEvent())
		}
	}
}
