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
    animated: Bool = true,
    completion: (() -> Void)? = nil
  ) async where Component: UIComponent, Component.Controller.Context == Void {
    await replaceWindowRoot(
      with: type,
      in: Void(),
      animated: animated,
      completion: completion
    )
  }

  @MainActor public func replaceWindowRoot<Component>(
    with type: Component.Type,
    in context: Component.Controller.Context,
    animated: Bool = true,
    completion: (() -> Void)? = nil
  ) async where Component: UIComponent {
    guard let window: UIWindow = self.view.window
    else { return assertionFailure("Cannot replace window root without window") }

    let currentView: UIView? = window.rootViewController?.view
    window.rootViewController =
      await self.components
      .instance(
        of: Component.self,
        in: context
      )

    return await withCheckedContinuation { continuation in
      UIView.transition(
        with: window,
        duration: animated ? 0.3 : 0,
        options: [.transitionCrossDissolve],
        animations: {
          currentView?.alpha = 0
        },
        completion: { _ in
          completion?()
          continuation.resume()
        }
      )
    }
  }

  @MainActor public func replaceNavigationRoot<Component>(
    with type: Component.Type,
    animated: Bool = true,
    completion: (() -> Void)? = nil
  ) async where Component: UIComponent, Component.Controller.Context == Void {
    await replaceNavigationRoot(
      with: type,
      in: Void(),
      animated: animated,
      completion: completion
    )
  }

  @MainActor public func replaceNavigationRoot<Component>(
    with type: Component.Type,
    animated: Bool = true,
    completion: (() -> Void)? = nil
  ) async where Component: ComponentView, Component.Controller.NavigationContext == Void {
    await self.replaceNavigationRoot(
      with: type,
      in: Void(),
      animated: animated,
      completion: completion
    )
  }

  @MainActor public func replaceNavigationRoot<Component>(
    with type: Component.Type,
    in context: Component.Controller.Context,
    animated: Bool = true,
    completion: (() -> Void)? = nil
  ) async where Component: UIComponent {
    guard
      let navigationController = self as? UINavigationController
        ?? self.navigationController
        ?? self.presentingViewController?.navigationController
    else { unreachable("It is programmer error to replace navigatyion without navigation controller") }

    let component: Component =
      await self.components
      .instance(
        of: Component.self,
        in: context
      )

    return await withCheckedContinuation { continuation in
      CATransaction.begin()
      CATransaction.setCompletionBlock {
        completion?()
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
    in context: Component.Controller.NavigationContext,
    animated: Bool = true,
    completion: (() -> Void)? = nil
  ) async where Component: ComponentView {
    await self.replaceNavigationRoot(
      with: ComponentHostingViewController<Component>.self,
      in: context,
      animated: animated,
      completion: completion
    )
  }

  @MainActor public func present<Component>(
    _ type: Component.Type,
    animated: Bool = true,
    completion: (() -> Void)? = nil
  ) async where Component: ComponentView, Component.Controller.NavigationContext == Void {
    await self.present(
      ComponentHostingViewController<Component>.self,
      animated: animated,
      completion: completion
    )
  }

  @MainActor public func present<Component>(
    _ type: Component.Type,
    animated: Bool = true,
    completion: (() -> Void)? = nil
  ) async where Component: UIComponent, Component.Controller.Context == Void {
    await self.present(
      type,
      in: Void(),
      animated: animated,
      completion: completion
    )
  }

  @MainActor public func present<Component>(
    _ type: Component.Type,
    in context: Component.Controller.NavigationContext,
    animated: Bool = true,
    completion: (() -> Void)? = nil
  ) async where Component: ComponentView {
    await self.present(
      ComponentHostingViewController<Component>.self,
      in: context,
      animated: animated,
      completion: completion
    )
  }

  @MainActor public func present<Component>(
    _ type: Component.Type,
    in context: Component.Controller.Context,
    animated: Bool = true,
    completion: (() -> Void)? = nil
  ) async where Component: UIComponent {
    var presentedLeaf: UIViewController = self
    while let next: UIViewController = presentedLeaf.presentedViewController {
      presentedLeaf = next
    }

    let component: Component =
      await self.components
      .instance(
        of: Component.self,
        in: context
      )

    return await withCheckedContinuation { continuation in
      presentedLeaf.present(
        component,
        animated: animated,
        completion: {
          completion?()
          continuation.resume()
        }
      )
    }
  }

  @MainActor public func presentSheet<Component>(
    _ type: Component.Type,
    animated: Bool = true,
    completion: (() -> Void)? = nil
  ) async where Component: ComponentView, Component.Controller.NavigationContext == Void {
    await self.presentSheet(
      ComponentHostingViewController<Component>.self,
      in: Void(),
      animated: animated,
      completion: completion
    )
  }

  @MainActor public func presentSheet<Component>(
    _ type: Component.Type,
    in context: Component.Controller.NavigationContext,
    animated: Bool = true,
    completion: (() -> Void)? = nil
  ) async where Component: ComponentView {
    await self.presentSheet(
      ComponentHostingViewController<Component>.self,
      in: context,
      animated: animated,
      completion: completion
    )
  }

  @MainActor public func presentSheet<Component>(
    _ type: Component.Type,
    in context: SheetViewController<Component>.Controller.Context,
    animated: Bool = true,
    completion: (() -> Void)? = nil
  ) async where Component: UIComponent {
    await present(
      SheetViewController<Component>.self,
      in: context,
      animated: animated,
      completion: completion
    )
  }

  @MainActor public func presentSheetMenu<Component>(
    _ type: Component.Type,
    in context: SheetMenuViewController<Component>.Controller.Context,
    animated: Bool = true,
    completion: (() -> Void)? = nil
  ) async where Component: UIComponent {
    await present(
      SheetMenuViewController<Component>.self,
      in: context,
      animated: animated,
      completion: completion
    )
  }

  @MainActor public func dismiss<Component>(
    _ type: Component.Type,
    animated: Bool = true,
    completion: (() -> Void)? = nil
  ) async where Component: ComponentView {
    await self.dismiss(
      ComponentHostingViewController<Component>.self,
      animated: animated,
      completion: completion
    )
  }

  @MainActor public func dismiss<Component>(
    _ type: Component.Type,
    animated: Bool = true,
    completion: (() -> Void)? = nil
  ) async where Component: UIComponent {
    var current: UIViewController = self
    repeat {
      if current is Component {
        return await withCheckedContinuation { continuation in
          current
            .presentingViewController?
            .dismiss(
              animated: animated,
              completion: {
                completion?()
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
    animated: Bool = true,
    completion: (() -> Void)? = nil
  ) async where Component: ComponentView, Component.Controller.NavigationContext == Void {
    await self.push(
      ComponentHostingViewController<Component>.self,
      animated: animated,
      completion: completion
    )
  }

  @MainActor public func push<Component>(
    _ type: Component.Type,
    animated: Bool = true,
    completion: (() -> Void)? = nil
  ) async where Component: UIComponent, Component.Controller.Context == Void {
    await push(
      type,
      in: Void(),
      animated: animated,
      completion: completion
    )
  }

  @MainActor public func push<Component>(
    _ type: Component.Type,
    in context: Component.Controller.NavigationContext,
    animated: Bool = true,
    completion: (() -> Void)? = nil
  ) async where Component: ComponentView {
    await self.push(
      ComponentHostingViewController<Component>.self,
      in: context,
      animated: animated,
      completion: completion
    )
  }

  @MainActor public func push<Component>(
    _ type: Component.Type,
    in context: Component.Controller.Context,
    animated: Bool = true,
    completion: (() -> Void)? = nil
  ) async where Component: UIComponent {
    guard
      let navigationController = self as? UINavigationController
        ?? self.navigationController
        ?? self.presentingViewController?.navigationController
    else { unreachable("It is programmer error to push without navigation controller") }
    let component: Component =
      await self.components
      .instance(
        of: Component.self,
        in: context
      )
    return await withCheckedContinuation { continuation in
      CATransaction.begin()
      CATransaction.setCompletionBlock {
        completion?()
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

  @MainActor public func pop<Component>(
    if type: Component.Type,
    animated: Bool = true,
    completion: (() -> Void)? = nil
  ) async where Component: ComponentView {
    await self.pop(
      if: ComponentHostingViewController<Component>.self,
      animated: animated,
      completion: completion
    )
  }

  @MainActor public func pop<Component>(
    if type: Component.Type,
    animated: Bool = true,
    completion: (() -> Void)? = nil
  ) async where Component: UIComponent {
    guard let navigationController = self.navigationController
    else { unreachable("It is programmer error to pop without navigation controller") }
    guard navigationController.viewControllers.last is Component
    else { return }  // ignore

    return await withCheckedContinuation { continuation in
      CATransaction.begin()
      CATransaction.setCompletionBlock {
        completion?()
        continuation.resume()
      }
      navigationController.popViewController(animated: animated)
      CATransaction.commit()
    }
  }

  @discardableResult
  @MainActor public func pop<Component>(
    to type: Component.Type,
    animated: Bool = true,
    completion: (() -> Void)? = nil
  ) async -> Bool
  where Component: ComponentView {
    await self.pop(
      to: ComponentHostingViewController<Component>.self,
      animated: animated,
      completion: completion
    )
  }

  @discardableResult
  @MainActor public func pop<Component>(
    to type: Component.Type,
    animated: Bool = true,
    completion: (() -> Void)? = nil
  ) async -> Bool
  where Component: UIComponent {
    guard let navigationController = self.navigationController
    else { unreachable("It is programmer error to pop without navigation controller") }
    guard let targetViewController = navigationController.viewControllers.last(where: { $0 is Component })
    else { return false }  // ignore
    await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
      CATransaction.begin()
      CATransaction.setCompletionBlock {
        completion?()
        continuation.resume()
      }
      navigationController.popToViewController(targetViewController, animated: animated)
      CATransaction.commit()
    }
    return true
  }

  @MainActor public func popAll<Component>(
    _ type: Component.Type,
    animated: Bool = true,
    completion: (() -> Void)? = nil
  ) async where Component: ComponentView {
    await self.popAll(
      ComponentHostingViewController<Component>.self,
      animated: animated,
      completion: completion
    )
  }

  @MainActor public func popAll<Component>(
    _ type: Component.Type,
    animated: Bool = true,
    completion: (() -> Void)? = nil
  ) async where Component: UIComponent {
    guard let navigationController = self.navigationController
    else { unreachable("It is programmer error to pop without navigation controller") }
    return await withCheckedContinuation { continuation in
      CATransaction.begin()
      CATransaction.setCompletionBlock {
        completion?()
        continuation.resume()
      }
      navigationController
        .setViewControllers(
          navigationController.viewControllers.filter { !($0 is Component) },
          animated: animated && navigationController.viewControllers.last is Component
        )
      CATransaction.commit()
    }
  }

  @MainActor public func popToRoot(
    animated: Bool = true,
    completion: (() -> Void)? = nil
  ) async {
    guard let navigationController = self.navigationController
    else { unreachable("It is programmer error to pop without navigation controller") }
    return await withCheckedContinuation { continuation in
      CATransaction.begin()
      CATransaction.setCompletionBlock {
        completion?()
        continuation.resume()
      }
      navigationController.popToRootViewController(animated: animated)
      CATransaction.commit()
    }
  }

  @MainActor public func replaceLast<Replaced, Replacement>(
    _ replaced: Replaced.Type,
    with replacement: Replacement.Type,
    animated: Bool = true,
    completion: (() -> Void)? = nil
  ) async where Replaced: UIComponent, Replacement: UIComponent, Replacement.Controller.Context == Void {
    await replaceLast(
      replaced,
      with: replacement,
      in: Void(),
      animated: animated,
      completion: completion
    )
  }

  @MainActor public func replaceLast<Replaced, Replacement>(
    _ replaced: Replaced.Type,
    with replacement: Replacement.Type,
    in context: Replacement.Controller.Context,
    animated: Bool = true,
    completion: (() -> Void)? = nil
  ) async where Replaced: UIComponent, Replacement: UIComponent {
    guard let navigationController = self.navigationController
    else { unreachable("It is programmer error to replace without navigation controller") }
    guard let targetIndex = navigationController.viewControllers.lastIndex(where: { $0 is Replaced })
    else { return }  // ignore
    let component: Replacement = await self.components
      .instance(
        of: Replacement.self,
        in: context
      )
    return await withCheckedContinuation { continuation in
      CATransaction.begin()
      CATransaction.setCompletionBlock {
        completion?()
        continuation.resume()
      }
      var updatedViewControllers: Array<UIViewController> = navigationController.viewControllers
      updatedViewControllers[targetIndex] = component

      navigationController
        .setViewControllers(
          updatedViewControllers,
          animated: animated && updatedViewControllers.last is Replacement
        )
      CATransaction.commit()
    }
  }
}

extension UIComponent {

  @MainActor public func addChild<Component>(
    _ type: Component.Type,
    viewSetup: @escaping (_ parent: Self.ContentView, _ child: Component.ContentView) -> Void,
    animations: ((_ parent: Self.ContentView, _ child: Component.ContentView) -> Void)? = nil,
    completion: ((Component) -> Void)? = nil
  ) async where Component: UIComponent, Component.Controller.Context == Void {
    await addChild(
      type,
      in: Void(),
      viewSetup: viewSetup,
      animations: animations,
      completion: completion
    )
  }

  @MainActor public func addChild<Component>(
    _ type: Component.Type,
    in context: Component.Controller.Context,
    viewSetup: @escaping (_ parent: Self.ContentView, _ child: Component.ContentView) -> Void,
    animations: ((_ parent: Self.ContentView, _ child: Component.ContentView) -> Void)? = nil,
    completion: ((Component) -> Void)? = nil
  ) async
  where Component: UIComponent {
    let childComponent: Component =
      await self.components
      .instance(
        of: Component.self,
        in: context
      )

    self.addChild(childComponent)
    childComponent.loadViewIfNeeded()
    viewSetup(self.contentView, childComponent.contentView)

    if let animations = animations {
      return await withCheckedContinuation { continuation in
        UIView.animate(
          withDuration: 0.3,
          delay: 0,
          options: [.beginFromCurrentState, .allowUserInteraction],
          animations: {
            animations(self.contentView, childComponent.contentView)
          },
          completion: { _ in
            childComponent.didMove(toParent: self)
            completion?(childComponent)
            continuation.resume()
          }
        )
      }
    }
    else {
      childComponent.didMove(toParent: self)
      completion?(childComponent)
    }
  }

  @MainActor public func addChild<Component>(
    _ type: Component.Type,
    in context: Component.Controller.NavigationContext,
    viewSetup: @escaping (_ parent: Self.ContentView, _ child: ComponentHostingViewController<Component>.ContentView) -> Void,
    animations: ((_ parent: Self.ContentView, _ child: ComponentHostingViewController<Component>.ContentView) -> Void)? = nil,
    completion: (() -> Void)? = nil
  ) async
  where Component: ComponentView {
    await self.addChild(
      ComponentHostingViewController<Component>.self,
      in: context,
      viewSetup: viewSetup,
      animations: animations,
      completion: { _ in completion?() }
    )
  }

  @MainActor public func replaceChild<Replaced, Replacing>(
    _ replaced: Replaced.Type,
    with replacing: Replacing.Type,
    viewSetup: @escaping (_ parent: Self.ContentView, _ replacing: Replacing.ContentView) -> Void,
    animations: (
      (_ parent: Self.ContentView, _ replacing: Replacing.ContentView, _ replaced: Replaced.ContentView) -> Void
    )? = nil,
    completion: (() -> Void)? = nil
  ) async where Replaced: UIComponent, Replacing: UIComponent, Replacing.Controller.Context == Void {
    await replaceChild(
      replaced,
      with: replacing,
      in: Void(),
      viewSetup: viewSetup,
      animations: animations,
      completion: completion
    )
  }

  @MainActor public func replaceChild<Replaced, Replacing>(
    _ replaced: Replaced.Type,
    with replacing: Replacing.Type,
    in context: Replacing.Controller.Context,
    viewSetup: @escaping (_ parent: Self.ContentView, _ replacing: Replacing.ContentView) -> Void,
    animations: (
      (_ parent: Self.ContentView, _ replacing: Replacing.ContentView, _ replaced: Replaced.ContentView) -> Void
    )? = nil,
    completion: (() -> Void)? = nil
  ) async where Replaced: UIComponent, Replacing: UIComponent {
    let matchingComponents: Array<Replaced> = self.children.compactMap { $0 as? Replaced }
    assert(matchingComponents.count == 1, "Cannot replace non existing or ambiguous child")
    guard let replacedComponent: Replaced = matchingComponents.first
    else { return }

    replacedComponent.willMove(toParent: nil)

    let replacingComponent: Replacing =
      await self.components
      .instance(
        of: Replacing.self,
        in: context
      )

    self.addChild(replacingComponent)
    replacingComponent.loadViewIfNeeded()
    viewSetup(self.contentView, replacingComponent.contentView)

    if let animations = animations {
      return await withCheckedContinuation { continuation in
        UIView.animate(
          withDuration: 0.3,
          delay: 0,
          options: [.beginFromCurrentState, .allowUserInteraction],
          animations: {
            animations(self.contentView, replacingComponent.contentView, replacedComponent.contentView)
          },
          completion: { _ in
            replacedComponent.view.removeFromSuperview()
            replacedComponent.removeFromParent()
            replacingComponent.didMove(toParent: self)
            completion?()
            continuation.resume()
          }
        )
      }
    }
    else {
      replacedComponent.view.removeFromSuperview()
      replacedComponent.removeFromParent()
      replacingComponent.didMove(toParent: self)
      completion?()
    }
  }

  @MainActor public func removeAllChildren<Component>(
    _ type: Component.Type,
    animations: ((_ parent: Self.ContentView, _ removed: Component.ContentView) -> Void)? = nil,
    completion: (() -> Void)? = nil
  ) async where Component: UIComponent {
    return await withCheckedContinuation { continuation in
      CATransaction.begin()
      CATransaction.setCompletionBlock {
        completion?()
        continuation.resume()
      }
      self.children
        .compactMap { $0 as? Component }
        .forEach { child in
          child.willMove(toParent: nil)
          if let animations = animations {
            UIView.animate(
              withDuration: 0.3,
              delay: 0,
              options: [.beginFromCurrentState, .allowUserInteraction],
              animations: {
                animations(self.contentView, child.contentView)
              },
              completion: { _ in
                child.view.removeFromSuperview()
                child.removeFromParent()
              }
            )
          }
          else {
            child.view.removeFromSuperview()
            child.removeFromParent()
          }
        }
      CATransaction.commit()
    }
  }

  @MainActor public func removeAllChildren<Component>(
    _ type: Component.Type,
    animations: ((_ parent: Self.ContentView, _ removed: ComponentHostingViewController<Component>.ContentView) -> Void)? = nil,
    completion: (() -> Void)? = nil
  ) async where Component: ComponentView {
    await self.removeAllChildren(
      ComponentHostingViewController<Component>.self
    )
  }
}
