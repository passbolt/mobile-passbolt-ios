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

import SharedUIComponents
import UIComponents

@MainActor
internal final class Window {

	private enum ScreenCache {

		case cached(AnyUIComponent, for: Account)
	}

  private static let transitionDuration: TimeInterval = 0.3

  private let window: UIWindow
  private let components: UIComponentFactory
  private let cancellables: Cancellables
  private let maskView: SplashScreenView = .init()
  private var screenStateAccount: Account?
  private var screenStateCache: ScreenCache?

  internal init(
    in scene: UIWindowScene,
    using lazyController: @escaping () -> WindowController,
    within components: UIComponentFactory,
    rootViewController: UIViewController,
    cancellables: Cancellables
  ) {
    self.window = UIWindow(windowScene: scene)
    self.components = components
    self.cancellables = cancellables
    self.window.rootViewController = rootViewController
    self.screenStateAccount = .none
    self.screenStateCache = .none
    setupSnackBarMessages(within: self.window)

    cancellables.executeAsync { @MainActor [self] in
      let controller: WindowController = lazyController()
			try self.replaceRoot(
				with: self.components
					.instance(
						of: SplashScreenViewController.self,
						in: controller.initialAccount()
					)
			)
      for try await disposition in controller.screenStateDispositionSequence() {
        switch disposition {
        // Use last state for same session after authorization.
        case let .useAuthorizedScreenState(account):
					self.screenStateAccount = account
					switch self.screenStateCache {
					case .cached(let cached, for: account):
						self.screenStateCache = .none
            self.replaceRoot(with: cached)

					case .cached, .none:
						// fallback to initial screen state if there is none cached
						guard !self.isSplashScreenDisplayed || self.isErrorDisplayed
						else { return }
						self.screenStateCache = .none
						try self.replaceRoot(
							with: self.components
								.instance(
									of: SplashScreenViewController.self,
									in: account
								)
						)
					}


        // Go to initial screen state (through Splash)
        // which will be one of:
        // - welcome (no accounts)
        // - home (for authorized)
        // - account selection (for unauthorized)
        case .useInitialScreenState:
          guard !self.isSplashScreenDisplayed || self.isErrorDisplayed
          else { return }

          self.screenStateCache = .none
          try self.replaceRoot(
            with: self.components
              .instance(
                of: SplashScreenViewController.self,
                in: .none
              )
          )

        // Prompt user with authorization screen if it is not already displayed.
        case let .requestPassphrase(account, message):
          guard
            !self.isSplashScreenDisplayed,
            !self.isAuthorizationDisplayed
          else { return }

					if self.screenStateAccount == account {
						if !self.isMFAPromptDisplayed {
							assert(
								self.screenStateCache == nil,
								"Cannot replace screen state cache, it has to be empty"
							)
							guard let rootComponent: AnyUIComponent = self.window.rootViewController as? AnyUIComponent
							else { unreachable("Window root has to be an instance of UIComponent") }
							self.screenStateCache = .cached(rootComponent, for: account)
						}
						else {
							/* NOP - reuse previous cache if any if previous screen was mfa prompt */
						}
					}
					else {
						self.screenStateCache = .none
						self.screenStateAccount = account
					}

          try self.replaceRoot(
            with: self.components
              .instance(
                of: AuthorizationNavigationViewController.self,
                in: (account: account, message: message)
              )
          )

        // Prompt user with mfa screen if it is not already displayed.
        case let .requestMFA(account, providers):
          guard
            !self.isSplashScreenDisplayed,
            !self.isMFAPromptDisplayed
          else { return }

          if let authorizationNavigation = self.window.rootViewController
            as? AuthorizationNavigationViewController
          {
            if providers.isEmpty {
              try self.replaceRoot(
                with: self.components
                  .instance(
                    of: PlainNavigationViewController<UnsupportedMFAViewController>.self
                  )
              )
            }
            else {
              await authorizationNavigation
                .push(
                  MFARootViewController.self,
                  in: providers
                )
            }
          }
          else if let welcomeNavigation = self.window.rootViewController
            as? WelcomeNavigationViewController
          {
            if providers.isEmpty {
              try self.replaceRoot(
                with: self.components
                  .instance(
                    of: PlainNavigationViewController<UnsupportedMFAViewController>.self
                  )
              )
            }
            else {
              await welcomeNavigation
                .push(
                  MFARootViewController.self,
                  in: providers
                )
            }
          }
          else {
						if self.screenStateAccount == account {
							assert(
								self.screenStateCache == nil,
								"Cannot replace screen state cache, it has to be empty"
							)
							guard let rootComponent: AnyUIComponent = self.window.rootViewController as? AnyUIComponent
							else { unreachable("Window root has to be an instance of UIComponent") }
							self.screenStateCache = .cached(rootComponent, for: account)
						}
						else {
							self.screenStateCache = .none
							self.screenStateAccount = account
						}

            if providers.isEmpty {
              try self.replaceRoot(
                with: self.components
                  .instance(
                    of: PlainNavigationViewController<UnsupportedMFAViewController>.self
                  )
              )
            }
            else {
              try self.replaceRoot(
                with: self.components
                  .instance(
                    of: PlainNavigationViewController<MFARootViewController>.self,
                    in: providers
                  )
              )
            }
          }
        }
      }
    }
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

  private var isErrorDisplayed: Bool {
    window.rootViewController?.presentedViewController is ErrorViewController
  }

  private var isAccountTransferDisplayed: Bool {
    guard let navigation = window.rootViewController as? UINavigationController
    else { return false }
    return navigation.viewControllers.contains { (vc: UIViewController) -> Bool in
      vc is TransferSignInViewController
        || vc is TransferInfoScreenViewController
    }
  }

  private var isAuthorizationDisplayed: Bool {
    guard let navigation = window.rootViewController as? UINavigationController
    else { return false }

    return navigation.viewControllers
      .contains { (vc: UIViewController) -> Bool in
        vc is TransferSignInViewController
          || vc is AuthorizationViewController
      }
      && !navigation.viewControllers
        .contains { (vc: UIViewController) -> Bool in
          vc is MFARootViewController
        }
  }

  private var isMFAPromptDisplayed: Bool {
    window.rootViewController is PlainNavigationViewController<MFARootViewController>
      || (window.rootViewController as? AuthorizationNavigationViewController)?.viewControllers
        .contains(where: {
          $0 is MFARootViewController
        }) ?? false
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
      duration: animated ? Self.transitionDuration : 0,
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
