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

import UIComponents

internal final class CodeScanningViewController: PlainViewController, UIComponent {

  internal typealias View = CodeScanningView
  internal typealias Controller = CodeScanningController

  internal static func instance(
    using controller: Controller,
    with components: UIComponentFactory
  ) -> Self {
    Self(
      using: controller,
      with: components
    )
  }

  internal private(set) lazy var contentView: View = .init()
  internal let components: UIComponentFactory
  private let controller: Controller
  private let progressView: ProgressView = .init()

  internal init(
    using controller: Controller,
    with components: UIComponentFactory
  ) {
    self.controller = controller
    self.components = components
    super.init()
  }

  internal func setupView() {
    setupNavigationBar()
    setupCodeReaderView()
    setupSubscriptions()
  }

  private func setupNavigationBar() {
    mut(progressView) {
      .combined(
        .tintColor(dynamic: .secondaryRed)
      )
    }
    mut(navigationItem) {
      .combined(
        .leftBarButtonItem(
          Mutation<UIBarButtonItem>
            .combined(
              .backStyle(),
              .accessibilityIdentifier("button.exit"),
              .action { [weak self] in
                self?.controller.presentExitConfirmation()
              }
            )
            .instantiate()
        ),
        .titleView(progressView),
        .rightBarButtonItem(
          Mutation<UIBarButtonItem>
            .combined(
              .style(.done),
              .image(named: .help, from: .uiCommons),
              .accessibilityIdentifier("button.help"),
              .action { [weak self] in
                self?.controller.presentHelp()
              }
            )
            .instantiate()
        )
      )
    }
  }

  private func setupCodeReaderView() {
    addChild(
      CodeReaderViewController.self,
      viewSetup: { parentView, childView in
        parentView.set(embeded: childView)
      }
    )
  }

  private func setupSubscriptions() {
    controller
      .progressPublisher()
      .receive(on: RunLoop.main)
      .sink { [weak self] progress in
        self?.progressView.update(progress: progress, animated: true)
      }
      .store(in: cancellables)

    controller
      .exitConfirmationPresentationPublisher()
      .receive(on: RunLoop.main)
      .sink { [weak self] presented in
        if presented {
          self?.present(CodeScanningExitConfirmationViewController.self)
        }
        else {
          self?.dismiss(CodeScanningExitConfirmationViewController.self)
        }
      }
      .store(in: cancellables)

    controller
      .helpPresentationPublisher()
      .receive(on: RunLoop.main)
      .sink { [weak self] presented in
        if presented {
          self?.present(CodeScanningHelpViewController.self)
        }
        else {
          self?.dismiss(CodeScanningExitConfirmationViewController.self)
        }
      }
      .store(in: cancellables)

    controller
      .resultPresentationPublisher()
      .receive(on: RunLoop.main)
      .sink(
        receiveCompletion: { [weak self] completion in
          switch completion {
          case .finished:
            self?.push(
              CodeScanningSuccessViewController.self,
              completion: { [weak self] in
                self?.popAll(Self.self, animated: false)
              }
            )

          case .failure(.canceled):
            switch self?.navigationController {
            case .some(_ as WelcomeNavigationViewController):
              self?.popToRoot()

            case .some(_ as AuthorizationNavigationViewController):
              self?.pop(to: AccountSelectionViewController.self)

            case .some:
              if self?.pop(to: AccountSelectionViewController.self) ?? false {
                /* NOP */
              }
              else {
                self?.popToRoot()
              }

            case .none:
              self?.dismiss(Self.self)
            }

          case .failure(.duplicateAccount):
            self?.push(
              CodeScanningDuplicateViewController.self,
              completion: { [weak self] in
                self?.popAll(Self.self, animated: false)
              }
            )

          case let .failure(error):
            self?.push(
              AccountTransferFailureViewController.self,
              in: error
            )
          }
        },
        receiveValue: { _ in }
      )
      .store(in: cancellables)
  }
}
