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
  private var cancellables: Array<AnyCancellable> = .init()
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
              .action { [weak self] in
                self?.controller.presentExitConfirmation()
              }
            )
            .instantiate()
        ),
        .titleView(progressView),
        .rightBarButtonItem(
          Mutation<UIBarButtonItem>
            .placeholderStyle()
            .instantiate()
        )
      )
    }
  }
  
  private func setupCodeReaderView() {
    #warning("TODO: [PAS-39] Use code reader (camera) component")
  }
  
  private func setupSubscriptions() {
    controller
      .progressPublisher()
      .receive(on: RunLoop.main)
      .sink { [weak self] progress in
        self?.progressView.update(progress: progress, animated: true)
      }
      .store(in: &cancellables)
    controller
      .exitConfirmationPresentationPublisher()
      .receive(on: RunLoop.main)
      .sink { [weak self] presented in
        self?.setExitConfirmation(presented: presented)
      }
      .store(in: &cancellables)
  }
  
  private func setExitConfirmation(presented: Bool) {
    var presentedLeaf: UIViewController = self
    while let next: UIViewController = presentedLeaf.presentedViewController {
      if next is CodeScanningExitConfirmationViewController, !presented {
        return presentedLeaf.dismiss(animated: true)
      } else {
        presentedLeaf = next
      }
    }
    if presented {
      presentedLeaf.present(
        components
          .instance(
            of: CodeScanningExitConfirmationViewController.self,
            in: CodeScanningExitConfirmationController.Context(
              cancel: controller.dismissExitConfirmation,
              exit: { [weak self] in self?.navigationController?.popViewController(animated: true) }
            )
          ),
        animated: true,
        completion: nil
      )
    } else { /* */ }
  }
}
