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

import SharedUIComponents
import UIComponents

internal final class SplashScreenViewController: PlainViewController, UIComponent {

  internal typealias ContentView = SplashScreenView
  internal typealias Controller = SplashScreenController

  internal static func instance(
    using controller: Controller,
    with components: UIComponentFactory
  ) -> Self {
    Self(
      using: controller,
      with: components
    )
  }

  internal private(set) lazy var contentView: SplashScreenView = .init()
  internal let components: UIComponentFactory
  private let controller: SplashScreenController

  internal init(
    using controller: SplashScreenController,
    with components: UIComponentFactory
  ) {
    self.controller = controller
    self.components = components
    super.init()
  }

  internal func setupView() {
    mut(contentView) {
      .backgroundColor(dynamic: .background)
    }

    setupSubscriptions()
  }

  private func setupSubscriptions() {
    controller
      .navigationDestinationPublisher()
      .delay(for: 0.3, scheduler: RunLoop.main)
      .receive(on: RunLoop.main)
      .sink { [weak self] destination in
        Task { [weak self] in
          let presentUpdateAlert: Bool = await self?.controller.shouldDisplayUpdateAlert() ?? false
          if presentUpdateAlert {
            self?.present(
              UpdateAvailableViewController.self,
              in: { [weak self] in
                self?.navigate(to: destination)
              }
            )
          }
          else {
            self?.navigate(to: destination)
          }
        }

      }
      .store(in: cancellables)
  }

  private func navigate(to destination: Controller.Destination) {
    showFeedbackAlertIfNeeded(presentationAnchor: self) { [weak self] in
      switch destination {
      case let .accountSelection(lastAccount, message):
        self?.replaceWindowRoot(
          with: AuthorizationNavigationViewController.self,
          in: (
            account: lastAccount,
            message: message
          )
        )

      case .accountSetup:
        self?.replaceWindowRoot(
          with: WelcomeNavigationViewController.self
        )

      case .diagnostics:
        self?.replaceWindowRoot(
          with: PlainNavigationViewController<LogsViewerViewController>.self
        )

      case .home:
        self?.replaceWindowRoot(
          with: MainTabsViewController.self
        )

      case let .mfaAuthorization(mfaProviders):
        if mfaProviders.isEmpty {
          self?.replaceWindowRoot(
            with: PlainNavigationViewController<UnsupportedMFAViewController>.self
          )
        }
        else {
          self?.replaceWindowRoot(
            with: PlainNavigationViewController<MFARootViewController>.self,
            in: mfaProviders
          )
        }

      case .featureConfigFetchError:
        self?.present(
          ErrorViewController.self,
          in: { [weak self] in
            guard let self = self
            else { return Empty().eraseToAnyPublisher() }

            return self.controller.retryFetchConfiguration()
          }
        )
      }
    }
  }
}
