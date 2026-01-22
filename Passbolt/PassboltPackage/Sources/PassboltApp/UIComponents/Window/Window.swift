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

import Display
import SharedUIComponents

@MainActor
internal final class Window {

  private enum ScreenCache {

    case cached(UIViewController, for: Account)
  }

  private static let transitionDuration: TimeInterval = 0.3

  private let window: UIWindow
  private let features: Features
  private var screenStateDispositionTask: Task<Void, Error>?

  private lazy var maskView: UIView = {
    let hostedController: UIHostingController<SplashView> = .init(rootView: .init())
    return hostedController.view
  }()
  private var screenStateAccount: Account?
  private var screenStateCache: ScreenCache?

  internal init(
    in scene: UIWindowScene,
    using lazyController: @escaping () -> WindowController,
    with features: Features,
    rootViewController: UIViewController
  ) {
    self.window = UIWindow(windowScene: scene)
    self.features = features

    self.window.rootViewController = rootViewController
    self.screenStateAccount = .none
    self.screenStateCache = .none
    setupSnackBarMessages(within: self.window)
    self.screenStateDispositionTask = .init { @MainActor [self] in
      let controller: WindowController = lazyController()
      let navigationToSplashScreen: NavigationToSplashScreen = try self.features
        .instance()
      try await navigationToSplashScreen.perform(
        context: controller.initialAccount()
      )

      for try await disposition in controller.screenStateDispositionSequence() {
        switch disposition {
        // Use last state for same session after authorization.
        case .useAuthorizedScreenState(let account):
          self.screenStateAccount = account
          switch self.screenStateCache {
          case .cached(let cached, for: account):
            self.screenStateCache = .none
            self.replaceRoot(with: cached)

          case .cached, .none:
            self.screenStateCache = .none
            let navigationToSplashScreen: NavigationToSplashScreen =
              try self.features.instance()
            try await navigationToSplashScreen.perform(context: account)
          }

        // Go to initial screen state (through Splash)
        // which will be one of:
        // - welcome (no accounts)
        // - home (for authorized)
        // - account selection (for unauthorized)
        case .useInitialScreenState:

          self.screenStateCache = .none
          let navigationToSplashScreen: NavigationToSplashScreen =
            try self.features.instance()
          try await navigationToSplashScreen.perform(context: .none)

        // Prompt user with authorization screen if it is not already displayed.
        case .requestPassphrase(let account, _):
          guard
            !self.isAuthorizationDisplayed
          else { return }

          if self.screenStateAccount == account {
            if !self.isMFAPromptDisplayed {
              assert(
                self.screenStateCache == nil,
                "Cannot replace screen state cache, it has to be empty"
              )

              guard
                let currentRootController: UIViewController = self.window
                  .rootViewController
              else { return }
              self.screenStateCache = .cached(
                currentRootController,
                for: account
              )
            } else {
              /* NOP - reuse previous cache if any if previous screen was mfa prompt */
            }
          } else {
            self.screenStateCache = .none
            self.screenStateAccount = account
          }

          let navigationToAccountSelection: NavigationToAccountSelection =
            try self.features.instance()
          try await navigationToAccountSelection.perform(
            context: .init(isSignIn: true)
          )

          let navigationToAuthorization: NavigationToAuthorization =
            try self.features.instance()
          try await navigationToAuthorization.perform(
            animated: false,
            context: account
          )

        // Prompt user with mfa screen if it is not already displayed.
        case .requestMFA(let account, let providers):
          guard
            !self.isMFAPromptDisplayed
          else { return }

          if !self.isAuthorizationDisplayed {
            if self.screenStateAccount == account {
              assert(
                self.screenStateCache == nil,
                "Cannot replace screen state cache, it has to be empty"
              )
              guard
                let currentRootController: UIViewController = self.window
                  .rootViewController
              else { return }
              self.screenStateCache = .cached(
                currentRootController,
                for: account
              )
            } else {
              self.screenStateCache = .none
              self.screenStateAccount = account
            }
          }
          if providers.isEmpty {
            let navigationToResult: NavigationToUnsupportedMFA =
              try self.features.instance()
            try await navigationToResult.perform()
            return
          }

          let navigationToMFA: NavigationToMFA = try self.features.instance()
          try await navigationToMFA.perform(context: providers)
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

  private var isAuthorizationDisplayed: Bool {
    guard let navigation = window.rootViewController as? UINavigationController
    else { return false }

    if navigation.contains(AuthorizationView.self) || navigation.contains(TransferSignInView.self) {
      return isMFAPromptDisplayed
    }
    return false
  }

  private var isMFAPromptDisplayed: Bool {
    guard let navigation = window.rootViewController as? UINavigationController
    else { return false }
    return navigation.contains(MFAView.self)
  }
}

extension Window {

  private func replaceRoot(
    with component: UIViewController,
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

extension UINavigationController {

  fileprivate func contains<V>(_ view: V.Type) -> Bool where V: ControlledView {
    viewControllers.contains { $0 is UIHostingController<V> }
  }
}
