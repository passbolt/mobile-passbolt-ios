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

import Commons
import UIKit

extension UIComponent {

  public func replaceWindowRoot<Component>(
    with type: Component.Type,
    animated: Bool = true,
    completion: (() -> Void)? = nil
  ) where Component: UIComponent, Component.Controller.Context == Void {
    replaceWindowRoot(
      with: type,
      in: Void(),
      animated: animated,
      completion: completion
    )
  }

  public func replaceWindowRoot<Component>(
    with type: Component.Type,
    in context: Component.Controller.Context,
    animated: Bool = true,
    completion: (() -> Void)? = nil
  ) where Component: UIComponent {
    guard let window: UIWindow = view.window
    else { return assertionFailure("Cannot replace window root without window") }

    let currentView: UIView? = window.rootViewController?.view
    window.rootViewController =
      components
      .instance(
        of: Component.self,
        in: context
      )
    UIView.transition(
      with: window,
      duration: animated ? 0.3 : 0,
      options: [.transitionCrossDissolve],
      animations: {
        currentView?.alpha = 0
      },
      completion: { _ in completion?() }
    )
  }

  public func present<Component>(
    _ type: Component.Type,
    animated: Bool = true,
    completion: (() -> Void)? = nil
  ) where Component: UIComponent, Component.Controller.Context == Void {
    present(type, in: Void(), animated: animated, completion: completion)
  }

  public func present<Component>(
    _ type: Component.Type,
    in context: Component.Controller.Context,
    animated: Bool = true,
    completion: (() -> Void)? = nil
  ) where Component: UIComponent {
    var presentedLeaf: UIViewController = self
    while let next: UIViewController = presentedLeaf.presentedViewController {
      presentedLeaf = next
    }

    presentedLeaf.present(
      components
        .instance(
          of: Component.self,
          in: context
        ),
      animated: animated,
      completion: completion
    )
  }

  public func presentSheet<Component>(
    _ type: Component.Type,
    in context: Component.Controller.Context,
    animated: Bool = true,
    insets: UIEdgeInsets = .zero,
    completion: (() -> Void)? = nil
  ) where Component: UIComponent {
    var presentedLeaf: UIViewController = self
    while let next: UIViewController = presentedLeaf.presentedViewController {
      presentedLeaf = next
    }

    let sheet: SheetViewController<Component> = components.instance(in: context)

    presentedLeaf.present(
      sheet,
      animated: animated,
      completion: completion
    )
  }

  public func dismiss<Component>(
    _ type: Component.Type,
    animated: Bool = true,
    completion: (() -> Void)? = nil
  ) where Component: UIComponent {
    var presentedLeaf: UIViewController = self
    while let next: UIViewController = presentedLeaf.presentedViewController {
      if next is Component {
        break
      }
      else {
        presentedLeaf = next
      }
    }

    presentedLeaf.presentingViewController?.dismiss(
      animated: animated,
      completion: completion
    )
  }

  public func push<Component>(
    _ type: Component.Type,
    animated: Bool = true,
    completion: (() -> Void)? = nil
  ) where Component: UIComponent, Component.Controller.Context == Void {
    push(type, in: Void(), animated: animated, completion: completion)
  }

  public func push<Component>(
    _ type: Component.Type,
    in context: Component.Controller.Context,
    animated: Bool = true,
    completion: (() -> Void)? = nil
  ) where Component: UIComponent {
    guard let navigationController = navigationController ?? self as? UINavigationController
    else { unreachable("It is programmer error to push without navigation controller") }
    CATransaction.begin()
    CATransaction.setCompletionBlock(completion)
    navigationController
      .pushViewController(
        components
          .instance(
            of: Component.self,
            in: context
          ),
        animated: animated
      )
    CATransaction.commit()
  }

  @discardableResult
  public func pop<Component>(
    if type: Component.Type,
    animated: Bool = true,
    completion: (() -> Void)? = nil
  ) -> Bool
  where Component: UIComponent {
    guard let navigationController = navigationController
    else { unreachable("It is programmer error to pop without navigation controller") }
    guard navigationController.viewControllers.last is Component
    else { return false }  // ignore
    CATransaction.begin()
    CATransaction.setCompletionBlock(completion)
    navigationController.popViewController(animated: animated)
    CATransaction.commit()
    return true
  }

  @discardableResult
  public func pop<Component>(
    to type: Component.Type,
    animated: Bool = true,
    completion: (() -> Void)? = nil
  ) -> Bool
  where Component: UIComponent {
    guard let navigationController = navigationController
    else { unreachable("It is programmer error to pop without navigation controller") }
    guard let targetViewController = navigationController.viewControllers.last(where: { $0 is Component })
    else { return false }  // ignore
    CATransaction.begin()
    CATransaction.setCompletionBlock(completion)
    navigationController.popToViewController(targetViewController, animated: animated)
    CATransaction.commit()
    return true
  }

  public func popAll<Component>(
    _ type: Component.Type,
    animated: Bool = true,
    completion: (() -> Void)? = nil
  ) where Component: UIComponent {
    guard let navigationController = navigationController
    else { unreachable("It is programmer error to pop without navigation controller") }
    CATransaction.begin()
    CATransaction.setCompletionBlock(completion)
    navigationController
      .setViewControllers(
        navigationController.viewControllers.filter { !($0 is Component) },
        animated: animated && navigationController.viewControllers.last is Component
      )
    CATransaction.commit()
  }

