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

internal final class MFARequiredViewController: PlainViewController, UIComponent, CustomPresentableUIComponent {

  internal typealias View = MFARequiredView
  internal typealias Controller = MFARequiredController

  internal static func instance(
    using controller: Controller,
    with components: UIComponentFactory
  ) -> Self {
    Self(
      using: controller,
      with: components
    )
  }

  internal private(set) var contentView: View = .init()
  internal var components: UIComponentFactory

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
    customPresentationSetup()
    setupSubscriptions()
  }

  private func setupSubscriptions() {
    contentView.tapPublisher
      .map { [unowned self] _ -> AnyPublisher<Bool, Never> in
        self.controller.openApp()
          .handleEvents(receiveOutput: { didOpen in
            guard !didOpen else { return }

            self.present(
              snackbar: Mutation<UICommons.View>
                .snackBarErrorMessage(
                  localized: "generic.failed.open.app"
                )
                .instantiate()
            )
          })
          .eraseToAnyPublisher()
      }
      .switchToLatest()
      .sinkDrop()
      .store(in: cancellables)
  }
}

