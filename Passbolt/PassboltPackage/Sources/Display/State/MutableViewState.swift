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

@available(*, deprecated, message: "Please use ViewStateVariable instead")
@MainActor @dynamicMemberLookup
public final class MutableViewState<ViewState>
where ViewState: Equatable & Sendable {

  public let cancellables: Cancellables = .init()
  internal let stateWillChange: AnyPublisher<ViewState, Never>
  private let read: @MainActor () -> ViewState
  private let write: @MainActor (ViewState) -> Void
  private nonisolated let updatesSource: UpdatesSource  // for compatibility only
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
    initial: ViewState,
    extendingLifetimeOf container: FeaturesContainer? = .none,
    cleanup: @escaping () -> Void = { /* NOP */  }
  ) {
    var state: ViewState = initial
    let nextValueSubject: CurrentValueSubject<ViewState, Never> = .init(initial)
    let updatesSource: UpdatesSource = .init()
    self.updatesSource = updatesSource
    self.read = { state }
    self.write = { (newValue: ViewState) in
      nextValueSubject.send(newValue)
      state = newValue
    }
    self.stateWillChange =
      nextValueSubject
      .map {
        // compatibility only
        updatesSource.sendUpdate()
        return $0
      }
      .eraseToAnyPublisher()
    self.featuresContainer = container
    self.cleanup = cleanup
  }

  // stateless - does nothing
  public nonisolated init(
    extendingLifetimeOf container: FeaturesContainer? = .none,
    cleanup: @escaping () -> Void = { /* NOP */  }
  ) where ViewState == Never {
    self.read = { fatalError("Can't read Never") }
    self.write = { _ in /* NOP */ }
    self.stateWillChange = Empty<ViewState, Never>().eraseToAnyPublisher()
    let updatesSource: UpdatesSource = .init()
    updatesSource.terminate()
    self.updatesSource = updatesSource
    self.featuresContainer = container
    self.cleanup = cleanup
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
    self.stateWillChange = Empty<ViewState, Never>(completeImmediately: true).eraseToAnyPublisher()
    self.updatesSource = .placeholder
    self.featuresContainer = .none
    self.cleanup = { /* NOP */  }
  }
  #endif

  deinit {
    self.cleanup()
  }

  public private(set) var state: ViewState {
    @MainActor get { self.read() }
    @MainActor set { self.write(newValue) }
  }

  public subscript<Value>(
    dynamicMember keyPath: KeyPath<ViewState, Value>
  ) -> Value {
    self.state[keyPath: keyPath]
  }
}

extension MutableViewState: ViewStateSource {

  // It seems that there is some bug in swift 5.8 compiler,
  // typealiases below are already defined but it does not compile without it
  public typealias DataType = ViewState
  public typealias Failure = Never
  public typealias Element = ViewState
  public typealias AsyncIterator = AsyncThrowingMapSequence<Updates, ViewState>.Iterator

  public nonisolated var updates: Updates { self.updatesSource.updates }
}

extension MutableViewState {

  @MainActor public func update<Returned>(
    _ mutation: (inout ViewState) throws -> Returned
  ) rethrows -> Returned {
    var copy: ViewState = self.state
    defer { self.state = copy }

    return try mutation(&copy)
  }

  @MainActor public func update<Value>(
    _ keyPath: WritableKeyPath<ViewState, Value>,
    to value: Value
  ) {
    self.state[keyPath: keyPath] = value
  }

  public func binding<BindingValue>(
    to keyPath: WritableKeyPath<ViewState, BindingValue>
  ) -> Binding<BindingValue> {
    Binding<BindingValue>(
      get: { self.state[keyPath: keyPath] },
      set: { (newValue: BindingValue) in
        self.state[keyPath: keyPath] = newValue
      }
    )
  }
}

extension MutableViewState: Equatable {

  public nonisolated static func == (
    lhs: MutableViewState<ViewState>,
    rhs: MutableViewState<ViewState>
  ) -> Bool {
    lhs === rhs
  }
}

extension ViewStateSource {

  @available(*, deprecated, message: "Legacy use only")
  public nonisolated var viewNodeID: ViewNodeID {
    ViewNodeID(
      rawValue: ObjectIdentifier(self)
    )
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
