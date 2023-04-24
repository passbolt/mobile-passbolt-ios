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

import AuthenticationServices
import SharedUIComponents
import UICommons
import UIComponents

internal final class AccountSelectionViewController: PlainViewController, UIComponent {

  internal typealias ContentView = AccountSelectionView
  internal typealias Controller = AccountSelectionController

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

  internal private(set) lazy var contentView: AccountSelectionView = .init(
    mode: controller.screenMode()
  )
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

  internal func setup() {
    setupNavigationBar()
  }

  internal func setupView() {
    setupSubscriptions()
  }

  private func setupNavigationBar() {
    mut(navigationItem) {
      .rightBarButtonItem(
        Mutation<UIBarButtonItem>
          .combined(
            .image(named: .close, from: .uiCommons),
            .action { [weak self] in
              self?.controller.closeExtension()
            }
          )
          .instantiate()
      )
    }
  }

  private func setupSubscriptions() {
    controller
      .accountsPublisher()
      .receive(on: RunLoop.main)
      .sink(
        receiveValue: { [weak self] items in
          self?.contentView.update(items: items)
        }
      )
      .store(in: cancellables)

    contentView
      .accountTapPublisher
      .sink { [weak self] item in
        self?.controller.selectAccount(item.account)
      }
      .store(in: cancellables)
  }
}
