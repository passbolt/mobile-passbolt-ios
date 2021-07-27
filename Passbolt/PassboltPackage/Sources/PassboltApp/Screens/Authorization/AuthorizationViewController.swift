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
  // sign in can be made only if it is nil
  private var signInCancellable: AnyCancellable?
    // initial value prevents sign in until setup completes
    = .init { /* NOP */ }
  private let autoLoginPromptSubject: PassthroughSubject<Never, Never> = .init()

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

    setupSubscriptions()
  }

  func activate() {
    autoLoginPromptSubject
      .delay(for: 0.05, scheduler: RunLoop.main)
      .sink(receiveCompletion: { [unowned self]  _ in
        guard signInCancellable == nil
        else { return }
        self.signInCancellable
          = self.controller
          .biometricSignIn()
          .receive(on: RunLoop.main)
          .handleEvents(
            receiveSubscription: { [weak self] _ in
              self?.present(overlay: LoaderOverlayView())
            },
            receiveCompletion: { [weak self] completion in
              defer { self?.signInCancellable = nil }
              self?.dismissOverlay()
              guard case let .failure(error) = completion, error.identifier != .canceled
              else { return }
              self?.present(
                snackbar: Mutation<UICommons.View>
                  .snackBarErrorMessage(localized: "sign.in.error.message")
                  .instantiate(),
                hideAfter: 2
              )
            }
          )
          .sinkDrop()
      })
      .store(in: cancellables)
  }

  func deactivate() {
    signInCancellable = nil
  }

  private func setupSubscriptions() {
    Publishers.CombineLatest(
      controller
        .accountProfilePublisher(),
      controller
        .biometricStatePublisher()
    )
    .first()
    .receive(on: RunLoop.main)
    .sink { [weak self] accountProfile, biometricsState in
      self?.contentView.applyOn(name: .text("\(accountProfile.label)"))
      self?.contentView.applyOn(email: .text(accountProfile.username))
      self?.contentView.applyOn(url: .text(accountProfile.domain))
      switch biometricsState {
      case .unavailable:
        self?.contentView.applyOn(
          biometricButtonContainer: .hidden(true)
        )
      case .faceID:
        self?.contentView.applyOn(
          biometricButton: .image(symbol: .faceID)
        )
        self?.contentView.applyOn(
          biometricButtonContainer: .hidden(false)
        )
        self?.autoLoginPromptSubject.send(completion: .finished)
      case .touchID:
        self?.contentView.applyOn(
          biometricButton: .image(symbol: .touchID)
        )
        self?.contentView.applyOn(
          biometricButtonContainer: .hidden(false)
        )
        self?.autoLoginPromptSubject.send(completion: .finished)
      }
      self?.signInCancellable = nil // unlock sign in
    }
    .store(in: cancellables)

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
      .sink { [unowned self] in
        guard signInCancellable == nil
        else { return }
        self.signInCancellable
          = self.controller
          .signIn()
          .receive(on: RunLoop.main)
          .handleEvents(
            receiveSubscription: { [weak self] _ in
              self?.present(overlay: LoaderOverlayView())
            },
            receiveCompletion: { [weak self] completion in
              defer { self?.signInCancellable = nil }
              self?.dismissOverlay()
              guard case let .failure(error) = completion, error.identifier != .canceled
              else { return }
              self?.present(
                snackbar: Mutation<UICommons.View>
                  .snackBarErrorMessage(localized: "sign.in.error.message")
                  .instantiate(),
                hideAfter: 2
              )
            }
          )
          .sinkDrop()
      }
      .store(in: cancellables)

    contentView
      .biometricTapPublisher
      .sink { [unowned self] in
        guard signInCancellable == nil
        else { return }
        self.signInCancellable
          = self.controller
          .biometricSignIn()
          .receive(on: RunLoop.main)
          .handleEvents(
            receiveSubscription: { [weak self] _ in
              self?.present(overlay: LoaderOverlayView())
            },
            receiveCompletion: { [weak self] completion in
              defer { self?.signInCancellable = nil }
              self?.dismissOverlay()
              guard case let .failure(error) = completion, error.identifier != .canceled
              else { return }
              self?.present(
                snackbar: Mutation<UICommons.View>
                  .snackBarErrorMessage(localized: "sign.in.error.message")
                  .instantiate(),
                hideAfter: 2
              )
            }
          )
          .sinkDrop()
      }
      .store(in: cancellables)

    contentView
      .forgotTapPublisher
      .receive(on: RunLoop.main)
      .sink { [weak self] in
        self?.controller
          .presentForgotPassphraseAlert()
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
