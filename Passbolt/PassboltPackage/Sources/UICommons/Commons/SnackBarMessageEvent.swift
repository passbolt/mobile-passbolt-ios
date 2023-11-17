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

import Commons

/// SnackBarMessageEvent is an event for presenting
/// a message inside the application. You can send it
/// from any place to display given message on screen.
/// Messages disappear automatically after 3 seconds.
/// You can send `clear` event to manuall dismiss currently visible
/// messages if any (it does not affect pending messages).
/// When multiple events are sent at once (or within
/// 3 second period) the latest will cover the other.
public enum SnackBarMessageEvent: EventDescription {

  public enum Payload: Equatable {
		case show(SnackBarMessage) // show message
		case clear // dismiss currently displayed message
	}

	public nonisolated static let eventList: EventList<SnackBarMessageEvent> = .init()
}

extension SnackBarMessageEvent {

	/// Sending `.none` does not affect display, it is allowed
	/// for convenicnce since CancelledError is removed from
	/// displaying by default (SnackBarMessage produces `.none`
	/// for that error type.
	@Sendable public static func send(
		_ message: SnackBarMessage?
	) {
		guard let message else { return }
		self.send(.show(message))
	}
}

/// Execute provided operation with automatically
/// consumed errors.
@_transparent public func consumingErrors(
	@_implicitSelfCapture _ operation: () throws -> Void
) {
	do {
		try operation()
	}
	catch {
		error.consume()
	}
}

/// Execute provided operation with automatically
/// consumed errors and additional error diagnostics.
@_transparent public func consumingErrors(
	errorDiagnostics: StaticString,
	@_implicitSelfCapture _ operation: () throws -> Void,
	file: StaticString = #fileID,
	line: UInt = #line
) {
	do {
		try operation()
	}
	catch {
		error
			.consume(
				context: errorDiagnostics,
				file: file,
				line: line
			)
	}
}

/// Execute provided operation with automatically
/// consumed errors.
@_disfavoredOverload @_transparent public func consumingErrors(
	@_implicitSelfCapture _ operation: () async throws -> Void
) async {
	do {
		try await operation()
	}
	catch {
		error.consume()
	}
}

/// Execute provided operation with automatically
/// consumed errors and additional error diagnostics.
@_disfavoredOverload @_transparent public func consumingErrors(
	errorDiagnostics: StaticString,
	@_implicitSelfCapture _ operation: () async throws -> Void,
	file: StaticString = #fileID,
	line: UInt = #line
) async {
	do {
		try await operation()
	}
	catch {
		error
			.consume(
				context: errorDiagnostics,
				file: file,
				line: line
			)
	}
}

/// Execute provided operation with automatically
/// consumed errors and fallback action on error.
@_transparent public func consumingErrors<Returned>(
	fallback: () -> Returned,
	@_implicitSelfCapture _ operation: () throws -> Returned
) -> Returned {
	do {
		return try operation()
	}
	catch {
		error.consume()
		return fallback()
	}
}

/// Execute provided operation with automatically
/// consumed errors and fallback action on error.
@_transparent public func consumingErrors<Returned>(
	fallback: () async -> Returned,
	@_implicitSelfCapture _ operation: () async throws -> Returned
) async -> Returned {
	do {
		return try await operation()
	}
	catch {
		error.consume()
		return await fallback()
	}
}

/// Execute provided operation with automatically
/// consumed errors and fallback action on error.
@_transparent public func consumingErrors<Returned>(
	errorDiagnostics: StaticString,
	fallback: () async -> Returned,
	@_implicitSelfCapture _ operation: () async throws -> Returned,
	file: StaticString = #fileID,
	line: UInt = #line
) async -> Returned {
	do {
		return try await operation()
	}
	catch {
		error
			.consume(
				context: errorDiagnostics,
				file: file,
				line: line
			)
		return await fallback()
	}
}

extension Error {

	/// Consume the error by putting it into logs
	/// and displaying on the screen. `consume`
	/// does not modify actual error. It is intended
	/// to be used in a control flow where the error
	/// is no longer passed and becomes handled.
	/// Consuming error is a way to signal that
	/// it was handled properly and should not be
	/// used anymore while making sure that it
	/// will be logged and displayed to the end user.
	@_transparent public func consume() {
		SnackBarMessageEvent.send(.error(self.logged()))
	}

	/// Consume the error by putting it into logs
	/// and displaying on the screen. `consume`
	/// does not modify actual error. It is intended
	/// to be used in a control flow where the error
	/// is no longer passed and becomes handled.
	/// Consuming error is a way to signal that
	/// it was handled properly and should not be
	/// used anymore while making sure that it
	/// will be logged and displayed to the end user.
	@_transparent public func consume(
		context: StaticString,
		file: StaticString = #fileID,
		line: UInt = #line
	) {
		SnackBarMessageEvent.send(
			.error(
				self.asTheError()
					.logged(
						info: .message(
							context,
							file: file,
							line: line
						)
					)
			)
		)
	}

	/// Consume the error by putting it into logs.
	/// `consumeSilently` does not modify actual error.
	/// It is intended to be used in a control flow
	/// where the error is no longer passed and becomes
	/// handled. Consuming error is a way to signal that
	/// it was handled properly and should not be
	/// used anymore while making sure that it
	/// will be logged. `consumeSilently` has the same
	/// intent as `consume` but does not display the error
	/// to the end user.
	@_transparent public func consumeSilently() {
		self.logged()
	}
}
