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

public extension UIComponent {
  
  func present<Component>(
    _ type: Component.Type,
    animated: Bool = true,
    completion: (() -> Void)? = nil
  ) where Component: UIComponent, Component.Controller.Context == Void {
    present(type, in: Void(), animated: animated, completion: completion)
  }
  
  func present<Component>(
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
  
  func dismiss<Component>(
    _ type: Component.Type,
    animated: Bool = true,
    completion: (() -> Void)? = nil
  ) where Component: UIComponent {
    var presentedLeaf: UIViewController = self
    while let next: UIViewController = presentedLeaf.presentedViewController {
      if next is Component {
        return presentedLeaf.dismiss(animated: animated, completion: completion)
      } else {
        presentedLeaf = next
      }
    }
  }
  
  func push<Component>(
    _ type: Component.Type,
    animated: Bool = true,
    completion: (() -> Void)? = nil
  ) where Component: UIComponent, Component.Controller.Context == Void {
    push(type, in: Void(), animated: animated, completion: completion)
  }
  
  func push<Component>(
    _ type: Component.Type,
    in context: Component.Controller.Context,
    animated: Bool = true,
    completion: (() -> Void)? = nil
  ) where Component: UIComponent {
    guard let navigationController = navigationController
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
  
  func pop<Component>(
    if type: Component.Type,
    animated: Bool = true,
    completion: (() -> Void)? = nil
  ) where Component: UIComponent {
    guard let navigationController = navigationController
    else { unreachable("It is programmer error to pop without navigation controller") }
    guard navigationController.viewControllers.last is Component
    else { return } // ignore
    CATransaction.begin()
    CATransaction.setCompletionBlock(completion)
    navigationController.popViewController(animated: animated)
    CATransaction.commit()
  }
  
  func pop<Component>(
    to type: Component.Type,
    animated: Bool = true,
    completion: (() -> Void)? = nil
  ) where Component: UIComponent {
    guard let navigationController = navigationController
    else { unreachable("It is programmer error to pop without navigation controller") }
    guard let targetViewController = navigationController.viewControllers.last(where: { $0 is Component })
    else { return } // ignore
    CATransaction.begin()
    CATransaction.setCompletionBlock(completion)
    navigationController.popToViewController(targetViewController, animated: animated)
    CATransaction.commit()
  }
  
  func popAll<Component>(
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
}
