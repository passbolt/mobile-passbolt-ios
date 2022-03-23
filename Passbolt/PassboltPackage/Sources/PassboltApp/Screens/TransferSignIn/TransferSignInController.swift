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

import AccountSetup
import Accounts
import CommonModels
import Crypto
import UIComponents

import struct Foundation.Data

internal struct TransferSignInController {

  internal var accountProfilePublisher: @MainActor () -> AnyPublisher<AccountTransfer.AccountDetails, Never>
  internal var accountAvatarPublisher: @MainActor () -> AnyPublisher<Data?, Never>
  internal var updatePassphrase: @MainActor (String) -> Void
  internal var validatedPassphrasePublisher: @MainActor () -> AnyPublisher<Validated<String>, Never>
  internal var completeTransfer: @MainActor () -> AnyPublisher<Never, Error>
  internal var presentForgotPassphraseAlert: @MainActor () -> Void
  internal var presentForgotPassphraseAlertPublisher: @MainActor () -> AnyPublisher<Bool, Never>
  internal var presentExitConfirmation: @MainActor () -> Void
  internal var exitConfirmationPresentationPublisher: @MainActor () -> AnyPublisher<Bool, Never>
  internal var presentationDestinationPublisher: @MainActor () -> AnyPublisher<Destination, Error>
}

extension TransferSignInController {

  internal enum Destination {

    case biometryInfo
    case biometrySetup
    case extensionSetup
    case finish
  }
}

extension TransferSignInController: UIController {

  internal typealias Context = Void

  internal static func instance(
    in context: Context,
    with features: FeatureFactory,
    cancellables: Cancellables
  ) async throws -> Self {
    let accountTransfer: AccountTransfer = try await features.instance()
    let autoFill: AutoFill = try await features.instance()
    let biometrics: Biometry = try await features.instance()
    let diagnostics: Diagnostics = try await features.instance()

    let passphraseSubject: CurrentValueSubject<String, Never> = .init("")
    let forgotAlertPresentationSubject: PassthroughSubject<Bool, Never> = .init()
    let exitConfirmationPresentationSubject: PassthroughSubject<Bool, Never> = .init()

    let presentationDestinationSubject: PassthroughSubject<Destination, Error> = .init()

    let validator: Validator<String> = .nonEmpty(
      displayable: .localized(
        key: "authorization.passphrase.error"
      )
    )

    accountTransfer
      .progressPublisher()
      .ignoreOutput()
      .sink(receiveCompletion: { completion in
        switch completion {
        case .finished:
          biometrics
            .biometricsStatePublisher()
            .first()
            .sink { biometricsState in
              switch biometricsState {
              case .unavailable:
                autoFill
                  .extensionEnabledStatePublisher()
                  .sink { enabled in
                    if enabled {
                      presentationDestinationSubject.send(.extensionSetup)
                    }
                    else {
                      presentationDestinationSubject.send(.finish)
                    }
                  }
                  .store(in: cancellables)

              case .unconfigured:
                presentationDestinationSubject.send(.biometryInfo)

              case .configuredTouchID, .configuredFaceID:
                presentationDestinationSubject.send(.biometrySetup)
              }
              presentationDestinationSubject.send(completion: .finished)
            }
            .store(in: cancellables)
        case let .failure(error):
          presentationDestinationSubject.send(completion: .failure(error))
        }
      })
      .store(in: cancellables)

    func accountProfilePublisher() -> AnyPublisher<AccountTransfer.AccountDetails, Never> {
      accountTransfer
        .accountDetailsPublisher()
        .map { details -> AccountTransfer.AccountDetails? in details }
        .collectErrorLog(using: diagnostics)
        .replaceError(with: nil)
        .filterMapOptional()
        .eraseToAnyPublisher()
    }

    func accountAvatarPublisher() -> AnyPublisher<Data?, Never> {
      accountTransfer
        .avatarPublisher()
        .map { data -> Data? in data }
        .collectErrorLog(using: diagnostics)
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

    func completeTransfer() -> AnyPublisher<Never, Error> {
      passphraseSubject
        .map(Passphrase.init(rawValue:))
        .eraseErrorType()
        .asyncMap {
          await accountTransfer.completeTransfer($0)
        }
        .switchToLatest()
        .ignoreOutput()
        .eraseToAnyPublisher()
    }

    func presentForgotPassphraseAlert() {
      forgotAlertPresentationSubject.send(true)
    }

    func presentForgotPassphraseAlertPublisher() -> AnyPublisher<Bool, Never> {
      forgotAlertPresentationSubject.eraseToAnyPublisher()
    }

    func presentExitConfirmation() {
      exitConfirmationPresentationSubject.send(true)
    }

    func exitConfirmationPresentationPublisher() -> AnyPublisher<Bool, Never> {
      exitConfirmationPresentationSubject.eraseToAnyPublisher()
    }

    func presentationDestinationPublisher() -> AnyPublisher<Destination, Error> {
      presentationDestinationSubject.eraseToAnyPublisher()
    }

    return Self(
      accountProfilePublisher: accountProfilePublisher,
      accountAvatarPublisher: accountAvatarPublisher,
      updatePassphrase: updatePassphrase,
      validatedPassphrasePublisher: validatedPassphrasePublisher,
      completeTransfer: completeTransfer,
      presentForgotPassphraseAlert: presentForgotPassphraseAlert,
      presentForgotPassphraseAlertPublisher: presentForgotPassphraseAlertPublisher,
      presentExitConfirmation: presentExitConfirmation,
      exitConfirmationPresentationPublisher: exitConfirmationPresentationPublisher,
      presentationDestinationPublisher: presentationDestinationPublisher
    )
  }
}
