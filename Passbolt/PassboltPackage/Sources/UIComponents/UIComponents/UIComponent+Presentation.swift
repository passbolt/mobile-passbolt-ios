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
import UIKit

extension AnyUIComponent {

  @MainActor public func replaceWindowRoot<Component>(
    with type: Component.Type,
    animated: Bool = true
  ) async where Component: UIComponent, Component.Controller.Context == Void {
    await replaceWindowRoot(
      with: type,
      in: Void(),
      animated: animated
    )
  }

  @MainActor public func replaceWindowRoot<Component>(
    with type: Component.Type,
    in context: Component.Controller.Context,
    animated: Bool = true
  ) async where Component: UIComponent {
    guard let window: UIWindow = self.view.window
    else { return assertionFailure("Cannot replace window root without window") }

    let currentView: UIView? = window.rootViewController?.view
    do {
      window.rootViewController =
        try self.components
        .instance(
          of: Component.self,
          in: context
        )
    }
    catch {
      error
        .asTheError()
        .asAssertionFailure()
      return
    }

    return await withCheckedContinuation { continuation in
      UIView.transition(
        with: window,
        duration: animated ? 0.3 : 0,
        options: [.transitionCrossDissolve],
        animations: {
          currentView?.alpha = 0
        },
        completion: { _ in
          continuation.resume()
        }
      )
    }
  }

  @MainActor public func replaceNavigationRoot<Component>(
    with type: Component.Type,
    animated: Bool = true
  ) async where Component: UIComponent, Component.Controller.Context == Void {
    await replaceNavigationRoot(
      with: type,
      in: Void(),
      animated: animated
    )
  }

  @MainActor public func replaceNavigationRoot<Component>(
    with type: Component.Type,
    animated: Bool = true
  ) async where Component: ComponentView, Component.Controller.Context == Void {
    await self.replaceNavigationRoot(
      with: type,
      in: Void(),
      animated: animated
    )
  }

  @MainActor public func replaceNavigationRoot<Component>(
    with type: Component.Type,
    in context: Component.Controller.Context,
    animated: Bool = true
  ) async where Component: UIComponent {
    guard
      let navigationController = self as? UINavigationController
        ?? self.navigationController
        ?? self.presentingViewController?.navigationController
    else { return assertionFailure("It is programmer error to replace navigation without navigation controller") }

    let component: Component
    do {
      component =
        try self.components
        .instance(
          of: Component.self,
          in: context
        )
    }
    catch {
      error
        .asTheError()
        .asAssertionFailure()
      return
    }

    return await withCheckedContinuation { continuation in
      CATransaction.begin()
      CATransaction.setCompletionBlock {
        continuation.resume()
      }
      navigationController
        .setViewControllers(
          [component],
          animated: animated
        )
      CATransaction.commit()
    }
  }

  @MainActor public func replaceNavigationRoot<Component>(
    with type: Component.Type,
    in context: Component.Controller.Context,
    animated: Bool = true
  ) async where Component: ComponentView {
    await self.replaceNavigationRoot(
      with: ComponentHostingViewController<Component>.self,
      in: context,
      animated: animated
    )
  }

  @MainActor public func present<Component>(
    _ type: Component.Type,
    animated: Bool = true
  ) async where Component: ComponentView, Component.Controller.Context == Void {
    await self.present(
      ComponentHostingViewController<Component>.self,
      animated: animated
    )
  }

  @MainActor public func present<Component>(
    _ type: Component.Type,
    animated: Bool = true
  ) async where Component: UIComponent, Component.Controller.Context == Void {
    await self.present(
      type,
      in: Void(),
      animated: animated
    )
  }

  @MainActor public func present<Component>(
    _ type: Component.Type,
    in context: Component.Controller.Context,
    animated: Bool = true
  ) async where Component: ComponentView {
    await self.present(
      ComponentHostingViewController<Component>.self,
      in: context,
      animated: animated
    )
  }

  @MainActor public func present<Component>(
    _ type: Component.Type,
    in context: Component.Controller.Context,
    animated: Bool = true
  ) async where Component: UIComponent {
    var presentedLeaf: UIViewController = self
    while let next: UIViewController = presentedLeaf.presentedViewController {
      presentedLeaf = next
    }

    let component: Component
    do {
      component =
        try await self.components
        .instance(
          of: Component.self,
          in: context
        )
    }
    catch {
      error
        .asTheError()
        .asAssertionFailure()
      return
    }

    return await withCheckedContinuation { continuation in
      presentedLeaf.present(
        component,
        animated: animated,
        completion: {
          continuation.resume()
        }
      )
    }
  }

  @MainActor public func dismiss<Component>(
    _ type: Component.Type,
    animated: Bool = true
  ) async where Component: ComponentView {
    await self.dismiss(
      ComponentHostingViewController<Component>.self,
      animated: animated
    )
  }

  @MainActor public func dismiss<Component>(
    _: Component.Type,
    animated: Bool = true
  ) async where Component: UIComponent {
    var current: UIViewController = self
    repeat {
      if current is Component
        || (current as? UINavigationController)?.viewControllers.contains(where: { $0 is Component }) ?? false
      {
        return await withCheckedContinuation { continuation in
          current
            .presentingViewController?
            .dismiss(
              animated: animated,
              completion: {
                continuation.resume()
              }
            )
            ?? Void()
        }
      }
      else if let next: UIViewController = current.presentedViewController {
        current = next
      }
      else {
        break
      }
    } while true
  }

  @MainActor public func push<Component>(
    _ type: Component.Type,
    animated: Bool = true
  ) async where Component: ComponentView, Component.Controller.Context == Void {
    await self.push(
      ComponentHostingViewController<Component>.self,
      animated: animated
    )
  }

  @MainActor public func push<Component>(
    _ type: Component.Type,
    animated: Bool = true
  ) async where Component: UIComponent, Component.Controller.Context == Void {
    await push(
      type,
      in: Void(),
      animated: animated
    )
  }

  @MainActor public func push<Component>(
    _ type: Component.Type,
    in context: Component.Controller.Context,
    animated: Bool = true
  ) async where Component: ComponentView {
    await self.push(
      ComponentHostingViewController<Component>.self,
      in: context,
      animated: animated
    )
  }

  @MainActor public func push<Component>(
    _ type: Component.Type,
    in context: Component.Controller.Context,
    animated: Bool = true
  ) async where Component: UIComponent {
    guard
      let navigationController = self as? UINavigationController
        ?? self.navigationController
        ?? self.presentingViewController?.navigationController
    else { return assertionFailure("It is programmer error to push without navigation controller") }
    let component: Component
    do {
      component =
        try self.components
        .instance(
          of: Component.self,
          in: context
        )
    }
    catch {
      error
        .asTheError()
        .asAssertionFailure()
      return
    }

    return await withCheckedContinuation { continuation in
      CATransaction.begin()
      CATransaction.setCompletionBlock {
        continuation.resume()
      }
      navigationController
        .pushViewController(
          component,
          animated: animated
        )
      CATransaction.commit()
    }
  }

  @MainActor public func push<V>(
    _ view: V,
    animated: Bool = true
  ) async where V: SwiftUI.View {
    guard
      let navigationController = self as? UINavigationController
        ?? self.navigationController
        ?? self.presentingViewController?.navigationController
    else { return assertionFailure("It is programmer error to push without navigation controller") }

    return await withCheckedContinuation { continuation in
      CATransaction.begin()
      CATransaction.setCompletionBlock {
        continuation.resume()
      }
      navigationController
        .pushViewController(
          UIHostingController(rootView: view),
          animated: animated
        )
      CATransaction.commit()
    }
  }
}
