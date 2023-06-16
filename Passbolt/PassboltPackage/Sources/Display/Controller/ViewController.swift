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

// Same instance should not be reused between multiple
// views - it should uniquely identify a view on display.
@MainActor public protocol ViewController: AnyObject, Hashable {

  associatedtype ViewState: Equatable = Never
	associatedtype StateSource: ViewStateSource = MutableViewState<Never>
	where StateSource.ViewState == ViewState
  associatedtype Context = Void

	nonisolated var viewState: StateSource { get }

  @MainActor init(
    context: Context,
    features: Features
  ) throws
}

extension ViewController {

	@available(*, deprecated, message: "Do not use viewNodeID to identify views.")
  public nonisolated var viewNodeID: ViewNodeID {
		(self.viewState as? MutableViewState<ViewState>)?.viewNodeID
		?? .init(rawValue: .init(self))
  }
}

extension ViewController /* Hashable */ {

  public nonisolated static func == (
    _ lhs: Self,
    _ rhs: Self
  ) -> Bool {
    lhs === rhs
  }

  public nonisolated func equal(
    to other: any ViewController
  ) -> Bool {
    return self === other  //equal(self, other)
  }

  public nonisolated func hash(
    into hasher: inout Hasher
  ) {
    hasher.combine(self)
  }
}

extension ViewController
where StateSource == MutableViewState<Never> {

  public nonisolated var viewState: StateSource { MutableViewState<Never>() }
}

extension ViewController {

  @MainActor public func binding<Value>(
    to keyPath: WritableKeyPath<ViewState, Value>
  ) -> Binding<Value> {
    self.viewState.binding(to: keyPath)
  }

  @MainActor public func binding<Value>(
    to keyPath: WritableKeyPath<ViewState, Value>,
    updating setter: @escaping (Value) -> Void
  ) -> Binding<Value> {
    .init(
      get: {
        self.viewState.state[keyPath: keyPath]
      },
      set: setter
    )
  }

  @MainActor public func validatedBinding<Value>(
    to keyPath: WritableKeyPath<ViewState, Validated<Value>>,
    updating setter: @escaping (Value) -> Void
  ) -> Binding<Validated<Value>> {
    .init(
      get: {
        self.viewState.state[keyPath: keyPath]
      },
      set: { (newValue: Validated<Value>) in
        setter(newValue.value)
      }
    )
  }

  @MainActor public func validatedStringBinding<Value, UpdateValue>(
    with keyPath: WritableKeyPath<ViewState, Validated<Value>>,
    updating setter: @escaping (UpdateValue) -> Void,
    fromString: @escaping (String) -> UpdateValue?,
    toString: @escaping (Value) -> String
  ) -> Binding<Validated<String>> {
    .init(
      get: {
        let validated: Validated<Value> = self.viewState.state[keyPath: keyPath]
        if let error: TheError = validated.error {
          return .invalid(
            toString(validated.value),
            error: error
          )
        }
        else {
          return .valid(toString(validated.value))
        }
      },
      set: { (newValidated: Validated<String>) in
        guard let newValue: UpdateValue = fromString(newValidated.value)
        else { return }  // ignore
        setter(newValue)
      }
    )
  }
}

extension Features {

  @MainActor public func instance<Controller>(
    of _: Controller.Type = Controller.self,
    context: Controller.Context,
    file: StaticString = #fileID,
    line: UInt = #line
  ) throws -> Controller
  where Controller: ViewController {
    try Controller(
      context: context,
      features: self
    )
  }

  @MainActor public func instance<Controller>(
    of _: Controller.Type = Controller.self,
    file: StaticString = #fileID,
    line: UInt = #line
  ) throws -> Controller
  where Controller: ViewController, Controller.Context == Void {
    try Controller(
      context: Void(),
      features: self
    )
  }
}

public enum Controlled {

  @ViewBuilder public static func by<ControlledViewA, DefaultView>(
    _ controller: any ViewController,
    view: ControlledViewA.Type,
    @ViewBuilder orDefault defaultView: () -> DefaultView
  ) -> some View
  where ControlledViewA: ControlledView, DefaultView: View {
    switch controller {
    case let controller as ControlledViewA.Controller:
      ControlledViewA(controller: controller)
        .id(controller.viewNodeID)

    case _:
      defaultView()
    }
  }

