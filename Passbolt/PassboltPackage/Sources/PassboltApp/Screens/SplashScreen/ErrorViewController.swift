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

final class ErrorViewController: PlainViewController, UIComponent {

  internal typealias ContentView = ErrorView
  internal typealias Controller = ErrorController

  internal static func instance(
    using controller: ErrorController,
    with components: UIComponentFactory
  ) -> Self {
    Self(
      using: controller,
      with: components
    )
  }

  internal private(set) var contentView: ErrorView = .init()
  internal var components: UIComponentFactory

  private var controller: Controller

  internal init(
    using controller: Controller,
    with components: UIComponentFactory
  ) {
    self.controller = controller
    self.components = components
    super.init()
  }

  internal func setupView() {
    setupSubscriptions()
  }

  private func setupSubscriptions() {
    contentView.refreshTapPublisher
      .map { [unowned self] in
        self.controller
          .retry()
          .receive(on: RunLoop.main)
          .handleEvents(
            receiveSubscription: { [weak self] _ in
              self?.present(
                overlay: LoaderOverlayView(
                  longLoadingMessage: (
                    message: .localized(
                      key: .loadingLong
                    ),
                    delay: 5
                  )
                )
              )
            }
          )
      }
      .switchToLatest()
      .receive(on: RunLoop.main)
      .sink { [weak self] result in
        self?.dismissOverlay()

        guard result == nil
        else { return }
        self?.present(
          snackbar: Mutation<UICommons.PlainView>
            .snackBarErrorMessage(
              .localized(
                key: .genericError
              )
            )
            .instantiate()
        )
      }
      .store(in: cancellables)

    contentView.signOutTapPublisher
      .sink { [unowned self] in
        self.controller.presentSignOut()
      }
      .store(in: cancellables)

    controller.signOutAlertPresentationPublisher()
      .receive(on: RunLoop.main)
      .sink { [weak self] in
        self?.present(SignOutAlertViewController.self)
      }
      .store(in: cancellables)
  }
}
