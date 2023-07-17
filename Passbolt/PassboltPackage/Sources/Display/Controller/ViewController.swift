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

  associatedtype ViewState: Equatable = Stateless
  associatedtype Context = Void

  nonisolated var viewState: ViewStateSource<ViewState> { get }

  @MainActor init(
    context: Context,
    features: Features
  ) throws

  @available(*, deprecated, message: "Do not use viewNodeID to identify views. Legacy use only!")
  nonisolated var viewNodeID: ViewNodeID { get }
}

extension ViewController {

  @available(*, deprecated, message: "Do not use viewNodeID to identify views. Legacy use only!")
  public nonisolated var viewNodeID: ViewNodeID {
    .init(rawValue: ObjectIdentifier(self))
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
    return self === other
  }

  public nonisolated func hash(
    into hasher: inout Hasher
  ) {
    hasher.combine(self)
  }
}

extension ViewController
where ViewState == Stateless {

  public nonisolated var viewState: ViewStateSource<Stateless> {
    ViewStateSource<Stateless>()
  }
}

extension ViewController {

  @MainActor internal func binding<Value>(
    to keyPath: WritableKeyPath<ViewState, Value>,
    updating setter: @escaping @MainActor (Value) -> Void
  ) -> Binding<Value> {
    .init(
      get: { @MainActor in
        self.viewState.value[keyPath: keyPath]
      },
      set: { @MainActor [setter] (newValue: Value) in
        // quick loop - update local state immediately to prevent SwiftUI issues
        self.viewState.value[keyPath: keyPath] = newValue
        setter(newValue)  // then pass the update to actual source of data
      }
    )
  }

  @MainActor internal func optionalBinding<Value>(
    to keyPath: WritableKeyPath<ViewState, Value?>,
    default: Value,
    updating setter: @escaping @MainActor (Value) -> Void
  ) -> Binding<Value> {
    .init(
      get: { @MainActor in
        self.viewState.value[keyPath: keyPath] ?? `default`
      },
      set: { @MainActor [setter] (newValue: Value) in
        // quick loop - update local state immediately to prevent SwiftUI issues
        self.viewState.value[keyPath: keyPath] = newValue
        setter(newValue)  // then pass the update to actual source of data
      }
    )
  }

  @MainActor internal func validatedBinding<Value>(
    to keyPath: WritableKeyPath<ViewState, Validated<Value>>,
    updating setter: @escaping @MainActor (Value) -> Void
  ) -> Binding<Validated<Value>> {
    .init(
      get: { @MainActor in
        self.viewState.value[keyPath: keyPath]
      },
      set: { @MainActor [setter] (newValue: Validated<Value>) in
        // quick loop - update local state immediately to prevent SwiftUI issues
        self.viewState.value[keyPath: keyPath] = newValue
        setter(newValue.value)  // then pass the update to actual source of data
      }
    )
  }

  @MainActor internal func validatedOptionalBinding<Value>(
    to keyPath: WritableKeyPath<ViewState, Validated<Value>?>,
    default: Validated<Value>,
    updating setter: @escaping @MainActor (Value) -> Void
  ) -> Binding<Validated<Value>> {
    .init(
      get: { @MainActor in
        self.viewState.value[keyPath: keyPath] ?? `default`
      },
      set: { @MainActor [setter] (newValue: Validated<Value>) in
        // quick loop - update local state immediately to prevent SwiftUI issues
        self.viewState.value[keyPath: keyPath] = newValue
        setter(newValue.value)  // then pass the update to actual source of data
      }
    )
  }

  @MainActor internal func validatedOptionalBinding<MidValue, Value>(
    to nestedKeyPath: WritableKeyPath<MidValue, Validated<Value>>,
    in keyPath: WritableKeyPath<ViewState, MidValue?>,
    default: Validated<Value>,
    updating setter: @escaping @MainActor (Value) -> Void
  ) -> Binding<Validated<Value>> {
    .init(
      get: { @MainActor in
        self.viewState.value[keyPath: keyPath]?[keyPath: nestedKeyPath] ?? `default`
      },
      set: { @MainActor [setter] (newValue: Validated<Value>) in
        // quick loop - update local state immediately to prevent SwiftUI issues
        self.viewState.value[keyPath: keyPath]?[keyPath: nestedKeyPath] = newValue
        setter(newValue.value)  // then pass the update to actual source of data
      }
    )
  }

  @MainActor internal func validatedBinding<Value, Tag>(
    to keyPath: WritableKeyPath<ViewState, Validated<Tagged<Value, Tag>>>,
    updating setter: @escaping @MainActor (Tagged<Value, Tag>) -> Void
  ) -> Binding<Validated<Value>> {
    return .init(
      get: { @MainActor in
        self.viewState.value[keyPath: keyPath].map(\.rawValue)
      },
      set: { @MainActor [setter] (newValue: Validated<Value>) in
        // quick loop - update local state immediately to prevent SwiftUI issues
        let tagged: Validated<Tagged<Value, Tag>> = newValue.map(Tagged<Value, Tag>.init(rawValue:))
        self.viewState.value[keyPath: keyPath] = tagged
        setter(tagged.value)  // then pass the update to actual source of data
      }
    )
  }

  @MainActor internal func binding<Value>(
    to keyPath: WritableKeyPath<ViewState, Value>
  ) -> Binding<Value> {
    Binding<Value>(
      get: { self.viewState.value[keyPath: keyPath] },
      set: { (newValue: Value) in
        self.viewState.value[keyPath: keyPath] = newValue
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