  @ViewBuilder public static func by<ControlledViewA, ControlledViewB, DefaultView>(
    _ controller: any ViewController,
    view: ControlledViewA.Type,
    or _: ControlledViewB.Type,
    @ViewBuilder orDefault defaultView: () -> DefaultView
  ) -> some View
  where ControlledViewA: ControlledView, ControlledViewB: ControlledView, DefaultView: View {
    switch controller {
    case let controller as ControlledViewA.Controller:
      ControlledViewA(controller: controller)
        .id(controller.viewNodeID)

    case let controller as ControlledViewB.Controller:
      ControlledViewB(controller: controller)
        .id(controller.viewNodeID)

    case _:
      defaultView()
    }
  }

  @ViewBuilder public static func by<ControlledViewA, ControlledViewB, ControlledViewC, DefaultView>(
    _ controller: any ViewController,
    view: ControlledViewA.Type,
    or _: ControlledViewB.Type,
    or _: ControlledViewC.Type,
    @ViewBuilder orDefault defaultView: () -> DefaultView
  ) -> some View
  where
    ControlledViewA: ControlledView,
    ControlledViewB: ControlledView,
    ControlledViewC: ControlledView,
    DefaultView: View
  {
    switch controller {
    case let controller as ControlledViewA.Controller:
      ControlledViewA(controller: controller)
        .id(controller.viewNodeID)

    case let controller as ControlledViewB.Controller:
      ControlledViewB(controller: controller)
        .id(controller.viewNodeID)

    case let controller as ControlledViewC.Controller:
      ControlledViewC(controller: controller)
        .id(controller.viewNodeID)

    case _:
      defaultView()
    }
  }

  @ViewBuilder public static func by<ControlledViewA, ControlledViewB, ControlledViewC, ControlledViewD, DefaultView>(
    _ controller: any ViewController,
    view: ControlledViewA.Type,
    or _: ControlledViewB.Type,
    or _: ControlledViewC.Type,
    or _: ControlledViewD.Type,
    @ViewBuilder orDefault defaultView: () -> DefaultView
  ) -> some View
  where
    ControlledViewA: ControlledView,
    ControlledViewB: ControlledView,
    ControlledViewC: ControlledView,
    ControlledViewD: ControlledView,
    DefaultView: View
  {
    switch controller {
    case let controller as ControlledViewA.Controller:
      ControlledViewA(controller: controller)
        .id(controller.viewNodeID)

    case let controller as ControlledViewB.Controller:
      ControlledViewB(controller: controller)
        .id(controller.viewNodeID)

    case let controller as ControlledViewC.Controller:
      ControlledViewC(controller: controller)
        .id(controller.viewNodeID)

    case let controller as ControlledViewD.Controller:
      ControlledViewD(controller: controller)
        .id(controller.viewNodeID)

    case _:
      defaultView()
    }
  }

  @ViewBuilder
  public static func by<
    ControlledViewA,
    ControlledViewB,
    ControlledViewC,
    ControlledViewD,
    ControlledViewE,
    DefaultView
  >(
    _ controller: any ViewController,
    view: ControlledViewA.Type,
    or _: ControlledViewB.Type,
    or _: ControlledViewC.Type,
    or _: ControlledViewD.Type,
    or _: ControlledViewE.Type,
    @ViewBuilder orDefault defaultView: () -> DefaultView
  ) -> some View
  where
    ControlledViewA: ControlledView,
    ControlledViewB: ControlledView,
    ControlledViewC: ControlledView,
    ControlledViewD: ControlledView,
    ControlledViewE: ControlledView,
    DefaultView: View
  {
    switch controller {
    case let controller as ControlledViewA.Controller:
      ControlledViewA(controller: controller)
        .id(controller.viewNodeID)

    case let controller as ControlledViewB.Controller:
      ControlledViewB(controller: controller)
        .id(controller.viewNodeID)

    case let controller as ControlledViewC.Controller:
      ControlledViewC(controller: controller)
        .id(controller.viewNodeID)

    case let controller as ControlledViewD.Controller:
      ControlledViewD(controller: controller)
        .id(controller.viewNodeID)

    case let controller as ControlledViewE.Controller:
      ControlledViewE(controller: controller)
        .id(controller.viewNodeID)

    case _:
      defaultView()
    }
  }
}
