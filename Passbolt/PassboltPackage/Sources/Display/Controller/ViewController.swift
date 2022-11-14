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

  var viewState: ViewStateBinding<ViewState> { get }
}

extension ViewController {

  public var id: ObjectIdentifier {
    ObjectIdentifier(self.viewState)
  }
}

extension ViewController /* Hashable */ {

  public static func == (
    _ lhs: Self,
    _ rhs: Self
  ) -> Bool {
    lhs.id == rhs.id
  }

  public func equal (
    to other: any ViewController
  ) -> Bool {
    func equal<LHS: ViewController>(
      _ lhs: LHS,
      _ rhs: any ViewController
    ) -> Bool {
      lhs.id == (rhs as? LHS)?.id
    }

    return equal(self, other)
  }

  public func hash(
    into hasher: inout Hasher
  ) {
    hasher.combine(self.id)
  }
}

extension ViewController {

  @MainActor public func binding<Value>(
    to keyPath: WritableKeyPath<ViewState, Value>
  ) -> Binding<Value> {
    self.viewState.binding(to: keyPath)
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
        .id(controller.id)

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
        .id(controller.id)

    case let controller as ControlledViewB.Controller:
      ControlledViewB(controller: controller)
        .id(controller.id)

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
  where ControlledViewA: ControlledView, ControlledViewB: ControlledView, ControlledViewC: ControlledView, DefaultView: View {
    switch controller {
    case let controller as ControlledViewA.Controller:
      ControlledViewA(controller: controller)
        .id(controller.id)

    case let controller as ControlledViewB.Controller:
      ControlledViewB(controller: controller)
        .id(controller.id)

    case let controller as ControlledViewC.Controller:
      ControlledViewC(controller: controller)
        .id(controller.id)

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
  where ControlledViewA: ControlledView, ControlledViewB: ControlledView, ControlledViewC: ControlledView, ControlledViewD: ControlledView,  DefaultView: View {
    switch controller {
    case let controller as ControlledViewA.Controller:
      ControlledViewA(controller: controller)
        .id(controller.id)

    case let controller as ControlledViewB.Controller:
      ControlledViewB(controller: controller)
        .id(controller.id)

    case let controller as ControlledViewC.Controller:
      ControlledViewC(controller: controller)
        .id(controller.id)

    case let controller as ControlledViewD.Controller:
      ControlledViewD(controller: controller)
        .id(controller.id)

    case _:
      defaultView()
    }
  }

  @ViewBuilder public static func by<ControlledViewA, ControlledViewB, ControlledViewC, ControlledViewD, ControlledViewE, DefaultView>(
    _ controller: any ViewController,
    view: ControlledViewA.Type,
    or _: ControlledViewB.Type,
    or _: ControlledViewC.Type,
    or _: ControlledViewD.Type,
    or _: ControlledViewE.Type,
    @ViewBuilder orDefault defaultView: () -> DefaultView
  ) -> some View
  where ControlledViewA: ControlledView, ControlledViewB: ControlledView, ControlledViewC: ControlledView, ControlledViewD: ControlledView, ControlledViewE: ControlledView, DefaultView: View {
    switch controller {
    case let controller as ControlledViewA.Controller:
      ControlledViewA(controller: controller)
        .id(controller.id)

    case let controller as ControlledViewB.Controller:
      ControlledViewB(controller: controller)
        .id(controller.id)

    case let controller as ControlledViewC.Controller:
      ControlledViewC(controller: controller)
        .id(controller.id)

    case let controller as ControlledViewD.Controller:
      ControlledViewD(controller: controller)
        .id(controller.id)

    case let controller as ControlledViewE.Controller:
      ControlledViewE(controller: controller)
        .id(controller.id)

    case _:
      defaultView()
    }
  }
}
