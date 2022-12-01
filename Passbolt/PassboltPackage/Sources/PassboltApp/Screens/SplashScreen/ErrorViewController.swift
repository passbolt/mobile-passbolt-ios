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
    using controller: Controller,
    with components: UIComponentFactory,
    cancellables: Cancellables
  ) -> Self {
    Self(
      using: controller,
      with: components,
      cancellables: cancellables
    )
  }

  internal private(set) var contentView: ErrorView = .init()
  internal var components: UIComponentFactory

  private var controller: Controller

  internal init(
    using controller: Controller,
    with components: UIComponentFactory,
    cancellables: Cancellables
  ) {
    self.controller = controller
    self.components = components
    super.init(
      cancellables: cancellables
    )
  }

  internal func setupView() {
    setupSubscriptions()
  }

  private func setupSubscriptions() {
    self.contentView
      .refreshTapPublisher
      .asyncMap { [unowned self] in
        self.present(
          overlay: LoaderOverlayView(
            longLoadingMessage: (
              message: .localized(
                key: .loadingLong
              ),
              delay: 5
            )
          )
        )
        do {
          try await self.controller.retry()
          self.dismissOverlay()
        }
        catch {
          self.dismissOverlay()
          self.presentErrorSnackbar(
            error.asTheError().displayableMessage
          )
        }
      }
      .sinkDrop()
      .store(in: cancellables)

    contentView.signOutTapPublisher
      .sink { [unowned self] in
        self.controller.presentSignOut()
      }
      .store(in: cancellables)

    controller.signOutAlertPresentationPublisher()
      .sink { [weak self] in
        self?.cancellables.executeOnMainActor { [weak self] in
          await self?.present(SignOutAlertViewController.self)
        }
      }
      .store(in: cancellables)
  }
}
