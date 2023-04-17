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

import Combine
import Commons
import SwiftUI

@MainActor @dynamicMemberLookup
public final class MutableViewState<State>
where State: Equatable & Sendable {

  public let cancellables: Cancellables = .init()
	public nonisolated let forceRefeshSubject: PassthroughSubject<Void, Never>
  internal let stateWillChange: AnyPublisher<State, Never>
  internal let updates: UpdatesSequence
  private let read: @MainActor () -> State
  private let write: @MainActor (State) -> Void
  private nonisolated let cleanup: () -> Void
  // Features are stored here to bind reference
  // with a screen when branching. Losing reference
  // to FeaturesContainer after branching closes that
  // branch. Easiest way to ensure proper lifetime of
  // a branch is to bind it to a view that begins
  // given branch. Since most of the code is out of
  // class/structure and cannot hold any reference
  // longer than the scope of load functions
  // it can be stored in ViewStateBinding which
  // lifetime directly corresponds to the view lifetime.
  private let featuresContainer: FeaturesContainer?

  public nonisolated init(
    initial: State,
    extendingLifetimeOf container: FeaturesContainer? = .none,
    cleanup: @escaping () -> Void = { /* NOP */  }
  ) {
    var state: State = initial
		let forceRefeshSubject: PassthroughSubject<Void, Never> = .init()
    let nextValueSubject: CurrentValueSubject<State, Never> = .init(initial)
    let updatesSource: UpdatesSequenceSource = .init()
    self.read = { state }
    self.write = { (newValue: State) in
      nextValueSubject.send(newValue)
      state = newValue
      updatesSource.sendUpdate()
    }
		self.stateWillChange = nextValueSubject.merge(with: forceRefeshSubject.map { nextValueSubject.value }).eraseToAnyPublisher()
    self.updates = updatesSource.updatesSequence
    self.featuresContainer = container
    self.cleanup = cleanup
		self.forceRefeshSubject = forceRefeshSubject
  }

  // stateless - does nothing
  public nonisolated init(
    extendingLifetimeOf container: FeaturesContainer? = .none,
    cleanup: @escaping () -> Void = { /* NOP */  }
  )
  where State == Stateless {
    self.read = { fatalError("Can't read Never") }
    self.write = { _ in /* NOP */ }
    self.stateWillChange = Empty<State, Never>().eraseToAnyPublisher()
    let updatesSource: UpdatesSequenceSource = .init()
    updatesSource.endUpdates()
    self.updates = updatesSource.updatesSequence
    self.featuresContainer = container
    self.cleanup = cleanup
		self.forceRefeshSubject = .init()
  }

  #if DEBUG
  // placeholder - crashes when used
  fileprivate nonisolated init(
    file: StaticString,
    line: UInt
  ) {
    self.read = unimplemented0(
      file: file,
      line: line
    )
    self.write = unimplemented1(
      file: file,
      line: line
    )
    self.stateWillChange = Empty<State, Never>().eraseToAnyPublisher()
    self.updates = .placeholder
    self.featuresContainer = .none
    self.cleanup = { /* NOP */  }
		self.forceRefeshSubject = .init()
  }
  #endif

  deinit {
    self.cleanup()
  }

  public private(set) var value: State {
    get { self.read() }
    set { self.write(newValue) }
  }

  public subscript<Value>(
    dynamicMember keyPath: KeyPath<State, Value>
  ) -> Value {
    self.value[keyPath: keyPath]
  }
}

extension MutableViewState {

  public func update<Returned>(
    _ mutation: (inout State) throws -> Returned
  ) rethrows -> Returned {
    var copy: State = self.value
    defer { self.value = copy }

    return try mutation(&copy)
  }

  public func update<Value>(
    _ keyPath: WritableKeyPath<State, Value>,
    to value: Value
  ) {
    self.value[keyPath: keyPath] = value
  }

  public func binding<BindingValue>(
    to keyPath: WritableKeyPath<State, BindingValue>
  ) -> Binding<BindingValue> {
    Binding<BindingValue>(
      get: { self.value[keyPath: keyPath] },
      set: { (newValue: BindingValue) in
        self.value[keyPath: keyPath] = newValue
      }
    )
  }
}

extension MutableViewState: Equatable {

  public nonisolated static func == (
    lhs: MutableViewState<State>,
    rhs: MutableViewState<State>
  ) -> Bool {
    lhs === rhs
  }

  public nonisolated var viewNodeID: ViewNodeID {
    ViewNodeID(
      rawValue: ObjectIdentifier(self)
    )
  }
}

extension MutableViewState: AsyncSequence {

  public typealias Element = State
  public typealias AsyncIterator = AsyncMapSequence<UpdatesSequence, State>.Iterator

  public func makeAsyncIterator() -> AsyncIterator {
    self.updates
      .map { self.value }
      .makeAsyncIterator()
  }
}

#if DEBUG
extension MutableViewState {

  public nonisolated static func placeholder(
    file: StaticString = #fileID,
    line: UInt = #line
  ) -> Self {
    .init(
      file: file,
      line: line
    )
  }
}
#endif
