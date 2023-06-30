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

public final class UpdatableViewState<ViewState>: @unchecked Sendable, ViewStateSource
where ViewState: Sendable & Equatable {

  // It seems that there is some bug in swift 5.8 compiler,
  // typealiases below are already defined but it does not compile without it
  public typealias DataType = ViewState
  public typealias Failure = Never

  public var updates: Updates
  @MainActor public private(set) var state: ViewState

  private let stateUpdates: UpdatesSource
  @MainActor private var sourceUpdates: Updates
  private let computeUpdate: (ViewState) async -> ViewState
  private var runningUpdate: Task<ViewState, Never>?

  public init(
    initial: ViewState,
    updateUsing updates: Updates,
    update: @escaping @MainActor (inout ViewState) async throws -> Void,
    fallback: @escaping @MainActor (inout ViewState, Error) async -> Void = { _, _ in }
  ) {
    self.state = initial
    self.stateUpdates = .init()
    self.updates = .init(
      combined: updates,
      with: self.stateUpdates.updates
    )
    self.sourceUpdates = updates
    self.computeUpdate = { (state: ViewState) async -> ViewState in
      await withLogCatch(
        fallback: { (error: Error) -> ViewState in
          var state: ViewState = state
          await fallback(&state, error)
          return state
        }
      ) { () async throws -> ViewState in
        var state: ViewState = state
        try await update(&state)
        return state
      }
    }
  }

  public init<Source>(
    initial: ViewState,
    updateFrom source: Source,
    update: @escaping @MainActor (inout ViewState, Source.DataType) async throws -> Void,
    fallback: @escaping @MainActor (inout ViewState, Error) async -> Void = { _, _ in }
  ) where Source: DataSource {
    self.state = initial
    self.stateUpdates = .init()
    self.updates = .init(
      combined: source.updates,
      with: self.stateUpdates.updates
    )
    self.sourceUpdates = source.updates
    self.computeUpdate = { (state: ViewState) async -> ViewState in
      await withLogCatch(
        fallback: { (error: Error) -> ViewState in
          var state: ViewState = state
          await fallback(&state, error)
          return state
        }
      ) { () async throws -> ViewState in
        var state: ViewState = state
        try await update(&state, source.value)
        return state
      }
    }
  }

  deinit {
    self.runningUpdate?.cancel()
  }
}

extension UpdatableViewState {

  @MainActor public func binding<Value>(
    to keyPath: WritableKeyPath<ViewState, Value>
  ) -> Binding<Value> {
    Binding<Value>(
      get: { self.state[keyPath: keyPath] },
      set: { (newValue: Value) in
        self.state[keyPath: keyPath] = newValue
      }
    )
  }

  @MainActor public func binding<Value>(
    to keyPath: KeyPath<ViewState, Value>,
    update: @escaping @MainActor (Value) -> Void
  ) -> Binding<Value> {
    Binding<Value>(
      get: { self.state[keyPath: keyPath] },
      set: { (newValue: Value) in
        update(newValue)
      }
    )
  }

  @MainActor public func updateIfNeeded() async {
    let state: ViewState = await runningUpdate?.value ?? self.state
    guard self.sourceUpdates.checkUpdate() else { return }
    let update: Task<ViewState, Never> = .init {
      await self.computeUpdate(state)
    }
    self.runningUpdate = update
    self.state = await update.value
    self.runningUpdate = .none
  }

  @MainActor public func update(
    _ mutation: @escaping @MainActor (inout ViewState) -> Void
  ) async {
    let state: ViewState = await runningUpdate?.value ?? self.state
    // set source generation, it will be force updated from source now
    self.sourceUpdates.generation = clock_gettime_nsec_np(CLOCK_MONOTONIC_RAW)
    let update: Task<ViewState, Never> = .init {
      var updated: ViewState = state
      mutation(&updated)
      return await self.computeUpdate(updated)
    }
    self.runningUpdate = update
    self.state = await update.value
    self.runningUpdate = .none
    self.stateUpdates.sendUpdate()
  }

  @MainActor public func update<Property>(
    _ keyPath: WritableKeyPath<ViewState, Property>,
    to newValue: Property
  ) async {
    await self.update { (state: inout ViewState) in
      state[keyPath: keyPath] = newValue
    }
  }
}
