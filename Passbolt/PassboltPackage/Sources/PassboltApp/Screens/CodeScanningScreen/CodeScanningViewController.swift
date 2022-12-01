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

import Session
import SharedUIComponents
import UIComponents

internal final class CodeScanningViewController: PlainViewController, UIComponent {

  internal typealias ContentView = CodeScanningView
  internal typealias Controller = CodeScanningController

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
  private let progressView: ProgressView = .init()

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
    self.cancellables.executeOnMainActor { [weak self] in
      guard let self = self else { return }
      await self.addChild(
        CodeReaderViewController.self,
        viewSetup: { parentView, childView in
          parentView.set(embeded: childView)
        }
      )
    }
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
      .sink { [weak self] presented in
        self?.cancellables.executeOnMainActor { [weak self] in
          if presented {
            await self?.present(CodeScanningExitConfirmationViewController.self)
          }
          else {
            await self?.dismiss(CodeScanningExitConfirmationViewController.self)
          }
        }
      }
      .store(in: cancellables)

    controller
      .helpPresentationPublisher()
      .receive(on: RunLoop.main)
      .sink { [weak self] presented in
        self?.cancellables.executeOnMainActor { [weak self] in
          if presented {
            await self?.presentSheetMenu(
              HelpMenuViewController.self,
              in: [
                .init(
                  iconName: .camera,
                  iconBundle: .uiCommons,
                  title: .localized("code.scanning.help.menu.button.title"),
                  handler: { [weak self] in
                    self?.cancellables.executeOnMainActor { [weak self] in
                      await self?.dismiss(
                        HelpMenuViewController.self
                      )
                      await self?.present(CodeScanningHelpViewController.self)
                    }
                  }
                )
              ]
            )
          }
          else {
            await self?.dismiss(HelpMenuViewController.self)
          }
        }
      }
      .store(in: cancellables)

    controller
      .resultPresentationPublisher()
      .receive(on: RunLoop.main)
      .sink(
        receiveCompletion: { [weak self] completion in
          self?.cancellables.executeOnMainActor { [weak self] in
            switch completion {
            case .finished:
              await self?.push(
                CodeScanningSuccessViewController.self
              )
              await self?.popAll(Self.self, animated: false)

            case let .failure(error) where error is Cancelled:
              switch self?.navigationController {
              case .some(_ as WelcomeNavigationViewController):
                await self?.popToRoot()

              case .some(_ as AuthorizationNavigationViewController):
                await self?.pop(to: AccountSelectionViewController.self)

              case .some:
                if await self?.pop(to: AccountSelectionViewController.self) ?? false {
                  /* NOP */
                }
                else {
                  await self?.popToRoot()
                }

              case .none:
                await self?.dismiss(Self.self)
              }

            case let .failure(error) where error is AccountDuplicate:
              await self?.push(
                CodeScanningDuplicateViewController.self
              )
              await self?.popAll(Self.self, animated: false)

            case let .failure(error):
              await self?.push(
                AccountTransferFailureViewController.self,
                in: error
              )
            }
          }
        },
        receiveValue: { _ in }
      )
      .store(in: cancellables)
  }
}
