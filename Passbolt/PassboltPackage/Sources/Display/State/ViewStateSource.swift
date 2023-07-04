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

public final class ViewStateSource<ViewState>
where ViewState: Equatable {

  public var current: ViewState {
    get async { await self.updateIfNeeded() }
  }

  @MainActor internal var value: ViewState {
    willSet { self.viewUpdatesPublisher.send(newValue) }
  }
  internal var updatesPublisher:
    Publishers.Share<Publishers.RemoveDuplicates<Publishers.Autoconnect<ViewUpdatesPublisher<ViewState>>>>
  @MainActor internal private(set) var sourceUpdates: Updates
  private var viewUpdatesPublisher: ViewUpdatesPublisher<ViewState>
  private var update: @MainActor (inout ViewState) async -> Void
  @MainActor private var runningUpdate: Task<ViewState, Never>?

  @MainActor public init<Source>(
    initial: ViewState,
    updateFrom source: Source,
    fallback: @escaping @MainActor (inout ViewState, Error) async -> Void = { _, _ in }
  ) where Source: DataSource, Source.DataValue == ViewState {
    self.value = initial
    self.sourceUpdates = source.updates
    self.update = { @MainActor (state: inout ViewState) async in
      await withLogCatch(
        fallback: { (error: Error) in
          await fallback(&state, error)
        }
      ) {
        state = try await source.current
      }
    }
    self.viewUpdatesPublisher = .init(initial: self.value)
    self.updatesPublisher = self.viewUpdatesPublisher
      .autoconnect()
      .removeDuplicates()
      .share()
    self.viewUpdatesPublisher.connection = { @MainActor [unowned self] in
      for await _ in source.updates {
        await self.updateIfNeeded()
      }
    }
  }

  @MainActor public init<Source>(
    initial: ViewState,
    updateFrom source: Source,
    transform: @escaping @Sendable (inout ViewState, Source.DataValue) async throws -> Void,
    fallback: @escaping @MainActor (inout ViewState, Error) async -> Void = { _, _ in }
  ) where Source: DataSource {
    self.value = initial
    self.sourceUpdates = source.updates
    self.update = { @MainActor (state: inout ViewState) async in
      await withLogCatch(
        fallback: { (error: Error) in
          await fallback(&state, error)
        }
      ) {
        try await transform(&state, source.current)
      }
    }
    self.viewUpdatesPublisher = .init(initial: self.value)
    self.updatesPublisher = self.viewUpdatesPublisher
      .autoconnect()
      .removeDuplicates()
      .share()
    self.viewUpdatesPublisher.connection = { @MainActor [unowned self] in
      for await _ in source.updates {
        await self.updateIfNeeded()
      }
    }
  }

  @MainActor public init(
    initial: ViewState,
    updateUsing updates: Updates,
    update: @escaping @MainActor (inout ViewState) async -> Void
  ) {
    self.value = initial
    self.sourceUpdates = updates
    self.update = update
    self.viewUpdatesPublisher = .init(initial: self.value)
    self.updatesPublisher = self.viewUpdatesPublisher
      .autoconnect()
      .removeDuplicates()
      .share()
    self.viewUpdatesPublisher.connection = { @MainActor [unowned self] in
      for await _ in updates {
        await self.updateIfNeeded()
      }
    }
  }

  @MainActor public init(
    initial: ViewState,
    updateUsing updates: Updates,
    update: @escaping @MainActor (inout ViewState) async throws -> Void,
    fallback: @escaping @MainActor (inout ViewState, Error) async -> Void
  ) {
    self.value = initial
    self.sourceUpdates = updates
    self.update = { @MainActor (state: inout ViewState) async -> Void in
      await withLogCatch(
        fallback: { (error: Error) in
          await fallback(&state, error)
        }
      ) {
        try await update(&state)
      }
    }
    self.viewUpdatesPublisher = .init(initial: self.value)
    self.updatesPublisher = self.viewUpdatesPublisher
      .autoconnect()
      .removeDuplicates()
      .share()
    self.viewUpdatesPublisher.connection = { @MainActor [unowned self] in
      for await _ in updates {
        await self.updateIfNeeded()
      }
    }
  }

  @MainActor public init(
    from variable: Variable<ViewState>
  ) {
    self.value = variable.current
    self.sourceUpdates = variable.updates
    self.update = { @MainActor (state: inout ViewState) async in
      state = variable.current
    }
    self.viewUpdatesPublisher = .init(initial: self.value)
    self.updatesPublisher = self.viewUpdatesPublisher
      .autoconnect()
      .removeDuplicates()
      .share()
    self.viewUpdatesPublisher.connection = { @MainActor [unowned self] in
      for await _ in variable.updates {
        await self.updateIfNeeded()
      }
    }
  }

  public init(
    initial: ViewState
  ) {
    self.value = initial
    self.sourceUpdates = .never
    self.update = { @MainActor (_: inout ViewState) async -> Void in
      // NOP
    }
    self.viewUpdatesPublisher = .init(initial: self.value)
    self.updatesPublisher = self.viewUpdatesPublisher
      .autoconnect()
      .removeDuplicates()
      .share()
  }

  public init() where ViewState == Stateless {
    self.value = Stateless()
    self.sourceUpdates = .never
    self.update = { @MainActor (_: inout ViewState) async -> Void in
      // NOP
    }
    self.viewUpdatesPublisher = .init(initial: self.value)
    self.updatesPublisher = self.viewUpdatesPublisher
      .autoconnect()
      .removeDuplicates()
      .share()
  }

  deinit {
    self.runningUpdate?.cancel()
  }

  @discardableResult
  @MainActor internal func updateIfNeeded() async -> ViewState {
    await self.runningUpdate?.waitForCompletion()
    guard self.sourceUpdates.checkUpdate()
    else { return self.value }
    let state: ViewState = self.value
    let runningUpdate: Task<ViewState, Never> = .init(
      priority: .userInitiated
    ) {
      var state: ViewState = state
      await update(&state)
      return state
    }
    self.runningUpdate = runningUpdate
    self.value = await runningUpdate.value
    self.runningUpdate = .none
    return self.value
  }
}

extension ViewStateSource {

  @discardableResult
  @MainActor public func update<Returned>(
    _ mutation: @MainActor (inout ViewState) throws -> Returned
  ) rethrows -> Returned {
    try mutation(&self.value)
  }

  @MainActor public func update<Property>(
    _ keyPath: WritableKeyPath<ViewState, Property>,
    to newValue: Property
  ) {
    self.value[keyPath: keyPath] = newValue
  }

  @MainActor public func update(
    to newValue: ViewState
  ) {
    self.value = newValue
  }
}

//extension ViewStateSource {
//
//  @available(*, deprecated, message: "Legacy use only")
//  public nonisolated var viewNodeID: ViewNodeID {
//    ViewNodeID(
//      rawValue: ObjectIdentifier(self)
//    )
//  }
//}

public struct Stateless: Equatable {}
