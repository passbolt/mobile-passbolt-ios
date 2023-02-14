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

@MainActor
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
    shouldHideTitle: controller.shouldHideTitle()
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
    mut(navigationItem) {
      .rightBarButtonItem(
        Mutation<UIBarButtonItem>
          .combined(
            .image(named: .help, from: .uiCommons),
            .action { [weak self] in
              self?.cancellables.executeOnMainActor { [weak self] in
                await self?.presentSheetMenu(HelpMenuViewController.self, in: [])
              }
            }
          )
          .instantiate()
      )
    }

    setupSubscriptions()
  }

  private func setupSubscriptions() {
    controller
      .accountsPublisher()
      .receive(on: RunLoop.main)
      .sink(
        receiveValue: { [weak self] items in
          self?.cancellables.executeOnMainActor { [weak self] in
            // After removing last account, window controller takes care of navigation to proper screen when removing current account.
            if items.isEmpty, self?.view.window != nil {
              await self?.replaceWindowRoot(
                with: SplashScreenViewController.self,
                in: .none
              )
            }
            else {
              self?.contentView.update(items: items)
            }
          }
        }
      )
      .store(in: cancellables)

    controller
      .listModePublisher()
      .receive(on: RunLoop.main)
      .sink { [weak self] mode in
        self?.contentView.update(mode: mode)
      }
      .store(in: cancellables)

    contentView
      .accountTapPublisher
      .sink { [weak self] item in
        self?.cancellables.executeOnMainActor { [weak self] in
          if item.isCurrentAccount && !(self?.navigationController is AuthorizationNavigationViewController) {
            await self?.popToRoot()
          }
          else {
            await self?.push(
              AuthorizationViewController.self,
              in: item.account
            )
          }
        }
      }
      .store(in: cancellables)

    contentView
      .removeTapPublisher
      .sink { [weak self] _ in
        self?.controller.toggleMode()
      }
      .store(in: cancellables)

    contentView
      .doneTapPublisher
      .sink { [weak self] _ in
        self?.controller.toggleMode()
      }
      .store(in: cancellables)

    contentView
      .removeAccountPublisher
      .sink { [weak self] item in
        let removeAccount: @MainActor () -> AnyPublisher<Void, Never> = { [weak self] in
          guard let self = self
          else { return Just(Void()).eraseToAnyPublisher() }

          self.controller.toggleMode()

          return self.controller
            .removeAccount(item.account)
            .handleValues { [weak self] in
              self?.cancellables.executeOnMainActor { [weak self] in
                self?.presentInfoSnackbar(
                  .localized(
                    key: "account.selection.account.removed"
                  )
                )
              }
            }
            .handleErrors { [weak self] error in
              self?.cancellables.executeOnMainActor { [weak self] in
                self?.present(
                  snackbar: Mutation<ContentView>
                    .snackBarErrorMessage(
                      error.displayableMessage
                    )
                    .instantiate(),
                  hideAfter: 2
                )
              }
            }
            .replaceError(with: Void())
            .eraseToAnyPublisher()
        }

        self?.cancellables.executeOnMainActor { [weak self] in
          await self?.present(
            RemoveAccountAlertViewController.self,
            in: removeAccount
          )
        }
      }
      .store(in: cancellables)

    contentView
      .addAccountTapPublisher
      .sink { [weak self] in
        self?.controller.addAccount()
      }
      .store(in: cancellables)

    controller
      .addAccountPresentationPublisher()
      .sink { [weak self] accountTransferInProgress in
        self?.cancellables.executeOnMainActor { [weak self] in
          if accountTransferInProgress {
            self?.presentErrorSnackbar(
              .localized("error.another.account.transfer.in.progress")
            )
          }
          else {
            await self?.push(
              TransferInfoScreenViewController.self,
              in: .import
            )
          }
        }
      }
      .store(in: cancellables)
  }
}
