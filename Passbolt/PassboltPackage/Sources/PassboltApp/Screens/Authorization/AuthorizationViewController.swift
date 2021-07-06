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

import Accounts
import Foundation
import UIComponents

internal final class AuthorizationViewController: PlainViewController, UIComponent {

  internal typealias View = AuthorizationView
  internal typealias Controller = AuthorizationController

  internal static func instance(
    using controller: Controller,
    with components: UIComponentFactory
  ) -> Self {
    Self(
      using: controller,
      with: components
    )
  }

  internal private(set) lazy var contentView: AuthorizationView = .init()
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
    mut(self) {
      .title(localized: "authorization.title")
    }

    mut(contentView) {
      .backgroundColor(dynamic: .background)
    }

    let accountProfile: AccountWithProfile = controller.accountProfile()

    contentView.applyOn(name: .text("\(accountProfile.label)"))
    contentView.applyOn(email: .text(accountProfile.username))
    contentView.applyOn(url: .text(accountProfile.domain))
    contentView.applyOn(biometricButtonContainer: .hidden(!accountProfile.biometricsEnabled))

    setupSubscriptions()
  }

  // swiftlint:disable:next function_body_length
  private func setupSubscriptions() {
    controller
      .accountAvatarPublisher()
      .receive(on: RunLoop.main)
      .sink { [weak self] data in
        guard
          let imageData = data,
          let image: UIImage = .init(data: imageData)
        else { return }

        self?.contentView.applyOn(image: .image(image))
      }
      .store(in: cancellables)

    contentView
      .secureTextPublisher
      .receive(on: RunLoop.main)
      .sink { [weak self] passphrase in
        self?.controller.updatePassphrase(passphrase)
      }
      .store(in: cancellables)

    controller
      .validatedPassphrasePublisher()
      .first()  // skipping error just to update intial value
      .map { Validated.valid($0.value) }
      .merge(
        with:
          controller
          .validatedPassphrasePublisher()
          .dropFirst()
      )
      .receive(on: RunLoop.main)
      .sink { [weak self] validatedPassphrase in
        self?.contentView.update(from: validatedPassphrase)
        self?.contentView.applyOn(
          signInButton: .when(
            validatedPassphrase.isValid,
            then: .enabled(),
            else: .disabled()
          )
        )
      }
      .store(in: cancellables)

    controller
      .validatedPassphrasePublisher()
      .map(\.isValid)
      .receive(on: RunLoop.main)
      .sink { [weak self] isValid in
        self?.contentView.applyOn(
          signInButton: .when(
            isValid,
            then: .enabled(),
            else: .disabled()
          )
        )
      }
      .store(in: cancellables)

    contentView
      .signInTapPublisher
      // swiftlint:disable:next unowned_variable_capture
      .map { [unowned self] () -> AnyPublisher<Void, Never> in
        self.controller.signIn()
          .receive(on: RunLoop.main)
          .handleEvents(
            receiveSubscription: { [weak self] _ in
              self?.present(overlay: LoaderOverlayView())
            },
            receiveCompletion: { [weak self] completion in
              self?.dismissOverlay()
              guard case .failure = completion else { return }
              self?.present(
                snackbar: Mutation<UICommons.View>
                  .snackBarErrorMessage(localized: "sign.in.error.message")
                  .instantiate(),
                hideAfter: 2
              )
            }
          )
          .replaceError(with: Void())
          .eraseToAnyPublisher()
      }
      .switchToLatest()
      .sink { /* */  }
      .store(in: cancellables)

    contentView
      .biometricTapPublisher
      // swiftlint:disable:next unowned_variable_capture
      .map { [unowned self] () -> AnyPublisher<Void, Never> in
        self.controller.biometricSignIn()
          .receive(on: RunLoop.main)
          .handleEvents(
            receiveSubscription: { [weak self] _ in
              self?.present(overlay: LoaderOverlayView())
            },
            receiveCompletion: { [weak self] completion in
              self?.dismissOverlay()
              guard case .failure = completion else { return }
              self?.present(
                snackbar: Mutation<UICommons.View>
                  .snackBarErrorMessage(localized: "sign.in.error.message")
                  .instantiate(),
                hideAfter: 2
              )
            }
          )
          .replaceError(with: Void())
          .eraseToAnyPublisher()
      }
      .switchToLatest()
      .sink { /* */  }
      .store(in: cancellables)

    contentView
      .forgotTapPublisher
      .receive(on: RunLoop.main)
      .sink { [weak self] in
        self?.controller.presentForgotPassphraseAlert()
      }
      .store(in: cancellables)

    controller
      .presentForgotPassphraseAlertPublisher()
      .receive(on: RunLoop.main)
      .sink { [weak self] presented in
        guard let self = self else { return }

        if presented {
          self.present(ForgotPassphraseAlertViewController.self)
        }
        else {
          self.dismiss(ForgotPassphraseAlertViewController.self)
        }
      }
      .store(in: cancellables)
  }
}
