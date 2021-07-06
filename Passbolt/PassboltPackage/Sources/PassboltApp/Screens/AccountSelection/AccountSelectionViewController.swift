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

import UICommons
import UIComponents

internal final class AccountSelectionViewController: PlainViewController, UIComponent {

  internal typealias View = AccountSelectionView
  internal typealias Controller = AccountSelectionController

  internal static func instance(
    using controller: AccountSelectionController,
    with components: UIComponentFactory
  ) -> Self {
    Self(
      using: controller,
      with: components
    )
  }

  internal private(set) lazy var contentView: AccountSelectionView = .init()
  internal let components: UIComponentFactory

  private let controller: Controller

  internal init(
    using controller: Controller,
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
    controller.accountsPublisher()
      .receive(on: RunLoop.main)
      .sink(
        receiveCompletion: { [weak self] _ in
          self?.replaceWindowRoot(with: WelcomeNavigationViewController.self)
        },
        receiveValue: { [weak self] items in
          self?.contentView.update(items: items)
        }
      )
      .store(in: cancellables)

    controller.modePublisher()
      .receive(on: RunLoop.main)
      .sink { [weak self] mode in
        self?.contentView.update(mode: mode)
      }
      .store(in: cancellables)

    contentView.accountTapPublisher
      .sink { [weak self] item in
        self?.push(
          AuthorizationViewController.self,
          in: item.localID
        )
      }
      .store(in: cancellables)

    contentView.removeTapPublisher
      .sink { [weak self] _ in
        self?.controller.changeMode(.removal)
      }
      .store(in: cancellables)

    contentView.doneTapPublisher
      .sink { [weak self] _ in
        self?.controller.changeMode(.selection)
      }
      .store(in: cancellables)

    contentView.removeAccountPublisher
      .sink { [weak self] item in
        let removeAccount: () -> Void = { [weak self] in
          guard let self = self else { return }

          self.controller.changeMode(.selection)

          guard case Result.failure = self.controller.removeAccount(item.localID) else {
            return
          }

          self.present(
            snackbar: Mutation<View>
              .snackBarErrorMessage(
                localized: .genericError,
                inBundle: .commons
              )
              .instantiate(),
            hideAfter: 2
          )
        }

        self?.present(
          RemoveAccountAlertViewController.self,
          in: removeAccount
        )
      }
      .store(in: cancellables)
  }
}
