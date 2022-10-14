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

import Features
import UIComponents

public protocol ViewController: Hashable, LoadableFeature {

  associatedtype ViewState: Hashable = Stateless
  associatedtype ViewActions: ViewControllerActions = Actionless

  var id: IID { get }
  var viewState: ViewStateBinding<ViewState> { get }
  var viewActions: ViewActions { get }
}

extension ViewController
where ViewState == Stateless {

  public var viewState: ViewStateBinding<Never> {
    Stateless().wrappedValue
  }
}

extension ViewController
where ViewActions == Actionless {

  public var viewActions: ViewActions {
    Actionless()
  }
}

extension ViewController /* Hashable */ {

  public static func == (
    _ lhs: Self,
    _ rhs: Self
  ) -> Bool {
    lhs.id == rhs.id
  }

  public func hash(
    into hasher: inout Hasher
  ) {
    hasher.combine(self.id)
  }
}

extension ViewController {

  public func binding<Value>(
    to keyPath: WritableKeyPath<ViewState, Value>
  ) -> Binding<Value> {
    self.viewState.binding(to: keyPath)
  }

  public func action(
    _ actionKeyPath: KeyPath<ViewActions, () -> Void>
  ) -> () -> Void {
    self.viewActions[keyPath: actionKeyPath]
  }

  public func actionOptional(
    _ actionKeyPath: KeyPath<ViewActions, (() -> Void)?>
  ) -> (() -> Void)? {
    self.viewActions[keyPath: actionKeyPath]
  }

  public func actionAsync(
    _ actionKeyPath: KeyPath<ViewActions, @Sendable () async -> Void>
  ) -> @Sendable () async -> Void {
    self.viewActions[keyPath: actionKeyPath]
  }

  public func action<A1>(
    _ actionKeyPath: KeyPath<ViewActions, (A1) -> Void>
  ) -> (A1) -> Void {
    self.viewActions[keyPath: actionKeyPath]
  }

  public func actionOptional<A1>(
    _ actionKeyPath: KeyPath<ViewActions, ((A1) -> Void)?>
  ) -> ((A1) -> Void)? {
    self.viewActions[keyPath: actionKeyPath]
  }

  public func perform(
    _ actionKeyPath: KeyPath<ViewActions, () -> Void>
  ) {
    self.viewActions[keyPath: actionKeyPath]()
  }

  public func perform<A1>(
    _ actionKeyPath: KeyPath<ViewActions, (A1) -> Void>,
    with arg1: A1
  ) {
    self.viewActions[keyPath: actionKeyPath](arg1)
  }

  public func perform<A1, A2>(
    _ actionKeyPath: KeyPath<ViewActions, (A1, A2) -> Void>,
    with arg1: A1,
    _ arg2: A2
  ) {
    self.viewActions[keyPath: actionKeyPath](arg1, arg2)
  }

  public func perform<A1, A2, A3>(
    _ actionKeyPath: KeyPath<ViewActions, (A1, A2, A3) -> Void>,
    with arg1: A1,
    _ arg2: A2,
    _ arg3: A3
  ) {
    self.viewActions[keyPath: actionKeyPath](arg1, arg2, arg3)
  }
}
