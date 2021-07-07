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

import UIComponents

internal final class Window {

  private let window: UIWindow
  private let controller: WindowController
  private let components: UIComponentFactory
  private let cancellables: Cancellables
  private let maskView: SplashScreenView = .init()
  private var screenStateCache: AnyUIComponent?

  internal init(
    in scene: UIWindowScene,
    using controller: WindowController,
    within components: UIComponentFactory,
    cancellables: Cancellables
  ) {
    self.window = UIWindow(windowScene: scene)
    self.controller = controller
    self.components = components
    self.cancellables = cancellables

    self.window.rootViewController =
      components
      .instance(
        of: SplashScreenViewController.self
      )

    self.controller
      .screenStateDispositionPublisher()
      .receive(on: RunLoop.main)
      .sink(
        receiveValue: { [weak self] disposition in
          guard let self = self else { return }
          switch disposition {
          // Just clear cache - "prevents weird behavior on
          // cached screen when signing out / switching account.
          case .clearCache:
            self.screenStateCache = nil

          // Use last state for same session after authorization.
          case .useCachedScreenState:
            if let cachedScreen: AnyUIComponent = self.screenStateCache {
              self.screenStateCache = nil
              self.replaceRoot(with: cachedScreen)
            }
            else {
              assertionFailure("Missing cached screen state")
              fallthrough  // fallback to initial screen state
            }

          // Go to initial screen state (through Splash)
          // which will be one of:
          // - welcome (no accounts)
          // - home (for authorized)
          // - account selection (for unauthorized)
          case .useInitialScreenState:
            self.screenStateCache = nil
            guard
              self.isInitialScreenNavigationAllowed
            else { return }

            self.replaceRoot(
              with: self.components
                .instance(
                  of: SplashScreenViewController.self
                )
            )

          // Prompt user with authorization screen if it is not already displayed.
          case let .authorize(accountLocalID):
            guard
              self.isAuthorizationPromptAllowed
            else { return }

            // we might also ignore configuration download error screen after it becomes available
            if self.isSplashScreenDisplayed {
              // cache only if current root is not a splash screen

            }
            else {
              self.screenStateCache = nil
              assert(
                self.screenStateCache == nil,
                "Cannot replace screen state cache, it has to be empty"
              )
              guard let rootComponent: AnyUIComponent = self.window.rootViewController as? AnyUIComponent
              else { unreachable("Window root has to be an instance of UIComponent") }
              self.screenStateCache = rootComponent
            }

            self.replaceRoot(
              with: self.components
                .instance(
                  of: AuthorizationNavigationViewController.self,
                  in: accountLocalID
                )
            )
          }
        }
      )
      .store(in: cancellables)
  }
}

extension Window {

  internal var isActive: Bool {
    get { window.isKeyWindow }
    set {
      switch newValue {
      case true:
        maskView.removeFromSuperview()
        window.makeKeyAndVisible()

      case false:
        maskView.frame = window.bounds
        window.addSubview(maskView)
        window.resignKey()
      }
    }
  }
}

extension Window {

  private var isSplashScreenDisplayed: Bool {
    window.rootViewController is SplashScreenViewController
  }

  private var isAuthorizationPromptAllowed: Bool {
    guard let accountSelectionNavigation = window.rootViewController as? AuthorizationNavigationViewController
    else { return true }  // always if we don't display authorization yet
    return accountSelectionNavigation.isAuthorizationPromptAllowed
  }

  private var isInitialScreenNavigationAllowed: Bool {
    if let accountSelectionNavigation = window.rootViewController as? AuthorizationNavigationViewController {
      return accountSelectionNavigation.isInitialScreenNavigationAllowed
    }
    else {
      // we allow that only after authorization (but not from account selection)
      return true
    }
  }
}

extension Window {

  private func replaceRoot(
    with component: AnyUIComponent,
    animated: Bool = true,
    completion: (() -> Void)? = nil
  ) {
    let currentView: UIView? = window.rootViewController?.view
    window.rootViewController = component
    UIView.transition(
      with: window,
      duration: animated ? 0.3 : 0,
      options: [.transitionCrossDissolve],
      animations: {
        currentView?.alpha = 0
      },
      completion: { _ in
        completion?()
        currentView?.alpha = 1
      }
    )
  }
}
