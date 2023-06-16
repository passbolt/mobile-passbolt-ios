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

import SwiftUI

public final class ComputedViewState<ViewState>: ViewStateSource
where ViewState: Sendable {

	public var updates: Updates { self.updatesSource.updates }
	@MainActor public private(set) var state: ViewState {
		willSet {
			self.updatesSource.sendUpdate()
		}
	}

	private let updatesSource: UpdatesSource
	private var updatesTask: Task<Void, Never>?

	public init<State>(
		async compute: @escaping @Sendable () async -> State
	) where ViewState == Optional<State> {
		self.state = .none
		self.updatesSource = .init()
		self.updatesTask = .detached { @MainActor [unowned self] in
			self.state = await compute()
		}
	}

	public init<State>(
		using updates: Updates,
		compute: @escaping @Sendable () async throws -> ViewState,
		failure: @escaping @MainActor (Error) -> ViewState
	) where ViewState == Optional<State> {
		self.state = .none
		self.updatesSource = .init()
		self.updatesTask = .detached { @MainActor [unowned self] in
			do {
				for await _ in updates {
					self.state = try await compute()
				}
			}
			catch {
				self.state = failure(error)
			}
		}
	}

	public init(
		initial: ViewState,
		updateUsing updates: Updates,
		update: @escaping @MainActor (ViewState) async -> ViewState
	) {
		self.state = initial
		self.updatesSource = .init()
		self.updatesTask = .detached { @MainActor [unowned self] in
			for await _ in updates {
				self.state = await update(self.state)
			}
		}
	}

	public init<Source, State>(
		from source: Source,
		transform: @escaping @MainActor (Source.DataType) async throws -> ViewState,
		failure: @escaping @MainActor (Error) -> ViewState
	) where Source: DataSource, ViewState == Optional<State> {
		self.state = .none
		self.updatesSource = .init()
		self.updatesTask = .detached { @MainActor [unowned source] in
			do {
				for await _ in source.updates {
					self.state = try await transform(source.value)
				}
			}
			catch {
				self.state = failure(error)
			}
		}
	}

	@MainActor public init<Source>(
		from source: Source,
		transform: @escaping @MainActor (Source.ViewState) -> ViewState
	) where Source: ViewStateSource {
		self.state = transform(source.state)
		self.updatesSource = .init()
		self.updatesTask = .detached { @MainActor [unowned source] in
			for await _ in source.updates.dropFirst() {
				self.state = transform(source.state)
			}
		}
	}

	deinit {
		self.updatesTask?.cancel()
	}
}

extension ComputedViewState {

	@MainActor public func binding<Value>(
		to keyPath: WritableKeyPath<ViewState, Value>
	) -> Binding<Value> {
		Binding<Value>(
			get: { self.value[keyPath: keyPath] },
			set: { (newValue: Value) in
				Unimplemented
					.error()
					.asAssertionFailure(message: "Can't set through a binding to ComputedViewState")
			}
		)
	}
}
