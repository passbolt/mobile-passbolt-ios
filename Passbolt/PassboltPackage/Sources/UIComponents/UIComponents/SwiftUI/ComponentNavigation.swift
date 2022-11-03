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

import UICommons

@available(*, deprecated)
@MainActor
public struct ComponentNavigation<Context> {

  nonisolated public let context: Context
  private weak var sourceComponent: AnyUIComponent?

  internal nonisolated init(
    context: Context,
    sourceComponent: AnyUIComponent?
  ) {
    self.context = context
    self.sourceComponent = sourceComponent
  }

  #if DEBUG
  /// Placeholder for SwiftUI previews
  public nonisolated static func ignored(
    with context: Context
  ) -> Self {
    .init(
      context: context,
      sourceComponent: .none
    )
  }
  #endif
}

extension ComponentNavigation {

  public func asContextlessNavigation() -> ComponentNavigation<Void> {
    .init(
      context: Void(),
      sourceComponent: self.sourceComponent
    )
  }
}

extension AnyUIComponent {

  public func asComponentNavigation() -> ComponentNavigation<Void> {
    .init(
      context: Void(),
      sourceComponent: self
    )
  }
}

extension ComponentNavigation {

  @MainActor public func present<Component>(
    _ type: Component.Type,
    animated: Bool = true
  ) async where Component: ComponentView, Component.Controller.NavigationContext == Void {
    await self.sourceComponent?.present(
      type,
      animated: animated
    )
  }

  @MainActor public func present<Component>(
    _ type: Component.Type,
    in context: Component.Controller.NavigationContext,
    animated: Bool = true
  ) async where Component: ComponentView {
    await self.sourceComponent?.present(
      type,
      in: context,
      animated: animated
    )
  }

  @_disfavoredOverload
  @MainActor public func present<Component>(
    _ type: Component.Type,
    animated: Bool = true
  ) async where Component: UIComponent, Component.Controller.Context == Void {
    await self.sourceComponent?.present(
      type,
      animated: animated
    )
  }

  @_disfavoredOverload
  @MainActor public func present<Component>(
    _ type: Component.Type,
    in context: Component.Controller.Context,
    animated: Bool = true
  ) async where Component: UIComponent {
    await self.sourceComponent?.present(
      type,
      in: context,
      animated: animated
    )
  }

  @MainActor public func presentSheet<Component>(
    _ type: Component.Type,
    animated: Bool = true
  ) async where Component: ComponentView, Component.Controller.NavigationContext == Void {
    await self.sourceComponent?.presentSheet(
      type,
      animated: animated
    )
  }

  @MainActor public func presentSheet<Component>(
    _ type: Component.Type,
    in context: Component.Controller.NavigationContext,
    animated: Bool = true
  ) async where Component: ComponentView {
    await self.sourceComponent?.presentSheet(
      type,
      in: context,
      animated: animated
    )
  }

  @_disfavoredOverload
  @MainActor public func presentSheet<Component>(
    _ type: Component.Type,
    in context: SheetViewController<Component>.Controller.Context,
    animated: Bool = true
  ) async where Component: UIComponent {
    await self.sourceComponent?.presentSheet(
      type,
      in: context,
      animated: animated
    )
  }

  @_disfavoredOverload
  @MainActor public func presentSheetMenu<Component>(
    _ type: Component.Type,
    in context: SheetMenuViewController<Component>.Controller.Context,
    animated: Bool = true
  ) async where Component: UIComponent {
    await self.sourceComponent?.presentSheetMenu(
      type,
      in: context,
      animated: animated
    )
  }

  @MainActor public func dismiss<Component>(
    _ type: Component.Type,
    animated: Bool = true
  ) async where Component: ComponentView {
    await self.sourceComponent?.dismiss(
      type,
      animated: animated
    )
  }

  @_disfavoredOverload
  @MainActor public func dismiss<Component>(
    _ type: Component.Type,
    animated: Bool = true
  ) async where Component: UIComponent {
    await self.sourceComponent?.dismiss(
      type,
      animated: animated
    )
  }

  @MainActor public func push<Component>(
    _ type: Component.Type,
    animated: Bool = true
  ) async where Component: ComponentView, Component.Controller.NavigationContext == Void {
    await self.sourceComponent?.push(
      type,
      animated: animated
    )
  }

  @MainActor public func push<Component>(
    _ type: Component.Type,
    in context: Component.Controller.NavigationContext,
    animated: Bool = true
  ) async where Component: ComponentView {
    await self.sourceComponent?.push(
      type,
      in: context,
      animated: animated
    )
  }

