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

import UIComponents  // LegacyBridge only

@available(*, deprecated, message: "Please switch to `NavigationTree`")
public struct DisplayNavigation {

  internal var legacyBridge: LegacyNavigationBridge
}

extension DisplayNavigation: LoadableContextlessFeature {

  #if DEBUG
  public static var placeholder: Self {
    .init(
      legacyBridge: .placeholder
    )
  }
  #endif
}

extension DisplayNavigation {

  @MainActor public func push<PushedLegacyComponent>(
    legacy type: PushedLegacyComponent.Type
  ) async where PushedLegacyComponent: UIComponent, PushedLegacyComponent.Controller.Context == Void {
    await self.legacyBridge
      .bridgeComponent()?
      .push(
        PushedLegacyComponent.self,
        animated: true
      )
  }

  @MainActor public func push<PushedLegacyComponent>(
    legacy type: PushedLegacyComponent.Type,
    context: PushedLegacyComponent.Controller.Context
  ) async where PushedLegacyComponent: UIComponent {
    await self.legacyBridge
      .bridgeComponent()?
      .push(
        PushedLegacyComponent.self,
        in: context,
        animated: true
      )
  }

  @MainActor public func push<PushedView>(
    _ type: PushedView.Type,
    controller: PushedView.Controller
  ) async where PushedView: ControlledView {
    await self.legacyBridge
      .bridgeComponent()?
      .push(
        DisplayViewBridge<PushedView>.self,
        in: controller,
        animated: true
      )
  }

  @MainActor public func pop<PushedView>(
    _ type: PushedView.Type
  ) async where PushedView: ControlledView {
    await self.legacyBridge
      .bridgeComponent()?
      .pop(
        if: DisplayViewBridge<PushedView>.self,
        animated: true
      )
  }

  @MainActor public func dismiss<PushedView>(
    _ type: PushedView.Type
  ) async where PushedView: ControlledView {
    await self.legacyBridge
      .bridgeComponent()?
      .dismiss(
        DisplayViewBridge<PushedView>.self,
        animated: true
      )
  }

  @MainActor public func presentLegacySheet<DisplayComponent>(
    _ type: DisplayComponent.Type,
    controller: DisplayComponent.Controller,
    animated: Bool = true
  ) async where DisplayComponent: ControlledView {
    await self.legacyBridge
      .bridgeComponent()?
      .presentSheet(
        DisplayViewBridge<DisplayComponent>.self,
        in: controller,
        animated: animated
      )
  }

  @MainActor public func dismissLegacySheet<DisplayComponent>(
    _ type: DisplayComponent.Type,
    animated: Bool = true
  ) async where DisplayComponent: ControlledView {
    await self.legacyBridge
      .bridgeComponent()?
      .dismiss(
        SheetViewController<DisplayViewBridge<DisplayComponent>>.self,
        animated: animated
      )
  }

  @MainActor public func presentInfoSnackbar(
    _ displayable: DisplayableString,
    with arguments: Array<CVarArg> = .init()
  ) async {
    await self.legacyBridge
      .bridgeComponent()?
      .presentInfoSnackbar(
        displayable,
        with: arguments
      )
  }
}

extension DisplayNavigation {

  fileprivate static func load(
    features: FeatureFactory,
    cancellables: Cancellables
  ) async throws -> Self {
    unowned let features: FeatureFactory = features
    let legacyBridge: LegacyNavigationBridge = try await features.instance()

    return DisplayNavigation(
      legacyBridge: legacyBridge
    )
  }
}

extension FeatureFactory {

  internal func useLiveDisplayNavigation() {
    self.use(
      .lazyLoaded(
        DisplayNavigation.self,
        load: DisplayNavigation.load(features:cancellables:)
      )
    )
  }
}
