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

  internal typealias ContentView = WelcomeScreenView
  internal typealias Controller = WelcomeScreenController

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

  internal private(set) lazy var contentView: WelcomeScreenView = .init()
  internal let components: UIComponentFactory

  private let controller: WelcomeScreenController

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
    // Listen to NotificationCenter for the help menu
    NotificationCenter.default.addObserver(
      self,
      selector: #selector(handleHelpMenuAccountkitAction),
      name: .helpMenuActionAccountKitNotification,
      object: nil
    )
  }

  internal func setupView() {
    mut(navigationItem) {
      .rightBarButtonItem(
        Mutation<UIBarButtonItem>
          .combined(
            .image(named: .help, from: .uiCommons),
            .action { [weak self] in
              self?.cancellables
                .executeOnMainActor { [weak self] in
                  await self?.presentSheetMenu(HelpMenuViewController.self, in: [])
                }
            }
          )
          .instantiate()
      )
    }

    setupSubscriptions()
  }

  /**
   * Handles the action triggered by the Help menu for AccountKit-related notifications.
   *
   * This function checks the type of notification and navigates to the appropriate view controller.
   * If the notification contains `AccountTransferData`, it navigates to the success view controller.
   * Otherwise, it checks for specific error types and navigates to corresponding error view controllers.
   *
   * @param notification The notification object received, which contains either `AccountTransferData`
   *                     or an error object indicating the type of error encountered.
   */
  @objc private func handleHelpMenuAccountkitAction(notification: Notification) {
    // Perform the navigation or other actions when the notification is received
    guard let accountTransferData = notification.object as? AccountTransferData else {
      Task {
        // Determine the error type from the notification object
        switch notification.object {
        case is AccountKitImportFailure:
          await self.push(AccountKitImportFailureViewController.self, animated: true)
        case is AccountKitImportInvalidSignature:
          await self.push(AccountKitSignatureErrorViewController.self, animated: true)
        case is AccountKitAccountAlreadyExist:
          await self.push(AccountKitAccountAlreadyExistViewController.self, animated: true)
        default:
          // If the error type is not recognized, do not perform any navigation
          return
        }
      }
      // Do not go further
      return
    }
    // If AccountTransferData is present, navigate to the success view controller
    Task {
      await self.push(
        AccountKitTransferSuccessViewController.self,
        in: accountTransferData,
        animated: true
      )
    }
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
        self?.cancellables
          .executeOnMainActor { [weak self] in
            guard let self = self else { return }
            if presented {
              await self.present(
                WelcomeScreenNoAccountAlertViewController.self,
                in: self.controller.dismissNoAccountAlert
              )
            }
            else {
              await self.dismiss(WelcomeScreenNoAccountAlertViewController.self)
            }
          }
      }
      .store(in: cancellables)

    controller.pushTransferInfoPublisher()
      .sink { [weak self] in
        self?.cancellables
          .executeOnMainActor { [weak self] in
            await self?
              .push(
                TransferInfoScreenViewController.self,
                in: .import
              )
          }
      }
      .store(in: cancellables)
  }
}
