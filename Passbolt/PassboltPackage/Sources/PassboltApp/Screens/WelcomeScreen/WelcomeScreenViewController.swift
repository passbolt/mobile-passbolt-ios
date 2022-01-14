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

import AccountSetup
import SharedUIComponents
import UIComponents

internal final class WelcomeScreenViewController: PlainViewController, UIComponent {

  internal typealias View = WelcomeScreenView
  internal typealias Controller = WelcomeScreenController

  internal static func instance(
    using controller: WelcomeScreenController,
    with components: UIComponentFactory
  ) -> Self {
    Self(
      using: controller,
      with: components
    )
  }

  internal private(set) lazy var contentView: WelcomeScreenView = .init()
  internal let components: UIComponentFactory

  private let controller: WelcomeScreenController

  internal init(
    using controller: Controller,
    with components: UIComponentFactory
  ) {
    self.controller = controller
    self.components = components
    super.init()
  }

  internal func setupView() {
    mut(navigationItem) {
      .rightBarButtonItem(
        Mutation<UIBarButtonItem>
          .combined(
            .image(named: .help, from: .uiCommons),
            .action { [weak self] in
              self?.presentSheetMenu(HelpMenuViewController.self, in: [])
            }
          )
          .instantiate()
      )
    }

    setupSubscriptions()
  }

  private func setupSubscriptions() {
    contentView.tapAccountPublisher
      .receive(on: RunLoop.main)
      .sink { [weak self] in
        self?.controller.pushTransferInfo()
      }
      .store(in: cancellables)

    contentView.tapNoAccountPublisher
      .receive(on: RunLoop.main)
      .sink { [weak self] in
        self?.controller.presentNoAccountAlert()
      }
      .store(in: cancellables)

    controller.noAccountAlertPresentationPublisher()
      .receive(on: RunLoop.main)
      .sink { [weak self] presented in
        guard let self = self else { return }
        if presented {
          self.present(
            WelcomeScreenNoAccountAlertViewController.self,
            in: self.controller.dismissNoAccountAlert
          )
        }
        else {
          self.dismiss(WelcomeScreenNoAccountAlertViewController.self)
        }
      }
      .store(in: cancellables)

    controller.pushTransferInfoPublisher()
      .receive(on: RunLoop.main)
      .sink { [weak self] in
        guard let self = self else { return }
        let viewController: TransferInfoScreenViewController = self.components.instance()
        self.navigationController?.pushViewController(viewController, animated: true)
      }
      .store(in: cancellables)
  }
}
