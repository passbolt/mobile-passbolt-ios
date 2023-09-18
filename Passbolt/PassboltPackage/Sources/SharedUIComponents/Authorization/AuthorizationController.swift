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
import CommonModels
import Crypto
import OSFeatures
import Session
import UIComponents

public struct AuthorizationController {

  public var accountWithProfilePublisher: @MainActor () -> AnyPublisher<AccountWithProfile, Never>
  public var accountAvatarPublisher: @MainActor () -> AnyPublisher<Data?, Never>
  public var updatePassphrase: @MainActor (String) -> Void
  public var validatedPassphrasePublisher: @MainActor () -> AnyPublisher<Validated<String>, Never>
  public var biometricStatePublisher: @MainActor () -> AnyPublisher<BiometricsState, Never>
  // returns true if MFA authorization screen should be displayed
  public var signIn: @MainActor () -> AnyPublisher<Bool, Error>
  // returns true if MFA authorization screen should be displayed
  public var biometricSignIn: @MainActor () -> AnyPublisher<Bool, Error>
  public var presentForgotPassphraseAlert: @MainActor () -> Void
  public var presentForgotPassphraseAlertPublisher: @MainActor () -> AnyPublisher<Bool, Never>
  public var accountNotFoundScreenPresentationPublisher: @MainActor () -> AnyPublisher<Account, Never>
}

extension AuthorizationController {

  public enum BiometricsState {

    case unavailable
    case faceID
    case touchID
  }
}

extension AuthorizationController: UIController {

  public typealias Context = Account

  public static func instance(
    in context: Context,
    with features: inout Features,
    cancellables: Cancellables
  ) throws -> Self {
    let accountDetails: AccountDetails = try features.instance(context: context)
    let accountPreferences: AccountPreferences = try features.instance(context: context)
    let session: Session = try features.instance()
    let biometry: OSBiometry = features.instance()

    let passphraseSubject: CurrentValueSubject<String, Never> = .init("")
    let forgotAlertPresentationSubject: PassthroughSubject<Bool, Never> = .init()
    let accountNotFoundScreenPresentationSubject: PassthroughSubject<Account, Never> = .init()
    let validator: Validator<String> = .nonEmpty(
      displayable: .localized(
        key: "authorization.passphrase.error"
      )
    )

    let account: Account = context
    let accountWithProfileSubject: CurrentValueSubject<AccountWithProfile, Never> = try .init(
      accountDetails.profile()
    )

    cancellables.executeAsync {
      for try await _ in accountDetails.updates {
        try accountWithProfileSubject
          .send(
            accountDetails.profile()
          )
      }
    }

    func accountWithProfilePublisher() -> AnyPublisher<AccountWithProfile, Never> {
      accountWithProfileSubject.eraseToAnyPublisher()
    }

    func accountAvatarPublisher() -> AnyPublisher<Data?, Never> {
      accountDetails
        .updates
        .asAnyAsyncSequence()
        .map { _ in
          try? await accountDetails.avatarImage()
        }
        .asThrowingPublisher()
        .replaceError(with: .none)
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
      accountPreferences
        .updates
        .asAnyAsyncSequence()
        .map { _ -> BiometricsState in
          switch (biometry.availability(), accountPreferences.isPassphraseStored()) {
          case (.unavailable, _), (.unconfigured, _), (.touchID, false), (.faceID, false):
            return .unavailable

          case (.touchID, true):
            return .touchID

          case (.faceID, true):
            return .faceID
          }
        }
        .asThrowingPublisher()
        .replaceError(with: .unavailable)
        .eraseToAnyPublisher()
    }

    func performSignIn() -> AnyPublisher<Bool, Error> {
      passphraseSubject
        .first()
        .eraseErrorType()
        .asyncMap { passphrase in
          do {
            try await session.authorize(
              .passphrase(
                account,
                .init(rawValue: passphrase)
              )
            )
            return false
          }
          catch is SessionMFAAuthorizationRequired {
            return true
          }
          catch {
            throw error
          }
        }
        .collectErrorLog(using: Diagnostics.shared)
        .handleErrors { error in
          switch error {
          case is HTTPNotFound:
            accountNotFoundScreenPresentationSubject.send(context)
          case _:
            return /* NOP */
          }
        }
        .eraseToAnyPublisher()
    }

    func performBiometricSignIn() -> AnyPublisher<Bool, Error> {
      cancellables.executeAsyncWithPublisher { () async throws -> Bool in
        do {
          try await session
            .authorize(
              .biometrics(account)
            )
          return false
        }
        catch is SessionMFAAuthorizationRequired {
          return true
        }
        catch {
          throw error
        }
      }
      .collectErrorLog(using: Diagnostics.shared)
      .handleErrors { error in
        switch error {
        case is HTTPNotFound:
          accountNotFoundScreenPresentationSubject.send(context)
        case _:
          return /* NOP */
        }
      }
      .eraseToAnyPublisher()
    }

    func presentForgotPassphraseAlert() {
      forgotAlertPresentationSubject.send(true)
    }

    func presentForgotPassphraseAlertPublisher() -> AnyPublisher<Bool, Never> {
      forgotAlertPresentationSubject.eraseToAnyPublisher()
    }

    func accountNotFoundScreenPresentationPublisher() -> AnyPublisher<Account, Never> {
      accountNotFoundScreenPresentationSubject.eraseToAnyPublisher()
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
      presentForgotPassphraseAlertPublisher: presentForgotPassphraseAlertPublisher,
      accountNotFoundScreenPresentationPublisher: accountNotFoundScreenPresentationPublisher
    )
  }
}