  @MainActor public func replace<Component, ReplacedComponent>(
    _: ReplacedComponent.Type,
    pushing type: Component.Type,
    animated: Bool = true
  ) async
  where Component: ComponentView, Component.Controller.NavigationContext == Void, ReplacedComponent: ComponentView {
    await self.sourceComponent?
      .replace(
        ReplacedComponent.self,
        pushing: Component.self,
        animated: animated
      )
  }

  @MainActor public func replace<Component, ReplacedComponent>(
    _: ReplacedComponent.Type,
    pushing type: Component.Type,
    in context: Component.Controller.NavigationContext,
    animated: Bool = true
  ) async where Component: ComponentView, ReplacedComponent: ComponentView {
    await self.sourceComponent?
      .replace(
        ReplacedComponent.self,
        pushing: Component.self,
        in: context,
        animated: animated
      )
  }

  @_disfavoredOverload
  @MainActor public func push<Component>(
    _ type: Component.Type,
    animated: Bool = true
  ) async where Component: UIComponent, Component.Controller.Context == Void {
    await self.sourceComponent?.push(
      type,
      animated: animated
    )
  }

  @_disfavoredOverload
  @MainActor public func push<Component>(
    _ type: Component.Type,
    in context: Component.Controller.Context,
    animated: Bool = true
  ) async where Component: UIComponent {
    await self.sourceComponent?.push(
      type,
      in: context,
      animated: animated
    )
  }

  @MainActor public func pop<Component>(
    if type: Component.Type,
    animated: Bool = true
  ) async where Component: ComponentView {
    await self.sourceComponent?.pop(
      if: type,
      animated: animated
    )
  }

  @_disfavoredOverload
  @MainActor public func pop<Component>(
    if type: Component.Type,
    animated: Bool = true
  ) async where Component: UIComponent {
    await self.sourceComponent?.pop(
      if: type,
      animated: animated
    )
  }

  @MainActor public func pop<Component>(
    to type: Component.Type,
    animated: Bool = true
  ) async where Component: ComponentView {
    await self.sourceComponent?.pop(
      to: type,
      animated: animated
    )
  }

  @_disfavoredOverload
  @MainActor public func pop<Component>(
    to type: Component.Type,
    animated: Bool = true
  ) async where Component: UIComponent {
    await self.sourceComponent?.pop(
      to: type,
      animated: animated
    )
  }

  @MainActor public func popAll<Component>(
    _ type: Component.Type,
    animated: Bool = true
  ) async where Component: ComponentView {
    await self.sourceComponent?.popAll(
      type,
      animated: animated
    )
  }

  @_disfavoredOverload
  @MainActor public func popAll<Component>(
    _ type: Component.Type,
    animated: Bool = true
  ) async where Component: UIComponent {
    await self.sourceComponent?.popAll(
      type,
      animated: animated
    )
  }

  @MainActor public func popToRoot(
    animated: Bool = true
  ) async {
    await self.sourceComponent?.popToRoot(
      animated: animated
    )
  }

  @_disfavoredOverload
  @MainActor public func replaceLast<Replaced, Replacement>(
    _ replaced: Replaced.Type,
    with replacement: Replacement.Type,
    animated: Bool = true
  ) async where Replaced: UIComponent, Replacement: UIComponent, Replacement.Controller.Context == Void {
    await self.sourceComponent?.replaceLast(
      replaced,
      with: replacement,
      animated: animated
    )
  }

  @_disfavoredOverload
  @MainActor public func replaceLast<Replaced, Replacement>(
    _ replaced: Replaced.Type,
    with replacement: Replacement.Type,
    in context: Replacement.Controller.Context,
    animated: Bool = true
  ) async where Replaced: UIComponent, Replacement: UIComponent {
    await self.sourceComponent?.replaceLast(
      replaced,
      with: replacement,
      in: context,
      animated: animated
    )
  }

  @MainActor public func present(
    snackbar: UIView,
    presentationMode: SnackbarPresentationMode = .local,
    hideAfter hideDelay: TimeInterval = 3,  // zero is not going to hide automatically
    replaceCurrent: Bool = true,  // presentation will be ignored if set to false and other is presented
    animated: Bool = true
  ) {
    self.sourceComponent?.present(
      snackbar: snackbar,
      presentationMode: presentationMode,
      hideAfter: hideDelay,
      replaceCurrent: replaceCurrent,
      animated: animated
    )
  }
}
