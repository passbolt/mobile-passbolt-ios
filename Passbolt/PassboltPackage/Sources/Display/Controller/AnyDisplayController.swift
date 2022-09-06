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

import CommonModels

public struct AnyDisplayController: ContextlessDisplayController {

  public typealias ViewState = HashableVoid

  public let viewState: DisplayViewState<HashableVoid>
  private let controllerType: Any.Type
  private let controller: Any

  #if DEBUG
  public static var placeholder: AnyDisplayController {
    unimplemented("There is no placeholder for AnyDisplayController, wrap any concrete controller instead.")
  }
  #endif
}

extension AnyDisplayController {

  public init<Controller>(
    erasing controller: Controller
  ) where Controller: DisplayController {
    self.controllerType = Controller.self
    self.controller = controller
    self.viewState = .init(initial: HashableVoid())
  }

  @ViewBuilder public func controlling<ControlledView, DefaultView>(
    _ viewType: ControlledView.Type,
    @ViewBuilder default defaultView: () -> DefaultView
  ) -> some View
  where ControlledView: DisplayView, DefaultView: View {
    switch self.controller {
    case let controller as ControlledView.Controller:
      ControlledView(controller: controller)
        .id(self)

    case _:
      defaultView()
        .id(self)
    }
  }

  @ViewBuilder public func controlling<ControlledViewA, ControlledViewB, DefaultView>(
    _ viewTypeA: ControlledViewA.Type,
    or viewTypeB: ControlledViewB.Type,
    @ViewBuilder default defaultView: () -> DefaultView
  ) -> some View
  where ControlledViewA: DisplayView, ControlledViewB: DisplayView, DefaultView: View {
    switch self.controller {
    case let controller as ControlledViewA.Controller:
      ControlledViewA(controller: controller)
        .id(self)

    case let controller as ControlledViewB.Controller:
      ControlledViewB(controller: controller)
        .id(self)

    case _:
      defaultView()
        .id(self)
    }
  }

  @ViewBuilder public func controlling<ControlledViewA, ControlledViewB, ControlledViewC, DefaultView>(
    _ viewTypeA: ControlledViewA.Type,
    or viewTypeB: ControlledViewB.Type,
    or viewTypeC: ControlledViewC.Type,
    @ViewBuilder default defaultView: () -> DefaultView
  ) -> some View
  where ControlledViewA: DisplayView, ControlledViewB: DisplayView, ControlledViewC: DisplayView, DefaultView: View {
    switch self.controller {
    case let controller as ControlledViewA.Controller:
      ControlledViewA(controller: controller)
        .id(self)

    case let controller as ControlledViewB.Controller:
      ControlledViewB(controller: controller)
        .id(self)

    case let controller as ControlledViewC.Controller:
      ControlledViewC(controller: controller)
        .id(self)

    case _:
      defaultView()
        .id(self)
    }
  }

  @ViewBuilder public func controlling<ControlledViewA, ControlledViewB, ControlledViewC, ControlledViewD, DefaultView>(
    _ viewTypeA: ControlledViewA.Type,
    or viewTypeB: ControlledViewB.Type,
    or viewTypeC: ControlledViewC.Type,
    or viewTypeD: ControlledViewD.Type,
    @ViewBuilder default defaultView: () -> DefaultView
  ) -> some View
  where
    ControlledViewA: DisplayView, ControlledViewB: DisplayView, ControlledViewC: DisplayView,
    ControlledViewD: DisplayView, DefaultView: View
  {
    switch self.controller {
    case let controller as ControlledViewA.Controller:
      ControlledViewA(controller: controller)
        .id(self)

    case let controller as ControlledViewB.Controller:
      ControlledViewB(controller: controller)
        .id(self)

    case let controller as ControlledViewC.Controller:
      ControlledViewC(controller: controller)
        .id(self)

    case let controller as ControlledViewD.Controller:
      ControlledViewD(controller: controller)
        .id(self)

    case _:
      defaultView()
        .id(self)
    }
  }

  @ViewBuilder
  public func controlling<
    ControlledViewA,
    ControlledViewB,
    ControlledViewC,
    ControlledViewD,
    ControlledViewE,
    DefaultView
  >(
    _ viewTypeA: ControlledViewA.Type,
    or viewTypeB: ControlledViewB.Type,
    or viewTypeC: ControlledViewC.Type,
    or viewTypeD: ControlledViewD.Type,
    or viewTypeE: ControlledViewE.Type,
    @ViewBuilder default defaultView: () -> DefaultView
  ) -> some View
  where
    ControlledViewA: DisplayView, ControlledViewB: DisplayView, ControlledViewC: DisplayView,
    ControlledViewD: DisplayView, ControlledViewE: DisplayView, DefaultView: View
  {
    switch self.controller {
    case let controller as ControlledViewA.Controller:
      ControlledViewA(controller: controller)
        .id(self)

    case let controller as ControlledViewB.Controller:
      ControlledViewB(controller: controller)
        .id(self)

    case let controller as ControlledViewC.Controller:
      ControlledViewC(controller: controller)
        .id(self)

    case let controller as ControlledViewD.Controller:
      ControlledViewD(controller: controller)
        .id(self)

    case let controller as ControlledViewE.Controller:
      ControlledViewE(controller: controller)
        .id(self)

    case _:
      defaultView()
        .id(self)
    }
  }
}
