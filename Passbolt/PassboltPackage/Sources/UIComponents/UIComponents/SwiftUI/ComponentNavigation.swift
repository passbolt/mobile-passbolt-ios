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
  public static func ignored(
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

  public func present<Component>(
    _ type: Component.Type,
    animated: Bool = true,
    completion: (() -> Void)? = nil
  ) where Component: ComponentView, Component.Controller.NavigationContext == Void {
    self.sourceComponent?.present(
      type,
      animated: animated,
      completion: completion
    )
  }

  public func present<Component>(
    _ type: Component.Type,
    in context: Component.Controller.NavigationContext,
    animated: Bool = true,
    completion: (() -> Void)? = nil
  ) where Component: ComponentView {
    self.sourceComponent?.present(
      type,
      in: context,
      animated: animated,
      completion: completion
    )
  }

  public func present<Component>(
    _ type: Component.Type,
    animated: Bool = true,
    completion: (() -> Void)? = nil
  ) where Component: UIComponent, Component.Controller.Context == Void {
    self.sourceComponent?.present(
      type,
      animated: animated,
      completion: completion
    )
  }

  public func present<Component>(
    _ type: Component.Type,
    in context: Component.Controller.Context,
    animated: Bool = true,
    completion: (() -> Void)? = nil
  ) where Component: UIComponent {
    self.sourceComponent?.present(
      type,
      in: context,
      animated: animated,
      completion: completion
    )
  }

  public func presentSheet<Component>(
    _ type: Component.Type,
    animated: Bool = true,
    completion: (() -> Void)? = nil
  ) where Component: ComponentView, Component.Controller.NavigationContext == Void {
    self.sourceComponent?.presentSheet(
      type,
      animated: animated,
      completion: completion
    )
  }

  public func presentSheet<Component>(
    _ type: Component.Type,
    in context: Component.Controller.NavigationContext,
    animated: Bool = true,
    completion: (() -> Void)? = nil
  ) where Component: ComponentView {
    self.sourceComponent?.presentSheet(
      type,
      in: context,
      animated: animated,
      completion: completion
    )
  }

  public func presentSheet<Component>(
    _ type: Component.Type,
    in context: SheetViewController<Component>.Controller.Context,
    animated: Bool = true,
    completion: (() -> Void)? = nil
  ) where Component: UIComponent {
    self.sourceComponent?.presentSheet(
      type,
      in: context,
      animated: animated,
      completion: completion
    )
  }

  public func presentSheetMenu<Component>(
    _ type: Component.Type,
    in context: SheetMenuViewController<Component>.Controller.Context,
    animated: Bool = true,
    completion: (() -> Void)? = nil
  ) where Component: UIComponent {
    self.sourceComponent?.presentSheetMenu(
      type,
      in: context,
      animated: animated,
      completion: completion
    )
  }

  public func dismiss<Component>(
    _ type: Component.Type,
    animated: Bool = true,
    completion: (() -> Void)? = nil
  ) where Component: ComponentView {
    self.sourceComponent?.dismiss(
      type,
      animated: animated,
      completion: completion
    )
  }

  public func dismiss<Component>(
    _ type: Component.Type,
    animated: Bool = true,
    completion: (() -> Void)? = nil
  ) where Component: UIComponent {
    self.sourceComponent?.dismiss(
      type,
      animated: animated,
      completion: completion
    )
  }

  public func push<Component>(
    _ type: Component.Type,
    animated: Bool = true,
    completion: (() -> Void)? = nil
  ) where Component: ComponentView, Component.Controller.NavigationContext == Void {
    self.sourceComponent?.push(
      type,
      animated: animated,
      completion: completion
    )
  }

  public func push<Component>(
    _ type: Component.Type,
    in context: Component.Controller.NavigationContext,
    animated: Bool = true,
    completion: (() -> Void)? = nil
  ) where Component: ComponentView {
    self.sourceComponent?.push(
      type,
      in: context,
      animated: animated,
      completion: completion
    )
  }

  public func push<Component>(
    _ type: Component.Type,
    animated: Bool = true,
    completion: (() -> Void)? = nil
  ) where Component: UIComponent, Component.Controller.Context == Void {
    self.sourceComponent?.push(
      type,
      animated: animated,
      completion: completion
    )
  }

  public func push<Component>(
    _ type: Component.Type,
    in context: Component.Controller.Context,
    animated: Bool = true,
    completion: (() -> Void)? = nil
  ) where Component: UIComponent {
    self.sourceComponent?.push(
      type,
      in: context,
      animated: animated,
      completion: completion
    )
  }

  public func pop<Component>(
    if type: Component.Type,
    animated: Bool = true,
    completion: (() -> Void)? = nil
  ) where Component: ComponentView {
    self.sourceComponent?.pop(
      if: type,
      animated: animated,
      completion: completion
    )
  }

  @discardableResult
  public func pop<Component>(
    if type: Component.Type,
    animated: Bool = true,
    completion: (() -> Void)? = nil
  ) -> Bool
  where Component: UIComponent {
    self.sourceComponent?.pop(
      if: type,
      animated: animated,
      completion: completion
    )
      ?? false
  }

  public func pop<Component>(
    to type: Component.Type,
    animated: Bool = true,
    completion: (() -> Void)? = nil
  ) where Component: ComponentView {
    self.sourceComponent?.pop(
      to: type,
      animated: animated,
      completion: completion
    )
  }

  @discardableResult
  public func pop<Component>(
    to type: Component.Type,
    animated: Bool = true,
    completion: (() -> Void)? = nil
  ) -> Bool
  where Component: UIComponent {
    self.sourceComponent?.pop(
      to: type,
      animated: animated,
      completion: completion
    )
      ?? false
  }

  public func popAll<Component>(
    _ type: Component.Type,
    animated: Bool = true,
    completion: (() -> Void)? = nil
  ) where Component: ComponentView {
    self.sourceComponent?.popAll(
      type,
      animated: animated,
      completion: completion
    )
  }

  public func popAll<Component>(
    _ type: Component.Type,
    animated: Bool = true,
    completion: (() -> Void)? = nil
  ) where Component: UIComponent {
    self.sourceComponent?.popAll(
      type,
      animated: animated,
      completion: completion
    )
  }

  public func popToRoot(
    animated: Bool = true,
    completion: (() -> Void)? = nil
  ) {
    self.sourceComponent?.popToRoot(
      animated: animated,
      completion: completion
    )
  }

  @discardableResult
  public func replaceLast<Replaced, Replacement>(
    _ replaced: Replaced.Type,
    with replacement: Replacement.Type,
    animated: Bool = true,
    completion: (() -> Void)? = nil
  ) -> Bool
  where Replaced: UIComponent, Replacement: UIComponent, Replacement.Controller.Context == Void {
    self.sourceComponent?.replaceLast(
      replaced,
      with: replacement,
      animated: animated,
      completion: completion
    )
      ?? false
  }

  @discardableResult
  public func replaceLast<Replaced, Replacement>(
    _ replaced: Replaced.Type,
    with replacement: Replacement.Type,
    in context: Replacement.Controller.Context,
    animated: Bool = true,
    completion: (() -> Void)? = nil
  ) -> Bool
  where Replaced: UIComponent, Replacement: UIComponent {
    self.sourceComponent?.replaceLast(
      replaced,
      with: replacement,
      in: context,
      animated: animated,
      completion: completion
    )
      ?? false
  }
}
