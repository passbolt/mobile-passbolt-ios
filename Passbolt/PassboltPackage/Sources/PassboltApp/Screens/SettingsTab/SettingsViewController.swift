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

internal final class SettingsViewController: PlainViewController, UIComponent {

  internal typealias View = SettingsView
  internal typealias Controller = SettingsController

  internal static func instance(
    using controller: SettingsController,
    with components: UIComponentFactory
  ) -> Self {
    Self(
      using: controller,
      with: components
    )
  }

  internal private(set) lazy var contentView: SettingsView = .init(
    termsHidden: !controller.termsEnabled(),
    privacyPolicyHidden: !controller.privacyPolicyEnabled()
  )

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
      .title(localized: "account.settings.title")
    }

    setupSubscriptions()
  }

  private func setupSubscriptions() {
    controller
      .biometricsPublisher()
      .receive(on: RunLoop.main)
      .sink { [weak self] biometricState in
        switch biometricState {
        case .none:
          #warning("TODO - change symbol to image when available")
          self?.contentView.applyOn(biometricsImage: .image(symbol: .noSign))
          self?.contentView.applyOn(biometricsLabel: .text(localized: "account.settings.biometrics.unavailable"))

        case let .faceID(enabled):
          self?.contentView.applyOn(biometricsImage: .image(named: .faceID, from: .uiCommons))
          self?.contentView.applyOn(biometricsLabel: .text(localized: "account.settings.biometrics.face.id"))
          self?.contentView.applyOn(
            biometricsSwitch: .custom { (subject: UISwitch) in
              subject.setOn(enabled, animated: true)
            }
          )

        case let .touchID(enabled):
          #warning("TODO - change symbol to image when available")
          self?.contentView.applyOn(biometricsImage: .image(symbol: .touchID))
          self?.contentView.applyOn(biometricsLabel: .text(localized: "account.settings.biometrics.touch.id"))
          self?.contentView.applyOn(
            biometricsSwitch: .custom { (subject: UISwitch) in
              subject.setOn(enabled, animated: true)
            }
          )
        }
      }
      .store(in: cancellables)

    contentView
      .autofillTapPublisher
      .sink { [weak self] in
        self?.push(SettingsAutoFillViewController.self)
      }
      .store(in: cancellables)

    controller
      .autoFillEnabledPublisher()
      .receive(on: RunLoop.main)
      .sink { [weak self] enabled in
        self?.contentView.setAutoFill(hidden: enabled)
      }
      .store(in: cancellables)

    contentView
      .manageAccountsTapPublisher
      .sink { [weak self] in
        self?.push(AccountSelectionViewController.self, in: .init(value: true))
      }
      .store(in: cancellables)

    contentView
      .termsTapPublisher
      .map {
        self.controller.openTerms()
          .receive(on: RunLoop.main)
          .handleEvents(receiveOutput: { [weak self] value in
            guard !value else { return }
            self?.present(
              snackbar: Mutation<UICommons.View>
                .snackBarErrorMessage(localized: .genericError)
                .instantiate(),
              hideAfter: 2
            )
          })
          .mapToVoid()
      }
      .switchToLatest()
      .sink { /* */  }
      .store(in: cancellables)

    contentView
      .privacyPolicyTapPublisher
      .map {
        self.controller.openPrivacyPolicy()
          .receive(on: RunLoop.main)
          .handleEvents(receiveOutput: { [weak self] value in
            guard !value else { return }
            self?.present(
              snackbar: Mutation<UICommons.View>
                .snackBarErrorMessage(localized: .genericError)
                .instantiate(),
              hideAfter: 2
            )
          })
          .mapToVoid()
      }
      .switchToLatest()
      .sink { /* */  }
      .store(in: cancellables)

    contentView
      .signOutTapPublisher
      .sink { [weak self] in
        self?.controller.presentSignOutAlert()
      }
      .store(in: cancellables)

    controller
      .signOutAlertPresentationPublisher()
      .receive(on: RunLoop.main)
      .sink { [weak self] in
        guard let self = self else { return }
        self.present(
          SignOutAlertViewController.self
        )
      }
      .store(in: cancellables)

    controller
      .biometricsDisableAlertPresentationPublisher()
      .receive(on: RunLoop.main)
      .sink { [weak self] in
        self?.present(
          DisableBiometricsAlertViewController.self,
          in: { [weak self] in
            guard let self = self else { return }
            self.controller
              .disableBiometrics()
              .receive(on: RunLoop.main)
              .sink { [weak self] completion in
                guard
                  case let .failure(error) = completion,
                  error.identifier != .authorizationRequired
                else { return }
                guard let self = self else { return }

                self.present(
                  snackbar: Mutation<UICommons.View>
                    .snackBarErrorMessage(localized: "account.settings.biometrics.error")
                    .instantiate(),
                  hideAfter: 2
                )
              }
              .store(in: self.cancellables)
          }
        )
      }
      .store(in: cancellables)

    contentView
      .biometricsTapPublisher
      .sink { [weak self] in
        guard let self = self else { return }

        self.controller.toggleBiometrics()
          .receive(on: RunLoop.main)
          .sink { [weak self] completion in
            guard
              case let .failure(error) = completion,
              error.identifier != .authorizationRequired
            else { return }
            guard let self = self else { return }

            self.present(
              snackbar: Mutation<UICommons.View>
                .snackBarErrorMessage(localized: "account.settings.biometrics.error")
                .instantiate(),
              hideAfter: 2
            )
          }
          .store(in: self.cancellables)
      }
      .store(in: cancellables)
  }
}
