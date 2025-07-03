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

import CommonModels
import UIComponents

internal final class TOTPViewController: PlainViewController, UIComponent {

  internal typealias ContentView = TOTPView
  internal typealias Controller = TOTPController

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

  internal func setupView() {
    setupSubscriptions()
  }

  internal func setupSubscriptions() {
    controller
      .otpPublisher()
      .receive(on: RunLoop.main)
      .sink { [weak self] otp in
        self?.contentView.update(otp: otp)
      }
      .store(in: cancellables)

    contentView
      .otpPublisher
      .sink { [weak self] otp in
        self?.controller.setOTP(otp)
      }
      .store(in: cancellables)

    controller
      .rememberDevicePublisher()
      .receive(on: RunLoop.main)
      .sink { [weak self] remember in
        self?.contentView.update(rememberDevice: remember)
      }
      .store(in: cancellables)

    contentView
      .rememberDeviceToggleTapPublisher
      .sink { [weak self] in
        self?.controller.toggleRememberDevice()
      }
      .store(in: cancellables)

    contentView
      .pasteOTPTapPublisher
      .sink { [weak self] in
        self?.view.endEditing(true)
        self?.controller.pasteOTP()
      }
      .store(in: cancellables)

    controller
      .statusChangePublisher()
      .receive(on: RunLoop.main)
      .sink { [weak self] change in
        switch change {
        case .idle, .processing:
          self?.contentView
            .applyOn(
              labels:
                .textColor(dynamic: .primaryText)
            )

        case .error:
          self?.contentView
            .applyOn(
              labels:
                .textColor(dynamic: .secondaryRed)
            )
        }

        switch change {
        case .idle:
          self?.dismissOverlay()

        case .processing:
          self?.view.endEditing(true)
          self?
            .present(
              overlay: LoaderOverlayView(
                longLoadingMessage: (
                  message: .localized(
                    key: .loadingLong
                  ),
                  delay: 15
                )
              )
            )

        case .error(let error) where error is InvalidPasteValue:
          self?.dismissOverlay()
          SnackBarMessageEvent.send(.error(.localized(key: .invalidPasteValue)))

        case .error(let error) where !(error is Cancelled):
          self?.dismissOverlay()
          SnackBarMessageEvent.send(.error(error))

        case .error(let error as NetworkRequestValidationFailure):
          self?.dismissOverlay()
          SnackBarMessageEvent.send(.error("totp.wrong.code.error"))

        case _:
          self?.dismissOverlay()
        }
      }
      .store(in: cancellables)
  }
}
