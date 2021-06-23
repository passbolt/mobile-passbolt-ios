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
import AccountSetup
import Commons
import Crypto
import struct Foundation.Data
import UIComponents

internal struct TransferSignInController {
  
  internal var accountProfilePublisher: () -> AnyPublisher<AccountTransfer.AccountDetails, Never>
  internal var accountAvatarPublisher: () -> AnyPublisher<Data?, Never>
  internal var updatePassphrase: (String) -> Void
  internal var validatedPassphrasePublisher: () -> AnyPublisher<Validated<String>, Never>
  internal var completeTransfer: () -> AnyPublisher<Never, TheError>
  internal var presentForgotPassphraseAlert: () -> Void
  internal var presentForgotPassphraseAlertPublisher: () -> AnyPublisher<Bool, Never>
  internal var presentExitConfirmation: () -> Void
  internal var exitConfirmationPresentationPublisher: () -> AnyPublisher<Bool, Never>
  internal var presentationDestinationPublisher: () -> AnyPublisher<Destination, TheError>
}

extension TransferSignInController {
  
  internal enum Destination {
    
    case biometryInfo
    case biometrySetup
    case extensionSetup
  }
}

extension TransferSignInController: UIController {
  
  internal typealias Context = Void
  
  internal static func instance(
    in context: Context,
    with features: FeatureFactory,
    cancellables: Cancellables
  ) -> Self {
    let accountTransfer: AccountTransfer = features.instance()
    let biometrics: Biometry = features.instance()
    let passphraseSubject: CurrentValueSubject<String, Never> = .init("")
    let forgotAlertPresentationSubject: PassthroughSubject<Bool, Never> = .init()
    let exitConfirmationPresentationSubject: PassthroughSubject<Bool, Never> = .init()
    
    let presentationDestinationSubject: PassthroughSubject<Destination, TheError> = .init()
    
    let validator: Validator<String> = .nonEmpty(errorLocalizationKey: "authorization.passphrase.error")
    
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
                presentationDestinationSubject.send(.extensionSetup)
                
              case .unconfigured:
                presentationDestinationSubject.send(.biometryInfo)
                
              case .configuredTouchID, .configuredFaceID:
                presentationDestinationSubject.send(.biometrySetup)
                
              }
              presentationDestinationSubject.send(completion: .finished)
            }
            .store(in: cancellables)
        // swiftlint:disable:next explicit_type_interface
        case let .failure(error):
          presentationDestinationSubject.send(completion: .failure(error))
        }
      })
      .store(in: cancellables)

    func accountProfilePublisher() -> AnyPublisher<AccountTransfer.AccountDetails, Never> {
      // swiftlint:disable:next array_init
      accountTransfer
        .accountDetailsPublisher()
        .map { details -> AccountTransfer.AccountDetails? in details }
        .replaceError(with: nil)
        .compactMap { $0 }
        .eraseToAnyPublisher()
    }
    
    func accountAvatarPublisher() -> AnyPublisher<Data?, Never> {
      // swiftlint:disable:next array_init
      accountTransfer
        .avatarPublisher()
        .map { data -> Data? in data }
        .replaceError(with: nil)
        .eraseToAnyPublisher()
    }
    
    func updatePassphrase(_ passphrase: String) -> Void {
      passphraseSubject.send(passphrase)
    }
    
    func validatedPassphrasePublisher() -> AnyPublisher<Validated<String>, Never> {
      passphraseSubject
        .map(validator.validate)
        .eraseToAnyPublisher()
    }
    
    func completeTransfer() -> AnyPublisher<Never, TheError> {
      passphraseSubject
        .map(Passphrase.init(rawValue:))
        .map(accountTransfer.completeTransfer)
        .switchToLatest()
        .ignoreOutput()
        .eraseToAnyPublisher()
    }
    
    func presentForgotPassphraseAlert() -> Void {
      forgotAlertPresentationSubject.send(true)
    }
    
    func presentForgotPassphraseAlertPublisher() -> AnyPublisher<Bool, Never> {
      forgotAlertPresentationSubject.eraseToAnyPublisher()
    }
    
    func presentExitConfirmation() -> Void {
      exitConfirmationPresentationSubject.send(true)
    }
    
    func exitConfirmationPresentationPublisher() -> AnyPublisher<Bool, Never> {
      exitConfirmationPresentationSubject.eraseToAnyPublisher()
    }
    
    func presentationDestinationPublisher() -> AnyPublisher<Destination, TheError> {
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
