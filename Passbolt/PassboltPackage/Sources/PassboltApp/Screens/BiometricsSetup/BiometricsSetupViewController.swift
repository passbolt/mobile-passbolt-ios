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

import AccountSetup
import UIComponents

internal final class BiometricsSetupViewController: PlainViewController, UIComponent {

  internal typealias ContentView = BiometricsSetupView
  internal typealias Controller = BiometricsSetupController

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

  internal private(set) lazy var contentView: ContentView = .init()
  internal let components: UIComponentFactory

  private let controller: Controller

  internal init(
    using controller: Controller,
    with components: UIComponentFactory,
    cancellables: Cancellables
  ) {
    self.controller = controller
    self.components = components
    super
      .init(
        cancellables: cancellables
      )
  }

  internal func setupView() {
    mut(navigationItem) {
      .hidesBackButton(true)
    }
    setupSubscriptions()
  }

  private func setupSubscriptions() {
    controller
      .biometricsStatePublisher()
      .receive(on: RunLoop.main)
      .sink { [weak self] biometricsState in
        self?.contentView.update(for: biometricsState)
      }
      .store(in: cancellables)

    contentView
      .setupTapPublisher
      .sink { [weak self] in
        guard let self = self else { return }
        self.controller
          .setupBiometrics()
          .receive(on: RunLoop.main)
          .sink(receiveCompletion: { [weak self] completion in
            guard case .failure = completion
            else { return }
            self?
              .present(
                snackbar: Mutation<UICommons.PlainView>
                  .snackBarErrorMessage(
                    .localized(
                      key: .genericError
                    )
                  )
                  .instantiate(),
                hideAfter: 2
              )
          })
          .store(in: self.cancellables)
      }
      .store(in: cancellables)

    contentView
      .skipTapPublisher
      .sink { [weak self] in
        guard let self = self else { return }
        self.controller.skipSetup()
      }
      .store(in: cancellables)

    controller
      .destinationPresentationPublisher()
      .sink { [weak self] destination in
        self?.cancellables
          .executeOnMainActor {
            switch destination {
            case .extensionSetup:
              await self?.push(ExtensionSetupViewController.self)
            case .finish:
              await self?.dismiss(Self.self)
            }
          }
      }
      .store(in: cancellables)
  }
}
