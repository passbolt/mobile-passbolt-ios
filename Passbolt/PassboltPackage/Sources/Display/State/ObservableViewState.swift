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

@MainActor
public final class ObservableViewState<State: Equatable>: ObservableObject {

  public nonisolated let objectWillChange: ObservableObjectPublisher
  internal let updates: AnyAsyncSequence<State>
  private let read: @MainActor () -> State
  private let cancellable: AnyCancellable

  public nonisolated init<Variable>(
    from variable: MutableViewState<Variable>,
    at keyPath: KeyPath<Variable, State>
  ) {
    self.read = { variable.value[keyPath: keyPath] }
    let objectWillChange: ObservableObjectPublisher = .init()
    self.objectWillChange = objectWillChange
    self.updates =
      variable
      .map { (variable: Variable) -> State in
        variable[keyPath: keyPath]
      }
      .removeDuplicates()
      .asAnyAsyncSequence()
    self.cancellable = variable
      .stateWillChange
      .map { (variable: Variable) in
        variable[keyPath: keyPath]
      }
      .removeDuplicates()
      .sink { (_: State) in
        objectWillChange.send()
      }
  }

  public nonisolated init(
    from variable: MutableViewState<State>
  ) {
    self.read = { variable.value }
    let objectWillChange: ObservableObjectPublisher = .init()
    self.objectWillChange = objectWillChange
    self.updates =
      variable
      .asAnyAsyncSequence()
    self.cancellable = variable
      .stateWillChange
      .removeDuplicates()
      .sink { (_: State) in
        objectWillChange.send()
      }
  }

  public nonisolated init<Other>(
    from observable: ObservableViewState<Other>,
    mapping: @escaping @Sendable (Other) -> State
  ) {
    self.read = { mapping(observable.value) }
    // TODO: no duplicate filtering
    self.objectWillChange = observable.objectWillChange
    self.updates =
      observable
      .asAnyAsyncSequence()
      .map(mapping)
      .asAnyAsyncSequence()
    self.cancellable = AnyCancellable({ /* NOP */  })
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
    self.objectWillChange = .init()
    self.updates = .init([])
    self.cancellable = AnyCancellable({ /* NOP */  })
  }
  #endif

  public var value: State {
    self.read()
  }
}

extension ObservableViewState {

  @available(
    *,
    deprecated,
    message:
      "Please use other forms of binding values. ViewStateView should be used only to provide view state and updates.`"
  )
  public nonisolated func map<Mapped>(
    _ mapping: @escaping @Sendable (State) -> Mapped
  ) -> ObservableViewState<Mapped> {
    .init(
      from: self,
      mapping: mapping
    )
  }

  @available(
    *,
    deprecated,
    message:
      "Please use other forms of binding values. ViewStateView should be used only to provide view state and updates.`"
  )
  public nonisolated func valuesPublisher() -> some Combine.Publisher<State, Never> {
    self.objectWillChange
      .compactMap { [weak self] in self }
      .asyncMap { (binding: ObservableViewState) in
        await binding.read()
      }
  }
}

extension ObservableViewState: AsyncSequence {

  public typealias Element = State
  public typealias AsyncIterator = AnyAsyncSequence<State>.AsyncIterator

  public func makeAsyncIterator() -> AsyncIterator {
    self.updates.makeAsyncIterator()
  }
}

#if DEBUG
extension ObservableViewState {

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
