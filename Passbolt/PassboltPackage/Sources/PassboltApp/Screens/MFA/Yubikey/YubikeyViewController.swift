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

import NFC
import UICommons
import UIComponents

internal final class YubikeyViewController: PlainViewController, UIComponent {

  internal typealias View = YubikeyView
  internal typealias Controller = YubikeyController

  internal static func instance(
    using controller: Controller,
    with components: UIComponentFactory
  ) -> Self {
    Self(
      using: controller,
      with: components
    )
  }

  internal lazy var contentView: View = .init()

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
    setupSubscriptions()
  }

  private func setupSubscriptions() {
    contentView.toggleRememberDevicePublisher
      .receive(on: RunLoop.main)
      .sink { [weak self] in
        self?.controller.toggleRememberDevice()
      }
      .store(in: cancellables)

    controller.rememberDevicePublisher()
      .receive(on: RunLoop.main)
      .sink { [weak self] rememberDevice in
        self?.contentView.update(rememberDevice: rememberDevice)
      }
      .store(in: cancellables)

    contentView.scanTapPublisher
      .map { [unowned self] _ -> AnyPublisher<Void, Never> in
        self.controller.authorizeUsingOTP()
          .receive(on: RunLoop.main)
          .handleEvents(receiveCompletion: { [weak self] completion in
            guard case let .failure(error) = completion
            else { return }

            switch (error.identifier, error.underlyingError) {
            case (.yubikey, .some(NFCError.nfcDataParsingFailed)):
              self?.parent?.presentErrorSnackbar(
                .localized("mfa.yubikey.scan.failed")
              )
            case (.yubikey, .some(NFCError.nfcNotSupported)):
              self?.parent?.presentErrorSnackbar(
                .localized("mfa.yubikey.nfc.not.supported")
              )
            case _:
              self?.parent?.presentErrorSnackbar(
                .localized("mfa.yubikey.generic.error")
              )
            }
          })
          .replaceError(with: ())
          .eraseToAnyPublisher()
      }
      .switchToLatest()
      .receive(on: RunLoop.main)
      .sinkDrop()
      .store(in: cancellables)
  }
}
