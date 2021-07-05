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

  internal var accountProfilePublisher: () -> AnyPublisher<AccountWithProfile, Never>
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

  internal typealias Context = Account.LocalID

  internal static func instance(
    in context: Context,
    with features: FeatureFactory,
    cancellables: Cancellables
  ) -> Self {
    let accounts: Accounts = features.instance()
    let accountSession: AccountSession = features.instance()
    let biometry: Biometry = features.instance()
    let diagnostics: Diagnostics = features.instance()
    let networkClient: NetworkClient = features.instance()

    guard let accountWithProfile: AccountWithProfile = accounts.storedAccounts().first(where: { $0.localID == context })
    else { unreachable("Cannot select an account that is not stored locally.") }

    let passphraseSubject: CurrentValueSubject<String, Never> = .init("")
    let forgotAlertPresentationSubject: PassthroughSubject<Bool, Never> = .init()
    let validator: Validator<String> = .nonEmpty(errorLocalizationKey: "authorization.passphrase.error")

    func accountProfilePublisher() -> AnyPublisher<AccountWithProfile, Never> {
      #warning("TODO: [PAS-180] switch to account settings to provide data - remove context")
      return Just(accountWithProfile).eraseToAnyPublisher()
    }

    func accountAvatarPublisher() -> AnyPublisher<Data?, Never> {
      networkClient.mediaDownload.make(using: .init(urlString: accountWithProfile.avatarImageURL))
        .collectErrorLog(using: diagnostics)
        .map { data -> Data? in data }
        .replaceError(with: nil)
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
      #warning("TODO: [PAS-180] switch to account settings to provide data - remove context")
      return Publishers.CombineLatest(
        biometry
          .biometricsStateChangesPublisher(),
        Just(accountWithProfile)
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
            accountWithProfile.account,
            .passphrase(.init(rawValue: passphrase))
          )
        }
        .switchToLatest()
        .eraseToAnyPublisher()
    }

    func performBiometricSignIn() -> AnyPublisher<Void, TheError> {
      accountSession
        .authorize(
          accountWithProfile.account,
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
      accountProfilePublisher: accountProfilePublisher,
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