  public func popToRoot(
    animated: Bool = true,
    completion: (() -> Void)? = nil
  ) {
    guard let navigationController = navigationController
    else { unreachable("It is programmer error to pop without navigation controller") }
    CATransaction.begin()
    CATransaction.setCompletionBlock(completion)
    navigationController.popToRootViewController(animated: animated)
    CATransaction.commit()
  }

  @discardableResult
  public func replaceLast<Replaced, Replacement>(
    _ replaced: Replaced.Type,
    with replacement: Replacement.Type,
    animated: Bool = true,
    completion: (() -> Void)? = nil
  ) -> Bool
  where Replaced: UIComponent, Replacement: UIComponent, Replacement.Controller.Context == Void {
    replaceLast(
      replaced,
      with: replacement,
      in: Void(),
      animated: animated,
      completion: completion
    )
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
    guard let navigationController = navigationController
    else { unreachable("It is programmer error to replace without navigation controller") }
    guard let targetIndex = navigationController.viewControllers.lastIndex(where: { $0 is Replaced })
    else { return false }  // ignore
    CATransaction.begin()
    CATransaction.setCompletionBlock(completion)
    var updatedViewControllers: Array<UIViewController> = navigationController.viewControllers
    updatedViewControllers[targetIndex] = components
      .instance(
        of: Replacement.self,
        in: context
      )
    navigationController
      .setViewControllers(
        updatedViewControllers,
        animated: animated && updatedViewControllers.last is Replacement
      )
    CATransaction.commit()
    return true
  }

  public func addChild<Component>(
    _ type: Component.Type,
    viewSetup: (_ parent: Self.View, _ child: Component.View) -> Void,
    animations: ((_ parent: Self.View, _ child: Component.View) -> Void)? = nil,
    completion: (() -> Void)? = nil
  ) where Component: UIComponent, Component.Controller.Context == Void {
    addChild(
      type,
      in: Void(),
      viewSetup: viewSetup,
      animations: animations,
      completion: completion
    )
  }

  public func addChild<Component>(
    _ type: Component.Type,
    in context: Component.Controller.Context,
    viewSetup: (_ parent: Self.View, _ child: Component.View) -> Void,
    animations: ((_ parent: Self.View, _ child: Component.View) -> Void)? = nil,
    completion: (() -> Void)? = nil
  ) where Component: UIComponent {
    let childComponent: Component = components
      .instance(
        of: Component.self,
        in: context
      )

    addChild(childComponent)
    childComponent.loadViewIfNeeded()
    viewSetup(self.contentView, childComponent.contentView)
    if let animations = animations {
      UIView.animate(
        withDuration: 0.3,
        delay: 0,
        options: [.beginFromCurrentState, .allowUserInteraction],
        animations: {
          animations(self.contentView, childComponent.contentView)
        },
        completion: { _ in
          childComponent.didMove(toParent: self)
          completion?()
        }
      )
    } else {
      childComponent.didMove(toParent: self)
      completion?()
    }
  }

  public func replaceChild<Replaced, Replacing>(
    _ replaced: Replaced.Type,
    with replacing: Replacing.Type,
    viewSetup: (_ parent: Self.View, _ replacing: Replacing.View) -> Void,
    animations: ((_ parent: Self.View, _ replacing: Replacing.View, _ replaced: Replaced.View) -> Void)? = nil,
    completion: (() -> Void)? = nil
  ) where Replaced: UIComponent, Replacing: UIComponent, Replacing.Controller.Context == Void {
    replaceChild(
      replaced,
      with: replacing,
      in: Void(),
      viewSetup: viewSetup,
      animations: animations,
      completion: completion
    )
  }

  public func replaceChild<Replaced, Replacing>(
    _ replaced: Replaced.Type,
    with replacing: Replacing.Type,
    in context: Replacing.Controller.Context,
    viewSetup: (_ parent: Self.View, _ replacing: Replacing.View) -> Void,
    animations: ((_ parent: Self.View, _ replacing: Replacing.View, _ replaced: Replaced.View) -> Void)? = nil,
    completion: (() -> Void)? = nil
  ) where Replaced: UIComponent, Replacing: UIComponent {
    let matchingComponents: Array<Replaced> = children.compactMap { $0 as? Replaced }
    assert(matchingComponents.count == 1, "Cannot replace non existing or ambiguous child")
    guard let replacedComponent: Replaced = matchingComponents.first
    else { return }

    replacedComponent.willMove(toParent: nil)

    let replacingComponent: Replacing = components
      .instance(
        of: Replacing.self,
        in: context
      )

    addChild(replacingComponent)
    replacingComponent.loadViewIfNeeded()
    viewSetup(self.contentView, replacingComponent.contentView)

    if let animations = animations {
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
        }
      )
    } else {
      replacedComponent.view.removeFromSuperview()
      replacedComponent.removeFromParent()
      replacingComponent.didMove(toParent: self)
      completion?()
    }
  }

  public func removeAllChildren<Component>(
    _ type: Component.Type,
    animations: ((_ parent: Self.View, _ removed: Component.View) -> Void)? = nil,
    completion: (() -> Void)? = nil
  ) where Component: UIComponent {
    CATransaction.begin()
    CATransaction.setCompletionBlock(completion)
    children
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
        } else {
          child.view.removeFromSuperview()
          child.removeFromParent()
        }
      }
    CATransaction.commit()
  }
}
