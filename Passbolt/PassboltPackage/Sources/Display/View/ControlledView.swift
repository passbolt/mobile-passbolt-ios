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
  public func when<OptionalView>(
    _ keyPath: KeyPath<ViewState, Bool>,
    @ViewBuilder content optionalView: @escaping () -> OptionalView
  ) -> some View
  where OptionalView: View {
    WithViewState(
      from: self.controller,
      at: keyPath,
      content: { (enabled: Bool) in
        if enabled {
          optionalView()
        }  // else no view
      }
    )
  }

  @_transparent
  public func whenFalse<OptionalView>(
    _ keyPath: KeyPath<ViewState, Bool>,
    @ViewBuilder content optionalView: @escaping () -> OptionalView
  ) -> some View
  where OptionalView: View {
    WithViewState(
      from: self.controller,
      at: keyPath,
      content: { (enabled: Bool) in
        if enabled == false {
          optionalView()
        }  // else no view
      }
    )
  }

  @_transparent
  public func whenUnwrapped<OptionalView, Value>(
    _ keyPath: KeyPath<ViewState, Optional<Value>>,
    @ViewBuilder content optionalView: @escaping (Value) -> OptionalView
  ) -> some View
  where OptionalView: View, Value: Equatable & Sendable {
    WithViewState(
      from: self.controller,
      at: keyPath,
      content: { (value: Value?) in
        if let value {
          optionalView(value)
        }  // else no view
      }
    )
  }

  @_transparent
  public func with<State, StateView>(
    _ keyPath: KeyPath<ViewState, State>,
    @ViewBuilder content stateView: @escaping (State) -> StateView
  ) -> some View
  where State: Equatable & Sendable, StateView: View {
    WithViewState(
      from: self.controller,
      at: keyPath,
      content: stateView
    )
  }

  @_transparent
  public func withBinding<State, StateView>(
    _ keyPath: WritableKeyPath<ViewState, State>,
    @ViewBuilder content stateView: @escaping (Binding<State>) -> StateView
  ) -> some View
  where State: Equatable & Sendable, StateView: View {
    WithBindingState(
      from: self.controller,
      at: keyPath,
      content: stateView
    )
  }

  @_transparent
  public func withBinding<State, StateView>(
    _ keyPath: WritableKeyPath<ViewState, State>,
    updating: @escaping @MainActor (State) -> Void,
    @ViewBuilder content stateView: @escaping (Binding<State>) -> StateView
  ) -> some View
  where State: Equatable & Sendable, StateView: View {
    WithBindingState(
      from: self.controller,
      at: keyPath,
      updating: updating,
      content: stateView
    )
  }

  @_transparent
  public func withValidatedBinding<State, StateView>(
    _ keyPath: WritableKeyPath<ViewState, Validated<State>>,
    updating: @escaping @MainActor (State) -> Void,
    @ViewBuilder content stateView: @escaping (Binding<Validated<State>>) -> StateView
  ) -> some View
  where State: Equatable, StateView: View {
    WithBindingState(
      from: self.controller,
      atValidated: keyPath,
      updating: updating,
      content: stateView
    )
  }

  @_transparent
  public func withEach<State, StateView>(
    _ keyPath: KeyPath<ViewState, State>,
    @ViewBuilder content stateView: @escaping (State.Element) -> StateView
  ) -> some View
  where
    State: RandomAccessCollection,
    State: Equatable & Sendable,
    State.Element: Equatable & Identifiable,
    StateView: View
  {
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
    State: Equatable & Sendable,
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

  /// Extends content view with support for system alert presentation from provided State.
  /// Parameters:
  ///  - keyPath: A key path to an optional State in the ViewState - if non-nil, alert will be shown, if nil - alert will disapear.
  ///  - alert: A closure that transforms State into AlertViewModel.
  ///  - content: A view builder that creates the content view.
  @_transparent
  public func withAlert<State, ContentView>(
    _ keyPath: WritableKeyPath<ViewState, State?>,
    alert: @escaping @Sendable (State) -> AlertViewModel,
    @ViewBuilder content: @escaping @MainActor () -> ContentView
  ) -> some View
  where State: Equatable & Sendable, ContentView: View {
    WithAlert(
      from: self.controller,
      at: keyPath,
      alert: alert,
      content: content
    )
  }

  /// Extends content view with support for system alert presentation from provided view model.
  ///  Parameters:
  ///   - keyPath: A key path to an optional AlertViewModel in the ViewState - if non-nil, alert will be shown, if nil - alert will disapear.
  ///   - content: A view builder that creates the content view.
  @_transparent
  public func withAlert<ContentView>(
    _ keyPath: WritableKeyPath<ViewState, AlertViewModel?>,
    @ViewBuilder content: @escaping @MainActor () -> ContentView
  ) -> some View
  where ContentView: View {
    withAlert(keyPath, alert: { $0 }, content: content)
  }

  @_transparent
  public func withSheet<State, SheetView, ContentView>(
    _ keyPath: WritableKeyPath<ViewState, State?>,
    @ViewBuilder sheet sheetView: @escaping @MainActor (State) -> SheetView,
    @ViewBuilder content contentView: @escaping @MainActor () -> ContentView
  ) -> some View
  where Controller: ViewController, State: Equatable & Identifiable & Sendable, SheetView: View, ContentView: View {
    WithSheet(
      from: self.controller,
      at: keyPath,
      sheet: sheetView,
      content: contentView
    )
  }

  @_transparent
  public func withSheet<SheetView, ContentView>(
    _ keyPath: WritableKeyPath<ViewState, Bool>,
    @ViewBuilder sheet sheetView: @escaping @MainActor () -> SheetView,
    @ViewBuilder content contentView: @escaping @MainActor () -> ContentView
  ) -> some View
  where Controller: ViewController, SheetView: View, ContentView: View {
    WithToggledSheet(
      from: self.controller,
      at: keyPath,
      sheet: sheetView,
      content: contentView
    )
  }

  @ViewBuilder @MainActor public func withExternalActivity<ContentView>(
    _ keyPath: WritableKeyPath<ViewState, ExternalActivityConfiguration?>,
    @ViewBuilder content contentView: @escaping @MainActor () -> ContentView
  ) -> some View
  where ContentView: View {
    WithExternalActivity(
      from: self.controller,
      at: keyPath,
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

  @MainActor public func optionalBinding<Value>(
    to keyPath: WritableKeyPath<ViewState, Value?>,
    default: Value,
    updating setter: @escaping @MainActor (Value) -> Void
  ) -> Binding<Value> {
    self.controller.optionalBinding(
      to: keyPath,
      default: `default`,
      updating: setter
    )
  }

  @MainActor public func validatedBinding<Value>(
    to keyPath: WritableKeyPath<ViewState, Validated<Value>>,
    updating setter: @escaping @MainActor (Value) -> Void
  ) -> Binding<Validated<Value>> {
    self.controller.validatedBinding(
      to: keyPath,
      updating: setter
    )
  }

  @MainActor public func validatedOptionalBinding<Value>(
    to keyPath: WritableKeyPath<ViewState, Validated<Value>?>,
    default: Validated<Value>,
    updating setter: @escaping @MainActor (Value) -> Void
  ) -> Binding<Validated<Value>> {
    self.controller.validatedOptionalBinding(
      to: keyPath,
      default: `default`,
      updating: setter
    )
  }

  @MainActor public func validatedOptionalBinding<MidValue, Value>(
    to nestedKeyPath: WritableKeyPath<MidValue, Validated<Value>>,
    in keyPath: WritableKeyPath<ViewState, MidValue?>,
    default: Validated<Value>,
    updating setter: @escaping @MainActor (Value) -> Void
  ) -> Binding<Validated<Value>> {
    self.controller.validatedOptionalBinding(
      to: nestedKeyPath,
      in: keyPath,
      default: `default`,
      updating: setter
    )
  }

  @MainActor public func validatedBinding<Value, Tag>(
    to keyPath: WritableKeyPath<ViewState, Validated<Tagged<Value, Tag>>>,
    updating setter: @escaping @MainActor (Tagged<Value, Tag>) -> Void
  ) -> Binding<Validated<Value>> {
    self.controller.validatedBinding(
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
