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
import OSFeatures
import UIComponents

import struct Foundation.Data

internal struct TransferSignInController {

  internal var accountProfilePublisher: @MainActor () -> AnyPublisher<AccountImport.AccountDetails, Never>
  internal var accountAvatarPublisher: @MainActor () -> AnyPublisher<Data?, Never>
  internal var updatePassphrase: @MainActor (String) -> Void
  internal var validatedPassphrasePublisher: @MainActor () -> AnyPublisher<Validated<String>, Never>
  internal var completeTransfer: @MainActor () -> AnyPublisher<Never, Error>
  internal var presentForgotPassphraseAlert: @MainActor () -> Void
  internal var presentForgotPassphraseAlertPublisher: @MainActor () -> AnyPublisher<Bool, Never>
  internal var presentExitConfirmation: @MainActor () -> Void
  internal var exitConfirmationPresentationPublisher: @MainActor () -> AnyPublisher<Bool, Never>
  internal var exitPublisher: @MainActor () -> AnyPublisher<Never, Error>
}

extension TransferSignInController: UIController {

  internal typealias Context = Void

  internal static func instance(
    in context: Context,
    with features: inout Features,
    cancellables: Cancellables
  ) throws -> Self {
    let accountTransfer: AccountImport = try features.instance()

    let passphraseSubject: CurrentValueSubject<String, Never> = .init("")
    let forgotAlertPresentationSubject: PassthroughSubject<Bool, Never> = .init()
    let exitConfirmationPresentationSubject: PassthroughSubject<Bool, Never> = .init()

    let validator: Validator<String> = .nonEmpty(
      displayable: .localized(
        key: "authorization.passphrase.error"
      )
    )

    func accountProfilePublisher() -> AnyPublisher<AccountImport.AccountDetails, Never> {
      accountTransfer
        .accountDetailsPublisher()
        .map { details -> AccountImport.AccountDetails? in details }
        .collectErrorLog(using: Diagnostics.shared)
        .replaceError(with: nil)
        .filterMapOptional()
        .eraseToAnyPublisher()
    }

    func accountAvatarPublisher() -> AnyPublisher<Data?, Never> {
      accountTransfer
        .avatarPublisher()
        .map { data -> Data? in data }
        .collectErrorLog(using: Diagnostics.shared)
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
        .map(accountTransfer.completeTransfer)
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

    func exitPublisher() -> AnyPublisher<Never, Error> {
      accountTransfer
        .progressPublisher()
        .ignoreOutput()
        .eraseToAnyPublisher()
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
      exitPublisher: exitPublisher
    )
  }
}
