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
import Crypto
import NetworkClient
import UIComponents

internal struct AuthorizationController {

  internal var accountWithProfilePublisher: () -> AnyPublisher<AccountWithProfile, Never>
  internal var accountAvatarPublisher: () -> AnyPublisher<Data?, Never>
  internal var updatePassphrase: (String) -> Void
  internal var validatedPassphrasePublisher: () -> AnyPublisher<Validated<String>, Never>
  internal var biometricStatePublisher: () -> AnyPublisher<BiometricsState, Never>
  internal var signIn: () -> AnyPublisher<Void, TheError>
  internal var biometricSignIn: () -> AnyPublisher<Void, TheError>
  internal var presentForgotPassphraseAlert: () -> Void
  internal var presentForgotPassphraseAlertPublisher: () -> AnyPublisher<Bool, Never>
}

extension AuthorizationController {

  internal enum BiometricsState {

    case unavailable
    case faceID
    case touchID
  }
}

extension AuthorizationController: UIController {

  internal typealias Context = Account

  internal static func instance(
    in context: Context,
    with features: FeatureFactory,
    cancellables: Cancellables
  ) -> Self {
    let accountSettings: AccountSettings = features.instance()
    let accountSession: AccountSession = features.instance()
    let biometry: Biometry = features.instance()
    let diagnostics: Diagnostics = features.instance()
    let networkClient: NetworkClient = features.instance()

    let passphraseSubject: CurrentValueSubject<String, Never> = .init("")
    let forgotAlertPresentationSubject: PassthroughSubject<Bool, Never> = .init()
    let validator: Validator<String> = .nonEmpty(errorLocalizationKey: "authorization.passphrase.error")

    let account: Account = context
    let accountWithProfileSubject: CurrentValueSubject<AccountWithProfile, Never>
      = .init(accountSettings.accountWithProfile(account))

    accountSettings
      .updatedAccountIDsPublisher()
      .filter { $0 == account.localID }
      .sink { _ in
        accountWithProfileSubject
          .send(
            accountSettings
              .accountWithProfile(account)
          )
      }
      .store(in: cancellables)

    func accountWithProfilePublisher() -> AnyPublisher<AccountWithProfile, Never> {
      accountWithProfileSubject.eraseToAnyPublisher()
    }

    func accountAvatarPublisher() -> AnyPublisher<Data?, Never> {
      accountWithProfileSubject
        .map { accountWithProfile in
          networkClient.mediaDownload.make(using: .init(urlString: accountWithProfile.avatarImageURL))
            .collectErrorLog(using: diagnostics)
            .map { data -> Data? in data }
            .replaceError(with: nil)
        }
        .switchToLatest()
        .eraseToAnyPublisher()
    }

    func updatePassphrase(_ passphrase: String) {
      passphraseSubject.send(passphrase)
    }

    func validatedPassphrasePublisher() -> AnyPublisher<Validated<String>, Never> {
      passphraseSubject
        .map(validator.validate)
        .eraseToAnyPublisher()
    }

    func biometricStatePublisher() -> AnyPublisher<BiometricsState, Never> {
      #warning("TODO: switch to account settings to provide data - remove context")
      return Publishers.CombineLatest(
        biometry
          .biometricsStatePublisher(),
        accountWithProfileSubject
      )
      .map { biometricsState, accountWithProfile in
        switch (biometricsState, accountWithProfile.biometricsEnabled) {
        case (.unavailable, _), (.unconfigured, _), (.configuredTouchID, false), (.configuredFaceID, false):
          return .unavailable

        case (.configuredTouchID, true):
          return .touchID

        case (.configuredFaceID, true):
          return .faceID
        }
      }
      .eraseToAnyPublisher()
    }

    func performSignIn() -> AnyPublisher<Void, TheError> {
      passphraseSubject
        .first()
        .map { passphrase in
          accountSession.authorize(
            account,
            .passphrase(.init(rawValue: passphrase))
          )
        }
        .switchToLatest()
        .eraseToAnyPublisher()
    }

    func performBiometricSignIn() -> AnyPublisher<Void, TheError> {
      accountSession
        .authorize(
          account,
          .biometrics
        )
    }

    func presentForgotPassphraseAlert() {
      forgotAlertPresentationSubject.send(true)
    }

    func presentForgotPassphraseAlertPublisher() -> AnyPublisher<Bool, Never> {
      forgotAlertPresentationSubject.eraseToAnyPublisher()
    }

    return Self(
      accountWithProfilePublisher: accountWithProfilePublisher,
      accountAvatarPublisher: accountAvatarPublisher,
      updatePassphrase: updatePassphrase,
      validatedPassphrasePublisher: validatedPassphrasePublisher,
      biometricStatePublisher: biometricStatePublisher,
      signIn: performSignIn,
      biometricSignIn: performBiometricSignIn,
      presentForgotPassphraseAlert: presentForgotPassphraseAlert,
      presentForgotPassphraseAlertPublisher: presentForgotPassphraseAlertPublisher
    )
  }
}
