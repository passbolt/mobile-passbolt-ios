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

import Environment
import UIComponents

internal final class TransferInfoScreenViewController: PlainViewController, UIComponent {
  
  internal typealias View = TransferInfoScreenView
  internal typealias Controller = TransferInfoScreenController
  
  internal static func instance(
    using controller: TransferInfoScreenController,
    with components: UIComponentFactory
  ) -> Self {
    Self(
      using: controller,
      with: components
    )
  }
  
  internal private(set) lazy var contentView: TransferInfoScreenView = .init()
  internal let components: UIComponentFactory
  
  private let controller: TransferInfoScreenController
  private var cancellables: Array<AnyCancellable> = .init()
  
  internal init(
    using controller: Controller,
    with components: UIComponentFactory
  ) {
    self.controller = controller
    self.components = components
    super.init()
  }
  
  internal func setupView() {
    mut(self) {
      .title(localized: "transfer.account.title")
    }
        
    setupSubscriptions()
  }
  
  private func setupSubscriptions() {
    contentView.tapButtonPublisher
      .compactMap { [weak self] in
        self?.controller.requestOrNavigatePublisher()
      }
      .switchToLatest()
      .receive(on: RunLoop.main)
      .sink { [weak self] granted in
        guard let self = self else { return }
        
        if granted {
          self.push(CodeScanningViewController.self)
        } else {
          self.controller.presentNoCameraPermissionAlert()
        }
      }
      .store(in: &cancellables)
    
    controller.presentNoCameraPermissionAlertPublisher()
      .receive(on: RunLoop.main)
      .sink { [weak self] presented in
        guard let self = self else { return }
        
        if presented {
          self.present(TransferInfoCameraRequiredAlertViewController.self)
        } else {
          self.dismiss(TransferInfoCameraRequiredAlertViewController.self)
        }
      }
      .store(in: &cancellables)
  }
}
