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

public final class ComputedViewState<ViewState>: @unchecked Sendable, ViewStateSource
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

  public init<State>(
    async compute: @escaping @Sendable () async -> State
  ) where ViewState == Optional<State> {
    self.state = .none
    self.stateUpdates = .init()
    self.updates = self.stateUpdates.updates
    self.sourceUpdates = .never
    self.computeUpdate = { [stateUpdates] (_: ViewState) async -> ViewState in
      defer {
        stateUpdates.sendUpdate()
        stateUpdates.terminate()
      }
      return await compute()
    }
  }

  public init<State>(
    using updates: Updates,
    compute: @escaping @Sendable () async throws -> ViewState,
    failure: @escaping @MainActor (Error) -> ViewState
  ) where ViewState == Optional<State> {
    self.state = .none
    self.stateUpdates = .init()
    self.updates = .init(
      combined: updates,
      with: self.stateUpdates.updates
    )
    self.sourceUpdates = updates
    self.computeUpdate = { (_: ViewState) async -> ViewState in
      await withLogCatch(
        fallback: failure
      ) {
        try await compute()
      }
    }
  }

  public init(
    initial: ViewState,
    updateUsing updates: Updates,
    update: @escaping @MainActor (inout ViewState) async -> Void
  ) {
    self.state = initial
    self.stateUpdates = .init()
    self.updates = .init(
      combined: updates,
      with: self.stateUpdates.updates
    )
    self.sourceUpdates = updates
    self.computeUpdate = { (state: ViewState) async -> ViewState in
      var state: ViewState = state
      await update(&state)
      return state
    }
  }

  public init<Source, State>(
    from source: Source,
    transform: @escaping @MainActor (Source.DataType) async throws -> ViewState,
    failure: @escaping @MainActor (Error) -> ViewState
  ) where Source: DataSource, ViewState == Optional<State> {
    self.state = .none
    self.stateUpdates = .init()
    self.updates = .init(
      combined: source.updates,
      with: self.stateUpdates.updates
    )
    self.sourceUpdates = source.updates
    self.computeUpdate = { (_: ViewState) async -> ViewState in
      await withLogCatch(
        fallback: failure
      ) {
        try await transform(source.value)
      }
    }
  }

  public init<Source, State>(
    from source: Source,
    transform: @escaping @MainActor (Source.DataType) async -> ViewState
  ) where Source: DataSource, Source.Failure == Never, ViewState == Optional<State> {
    self.state = .none
    self.stateUpdates = .init()
    self.updates = .init(
      combined: source.updates,
      with: self.stateUpdates.updates
    )
    self.sourceUpdates = source.updates
    self.computeUpdate = { (state: ViewState) async -> ViewState in
      // source value can't throw here
      (try? await transform(source.value)) ?? state
    }
  }

  public init<Source>(
    initial: ViewState,
    from source: Source,
    transform: @escaping @MainActor (Source.DataType) async throws -> ViewState,
    failure: @escaping @MainActor (Error) async -> ViewState
  ) where Source: DataSource {
    self.state = initial
    self.stateUpdates = .init()
    self.updates = .init(
      combined: source.updates,
      with: self.stateUpdates.updates
    )
    self.sourceUpdates = source.updates
    self.computeUpdate = { (_: ViewState) async -> ViewState in
      await withLogCatch(
        fallback: failure
      ) {
        try await transform(source.value)
      }
    }
  }

  public init<Source>(
    initial: ViewState,
    from source: Source,
    transform: @escaping @MainActor (Source.DataType) async -> ViewState
  ) where Source: DataSource, Source.Failure == Never {
    self.state = initial
    self.stateUpdates = .init()
    self.updates = .init(
      combined: source.updates,
      with: self.stateUpdates.updates
    )
    self.sourceUpdates = source.updates
    self.computeUpdate = { (state: ViewState) async -> ViewState in
      // source value can't throw here
      (try? await transform(source.value)) ?? state
    }
  }

  @MainActor public init<Source>(
    from source: Source,
    transform: @escaping @MainActor (Source.ViewState) -> ViewState
  ) where Source: ViewStateSource, Source.ViewState: Equatable {
    self.state = transform(source.state)
    self.stateUpdates = .init()
    self.updates = .init(
      combined: source.updates,
      with: self.stateUpdates.updates
    )
    self.sourceUpdates = source.updates
    if let computedSource = source as? ComputedViewState<Source.ViewState> {
      self.computeUpdate = { (_: ViewState) async -> ViewState in
        await computedSource.updateIfNeeded()
        return transform(computedSource.state)
      }
    }
    else if let updatableSource = source as? UpdatableViewState<Source.ViewState> {
      self.computeUpdate = { (_: ViewState) async -> ViewState in
        await updatableSource.updateIfNeeded()
        return transform(updatableSource.state)
      }
    }
    else {
      self.computeUpdate = { (_: ViewState) async -> ViewState in
        return transform(source.state)
      }
    }
  }

  @MainActor public init<Source>(
    from source: Source,
    at keyPath: KeyPath<Source.ViewState, ViewState>
  ) where Source: ViewStateSource, Source.ViewState: Equatable {
    self.state = source.state[keyPath: keyPath]
    self.stateUpdates = .init()
    self.updates = .init(
      combined: source.updates,
      with: self.stateUpdates.updates
    )
    self.sourceUpdates = source.updates
    if let computedSource = source as? ComputedViewState<Source.ViewState> {
      self.computeUpdate = { (_: ViewState) async -> ViewState in
        await computedSource.updateIfNeeded()
        return computedSource.state[keyPath: keyPath]
      }
    }
    else if let updatableSource = source as? UpdatableViewState<Source.ViewState> {
      self.computeUpdate = { (_: ViewState) async -> ViewState in
        await updatableSource.updateIfNeeded()
        return updatableSource.state[keyPath: keyPath]
      }
    }
    else {
      self.computeUpdate = { (_: ViewState) async -> ViewState in
        return source.state[keyPath: keyPath]
      }
    }
  }

  // never aka placeholder
  public init<State>(
    never: State.Type
  ) where ViewState == Optional<State> {
    self.state = .none
    self.stateUpdates = .placeholder
    self.updates = .never
    self.sourceUpdates = .never
    self.computeUpdate = { (state: ViewState) async -> ViewState in
      unreachable("Can't produce Never")
    }
  }

  public init()
  where ViewState == Never? {
    self.state = .none
    self.stateUpdates = .placeholder
    self.updates = .never
    self.sourceUpdates = .never
    self.computeUpdate = { (state: ViewState) async -> ViewState in
      unreachable("Can't produce Never")
    }
  }

  deinit {
    self.runningUpdate?.cancel()
  }
}

extension ComputedViewState {

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

  @MainActor public func forceUpdate() async {
    let state: ViewState = await runningUpdate?.value ?? self.state
    let update: Task<ViewState, Never> = .init {
      await self.computeUpdate(state)
    }
    self.runningUpdate = update
    self.state = await update.value
    self.runningUpdate = .none
    self.sourceUpdates.checkUpdate()
    self.stateUpdates.sendUpdate()
  }
}
