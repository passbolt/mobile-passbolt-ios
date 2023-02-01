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
import UICommons
import UIComponents
import UIKit

internal final class AccountMenuViewController: PlainViewController, UIComponent {

  internal typealias ContentView = AccountMenuView
  internal typealias Controller = AccountMenuController

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

  internal private(set) lazy var contentView: ContentView = .init(
    currentAcountWithProfile: controller.currentAccountWithProfile,
    currentAcountAvatarImagePublisher:
      controller
      .currentAcountAvatarImagePublisher()
      .map { data -> UIImage? in
        data.flatMap { UIImage(data: $0) }
      }
      .eraseToAnyPublisher()
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
    super.init(
      cancellables: cancellables
    )
  }

  internal func setupView() {
    title =
      DisplayableString
      .localized("account.menu.title")
      .string()

    controller
      .dismissPublisher()
      .sink { [weak self] in
        self?.cancellables.executeOnMainActor { [weak self] in
          await self?.dismiss(SheetMenuViewController<AccountMenuViewController>.self)
        }
      }
      .store(in: cancellables)

    contentView
      .signOutTapPublisher
      .sink { [unowned self] in
        self.controller.signOut()
      }
      .store(in: cancellables)

    contentView
      .accountDetailsTapPublisher
      .sink { [unowned self] in
        self.controller.presentAccountDetails()
      }
      .store(in: cancellables)

    controller
      .accountDetailsPresentationPublisher()
      .sink { [weak self] accountWithProfile in
        self?.cancellables.executeOnMainActor { [weak self] in
          guard let self = self else { return }
          await self.dismiss(
            AccountMenuViewController.self
          )
          await self.controller.navigation
            .push(
              legacy: AccountDetailsViewController.self,
              context: accountWithProfile
            )
        }
      }
      .store(in: cancellables)

    contentView
      .accountSwitchTapPublisher
      .sink { [unowned self] account in
        self.controller.presentAccountSwitch(account)
      }
      .store(in: cancellables)

    controller
      .accountSwitchPresentationPublisher()
      .receive(on: RunLoop.main)
      .sink { [weak self] account in
        self?.cancellables.executeOnMainActor { [weak self] in
          guard let self = self else { return }
          await self.dismiss(
            AccountMenuViewController.self
          )
          await self.controller.navigation
            .push(
              legacy: AuthorizationViewController.self,
              context: account
            )
        }
      }
      .store(in: cancellables)

    contentView
      .manageAccountsTapPublisher
      .sink { [unowned self] in
        self.controller.presentManageAccounts()
      }
      .store(in: cancellables)

    controller
      .manageAccountsPresentationPublisher()
      .receive(on: RunLoop.main)
      .sink { [weak self] in
        self?.cancellables.executeOnMainActor { [weak self] in
          guard let self = self else { return }
          await self.dismiss(
            AccountMenuViewController.self
          )
          await self.controller.navigation
            .push(
              legacy: AccountSelectionViewController.self,
              context: .init(value: true)
            )
        }
      }
      .store(in: cancellables)

    controller
      .accountsListPublisher()
      .receive(on: RunLoop.main)
      .sink { [weak self] accounts in
        self?.contentView
          .updateAccountsList(
            accounts:
              accounts
              .map { account in
                (
                  accountWithProfile: account.accountWithProfile,
                  avatarImagePublisher: account
                    .avatarImagePublisher
                    .map { data -> UIImage? in
                      data.flatMap(UIImage.init(data:))
                    }
                    .eraseToAnyPublisher()
                )
              }
          )
      }
      .store(in: cancellables)
  }
}
