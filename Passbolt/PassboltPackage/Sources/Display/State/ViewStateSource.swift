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
    @MainActor _read {
      yield self._value
    }
    @MainActor _modify {
      var modified: ViewState = self._value
      yield &modified
      self.viewUpdatesPublisher.send(modified)
      self._value = modified
    }
  }
  private var _value: ViewState
  internal let updatesPublisher:
    Publishers.Share<Publishers.RemoveDuplicates<Publishers.Autoconnect<ViewUpdatesPublisher<ViewState>>>>
  private let viewUpdatesPublisher: ViewUpdatesPublisher<ViewState>
  private let checkSourceUpdate: @MainActor () -> Bool
  private let updateFromSource: @Sendable (@MainActor (@MainActor (inout ViewState) -> Void) -> Void) async -> Void
  @MainActor private var runningUpdate: Task<Void, Never>?
  private let sourceRef: AnyObject?

  @MainActor public init<Source>(
    initial: ViewState,
    updateFrom source: Source,
    update: @escaping @Sendable (@MainActor (@MainActor (inout ViewState) -> Void) -> Void, Update<Source.Value>) async throws
      -> Void
  ) where Source: Updatable {
    // always keep reference to source to prevent unexpected
    // deallocation, however it should be kept only if uniquely referenced
    // revisit on iOS 16+ with Swift 5.9+
    self.sourceRef = source as? AnyObject  // warning due to iOS 15 support
    self._value = initial
    var lastUpdateGeneration: UpdateGeneration = .uninitialized
    self.checkSourceUpdate = { @MainActor [weak source] () -> Bool in
      lastUpdateGeneration < source?.generation ?? .uninitialized
    }
    self.updateFromSource = { @MainActor [weak source] (mutate: (@MainActor (inout ViewState) -> Void) -> Void) async in

      await consumingErrors {
        guard let sourceUpdate: Update<Source.Value> = try await source?.lastUpdate
        else { return }  // can't update without source
        lastUpdateGeneration = sourceUpdate.generation
        try await update(mutate, sourceUpdate)
      }
    }
    self.viewUpdatesPublisher = .init(initial: self._value)
    self.updatesPublisher = self.viewUpdatesPublisher
      .autoconnect()
      .removeDuplicates()
      .share()
    self.viewUpdatesPublisher.connection = { @MainActor [weak self, weak source] in
      guard var iterator = source?.makeAsyncIterator()
      else { return }  // can't update without source
      while let _ = await iterator.next() {
        await self?.updateIfNeeded()
      }
    }
  }

  public init(
    initial: ViewState
  ) {
    self.sourceRef = .none
    self._value = initial
    self.checkSourceUpdate = { false }
    self.updateFromSource = { @MainActor _ in
      // NOP
    }
    self.viewUpdatesPublisher = .init(initial: self._value)
    self.updatesPublisher = self.viewUpdatesPublisher
      .autoconnect()
      .removeDuplicates()
      .share()
  }

  public init() where ViewState == Stateless {
    self.sourceRef = .none
    self._value = Stateless()
    self.checkSourceUpdate = { false }
    self.updateFromSource = { @MainActor _ in
      // NOP
    }
    self.viewUpdatesPublisher = .init(initial: self._value)
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
    guard self.checkSourceUpdate() else { return self.value }
    let runningUpdate: Task<Void, Never> = .init(
      priority: .userInitiated
    ) { [weak self, updateFromSource] in
      await updateFromSource { @MainActor [weak self] (mutate: @MainActor (inout ViewState) -> Void) in
        self?.update(mutate)
      }
    }
    self.runningUpdate = runningUpdate
    await runningUpdate.waitForCompletion()
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

public struct Stateless: Equatable {}
