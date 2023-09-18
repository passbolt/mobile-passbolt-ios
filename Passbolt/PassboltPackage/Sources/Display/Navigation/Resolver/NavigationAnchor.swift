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

import UIKit

internal protocol NavigationAnchor: UIViewController {

  var destinationIdentifier: NavigationDestinationIdentifier? { get }
}

extension UIViewController: NavigationAnchor {

  public var destinationIdentifier: NavigationDestinationIdentifier? {
    get {
      objc_getAssociatedObject(
        self,
        &destinationIdentifierAssociationKey
      ) as? NavigationDestinationIdentifier
    }
    set {
      objc_setAssociatedObject(
        self,
        &destinationIdentifierAssociationKey,
        newValue,
        .OBJC_ASSOCIATION_RETAIN_NONATOMIC
      )
    }
  }
}

private var destinationIdentifierAssociationKey: Int = 0

extension NavigationAnchor {

  @MainActor internal func present(
    _ presentedAnchor: NavigationAnchor,
    animated: Bool,
    file: StaticString,
    line: UInt
  ) async {
    defer {
      if #available(iOS 16.0, *) {
        presentedAnchor.sheetPresentationController?
          .animateChanges {
            presentedAnchor.sheetPresentationController?.invalidateDetents()
          }
      }  // else NOP
    }
    return await withCheckedContinuation { continuation in
      (self.navigationTabs
        ?? self.navigationStack
        ?? self)
        .present(
          presentedAnchor,
          animated: animated,
          completion: continuation.resume
        )
    }
  }

  @MainActor internal var navigationStack: UINavigationController? {
    self as? UINavigationController ?? self.navigationController
  }

  @MainActor internal func push(
    _ pushedAnchor: NavigationAnchor,
    animated: Bool,
    file: StaticString,
    line: UInt
  ) async throws {
    guard let stack: UINavigationController = self.navigationStack
    else {
      throw
        InternalInconsistency
        .error(
          "Invalid navigation - missing stack!",
          file: file,
          line: line
        )
        .asAssertionFailure()
    }
    return await withCheckedContinuation { continuation in
      CATransaction.begin()
      CATransaction.setCompletionBlock(continuation.resume)
      stack.pushViewController(
        pushedAnchor,
        animated: animated
      )
      CATransaction.commit()
    }
  }

  @MainActor internal func pop(
    to identifier: NavigationDestinationIdentifier,
    animated: Bool,
    file: StaticString,
    line: UInt
  ) async throws {
    guard let destinationAnchor = self.leafAnchor(with: identifier)
    else {
      throw
        InternalInconsistency
        .error(
          "Invalid navigation - missing destination!",
          file: file,
          line: line
        )
        .asAssertionFailure()
    }
    guard let stack: UINavigationController = destinationAnchor.navigationStack
    else {
      throw
        InternalInconsistency
        .error(
          "Invalid navigation - missing stack!",
          file: file,
          line: line
        )
        .asAssertionFailure()
    }
    return await withCheckedContinuation { continuation in
      CATransaction.begin()
      CATransaction.setCompletionBlock(continuation.resume)
      stack.popToViewController(
        destinationAnchor,
        animated: animated
      )
      CATransaction.commit()
    }
  }

  @MainActor internal var navigationTabs: UITabBarController? {
    self as? UITabBarController ?? self.tabBarController
  }

  // traverse from leaf to root
  @MainActor internal func dismiss(
    with identifier: NavigationDestinationIdentifier,
    animated: Bool,
    file: StaticString,
    line: UInt
  ) async {
    guard let anchorToDismiss: NavigationAnchor = self.leafAnchor(with: identifier)
    else { return /* NOP - can't dismiss */ }

    if let presenting: UIViewController = anchorToDismiss.presentingViewController {
      return await withCheckedContinuation { continuation in
        presenting.dismiss(
          animated: animated,
          completion: continuation.resume
        )
      }
    }
    else if let stack: UINavigationController = anchorToDismiss.navigationStack {
      if let index: Int = stack.viewControllers.lastIndex(of: anchorToDismiss),
        index != stack.viewControllers.startIndex
      {
        let indexBefore: Int = stack.viewControllers.index(before: index)

        return await withCheckedContinuation { continuation in
          CATransaction.begin()
          CATransaction.setCompletionBlock(continuation.resume)
          stack.popToViewController(
            stack.viewControllers[indexBefore],
            animated: animated
          )
          CATransaction.commit()
        }
      }
      else {
        // what else to do really? it seems to be root
        return await withCheckedContinuation { continuation in
          stack.dismiss(
            animated: animated,
            completion: continuation.resume
          )
        }
      }
    }
    else if let tabs: UITabBarController = anchorToDismiss.navigationTabs {
      #warning("TODO: to implement in future - search through all tabs")
      //			return // NOP for now until required to be implemented
      InternalInconsistency
        .error(
          "Unexpected navigation!",
          file: file,
          line: line
        )
        .asAssertionFailure()
    }
    else {
      // do we have to handle any more?
      // this should be all?
      InternalInconsistency
        .error(
          "Unexpected navigation!",
          file: file,
          line: line
        )
        .asAssertionFailure()
    }
  }

  // make sure it is always called on root first
  @MainActor internal var leafAnchor: NavigationAnchor {
    if let presented: NavigationAnchor = self.presentedViewController {
      return presented.leafAnchor
    }
    else if let tabs: UITabBarController = self as? UITabBarController {
      if let content: Array<UIViewController> = tabs.viewControllers, !content.isEmpty {
        return content[tabs.selectedIndex].leafAnchor
      }
      else {
        return tabs
      }
    }
    else if let stack: UINavigationController = self as? UINavigationController {
      if let last: UIViewController = stack.viewControllers.last {
        return last.leafAnchor
      }
      else {
        return stack
      }
    }
    else {
      return self
    }
  }

  // make sure it is always called on root first
  @MainActor internal func leafAnchor(
    with identifier: NavigationDestinationIdentifier
  ) -> NavigationAnchor? {
    if self.destinationIdentifier == identifier {
      return self
    }
    else if let presented: NavigationAnchor = self.presentedViewController {
      return presented.leafAnchor(with: identifier)
    }
    else if let tabs: UITabBarController = self as? UITabBarController {
      if let content: Array<UIViewController> = tabs.viewControllers, !content.isEmpty {
        return content[tabs.selectedIndex]
          .leafAnchor(with: identifier)
          ?? content
          .compactMap({ $0.leafAnchor(with: identifier) })
          .last
      }
      else {
        return .none
      }
    }
    else if let stack: UINavigationController = self as? UINavigationController {
      if let lastMatching: NavigationAnchor = stack.viewControllers.compactMap({ $0.leafAnchor(with: identifier) }).last
      {
        return lastMatching
      }
      else {
        return .none
      }
    }
    else {
      return .none
    }
  }
}
