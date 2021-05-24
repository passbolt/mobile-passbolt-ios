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

internal final class SignInViewController: PlainViewController, UIComponent {

  internal typealias View = AuthorizationView
  internal typealias Controller = SignInController
  
  internal static func instance(
    using controller: SignInController,
    with components: UIComponentFactory
  ) -> Self {
    Self(
      using: controller,
      with: components
    )
  }
  
  internal private(set) lazy var contentView: View = .init()
  internal var components: UIComponentFactory
  
  private let controller: Controller
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
      .title(localized: "sign.in.title")
    }
    
    mut(contentView) {
      .backgroundColor(dynamic: .background)
    }
    
    #warning("TODO: Fill with proper values when available")
    contentView.applyOn(name: .text("TODO: Provide user name"))
    contentView.applyOn(email: .text("TODO: Provide email"))
    contentView.applyOn(url: .text("TODO: Provide url"))
    contentView.applyOn(passwordDescription: .text(localized: "autorization.passphrase.description.text"))
    
    setupSubscriptions()
  }
  
  private func setupSubscriptions() {
    contentView.secureTextPublisher
      .receive(on: RunLoop.main)
      .sink { [weak self] passphrase in
        self?.controller.updatePassphrase(passphrase)
      }
      .store(in: &cancellables)
    
    controller.validatedPassphrasePublisher()
      .first() // skipping error just to update intial value
      .map { Validated.valid($0.value) }
      .merge(
        with: controller
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
      .store(in: &cancellables)
    
    controller.validatedPassphrasePublisher()
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
      .store(in: &cancellables)
    
    controller.presentForgotPassphraseAlertPublisher()
      .receive(on: RunLoop.main)
      .sink { [weak self] presented in
        guard let self = self else { return }
        
        if presented {
          self.present(ForgotPassphraseAlertViewController.self)
        } else {
          self.dismiss(ForgotPassphraseAlertViewController.self)
        }
      }
      .store(in: &cancellables)
      
    contentView.forgotTapPublisher
      .receive(on: RunLoop.main)
      .sink { [weak self] in
        self?.controller.presentForgotPassphraseAlert()
      }
      .store(in: &cancellables)
  }
}
