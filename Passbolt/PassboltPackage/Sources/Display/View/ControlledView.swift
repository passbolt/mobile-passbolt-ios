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

public protocol ControlledView: View {

  associatedtype Controller: ViewController

  var controller: Controller { get }

  init(controller: Controller)
}

extension ControlledView {

  public typealias ViewState = Controller.ViewState
}

extension ControlledView {

  @_transparent
  public func withSnackBarMessage<ContentView>(
    _ keyPath: WritableKeyPath<ViewState, SnackBarMessage?>,
    @ViewBuilder content contentView: @escaping () -> ContentView
  ) -> some View
  where Controller: ViewController, ContentView: View {
    WithSnackBarMessage(
      from: self.controller,
      at: keyPath,
      content: contentView
    )
  }

  @_transparent
  public func with<State, StateView>(
    _ keyPath: KeyPath<ViewState, State>,
    @ViewBuilder content stateView: @escaping (State) -> StateView
  ) -> some View
  where State: Equatable, StateView: View {
    WithViewState(
      from: self.controller,
      at: keyPath,
      content: stateView
    )
  }

  @_transparent
  public func withEach<State, StateView>(
    _ keyPath: KeyPath<ViewState, State>,
    @ViewBuilder content stateView: @escaping (State.Element) -> StateView
  ) -> some View
  where State: RandomAccessCollection, State: Equatable, State.Element: Equatable & Identifiable, StateView: View {
    WithEachViewState(
      from: self.controller,
      at: keyPath,
      content: stateView
    )
  }

  @_transparent
  public func withEach<State, StateView, PlaceholderView>(
    _ keyPath: KeyPath<ViewState, State>,
    @ViewBuilder content stateView: @escaping (State.Element) -> StateView,
    @ViewBuilder placeholder placeholderView: @escaping () -> PlaceholderView
  ) -> some View
  where
    State: RandomAccessCollection,
    State: Equatable,
    State.Element: Equatable & Identifiable,
    StateView: View,
    PlaceholderView: View
  {
    WithEachViewState(
      from: self.controller,
      at: keyPath,
      content: stateView,
      placeholder: placeholderView
    )
  }

  @_transparent
  public func withAlert<State, ContentView>(
    _ keyPath: WritableKeyPath<ViewState, State?>,
    alert: @escaping @Sendable (State) -> AlertViewModel,
    @ViewBuilder content contentView: @escaping () -> ContentView
  ) -> some View
  where State: Equatable, ContentView: View {
    WithAlert(
      from: self.controller,
      at: keyPath,
      alert: alert,
      content: contentView
    )
  }
}

extension ControlledView {

  @MainActor public func binding<Value>(
    to keyPath: WritableKeyPath<ViewState, Value>,
    updating setter: @escaping @MainActor (Value) -> Void
  ) -> Binding<Value> {
    self.controller.binding(
      to: keyPath,
      updating: setter
    )
  }

  @MainActor public func binding<Value>(
    to keyPath: WritableKeyPath<ViewState, Value>
  ) -> Binding<Value> {
    self.controller.binding(to: keyPath)
  }
}
