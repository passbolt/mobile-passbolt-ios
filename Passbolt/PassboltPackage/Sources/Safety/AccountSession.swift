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
import Features

public struct AccountSession {
  
  public var currentAccountPublisher: () -> AnyPublisher<Account?, Never>
  public var completeAccountTransfer: (
    _ domain: String,
    _ userID: String,
    _ fingerprint: String,
    _ armoredKey: ArmoredPrivateKey,
    _ passphrase: Passphrase
  ) -> AnyPublisher<Void, TheError>
  public var signIn: (Account, Passphrase) -> AnyPublisher<Void, TheError>
  public var signOut: () -> AnyPublisher<Void, TheError>
}

extension AccountSession: Feature {
  
  public typealias Environment = Void
  
  public static func load(
    in environment: Environment,
    using features: FeatureFactory,
    cancellables: inout Array<AnyCancellable>
  ) -> AccountSession {
    let accounts: Accounts = features.instance()
    
    let currentAccountSubject: CurrentValueSubject<Account?, Never> = .init(nil)
    
    func signInPlaceholder(
      domain: String,
      armoredKey: ArmoredPrivateKey,
      passphrase: Passphrase
    ) -> AnyPublisher<Void, TheError> {
      #warning("TODO: [PAS-131] temporary placeholder for sign-in process")
      return Just(Void())
        .setFailureType(to: TheError.self)
        .eraseToAnyPublisher()
    }
    
    func completeAccountTransfer(
      domain: String,
      userID: String,
      fingerprint: String,
      armoredKey: ArmoredPrivateKey,
      passphrase: Passphrase
    ) -> AnyPublisher<Void, TheError> {
      signInPlaceholder(
        domain: domain,
        armoredKey: armoredKey,
        passphrase: passphrase
      )
      .flatMap { _ -> AnyPublisher<Void, TheError> in
        let accountSaveResult: Result<Account, TheError> = accounts
          .storeAccount(
            domain,
            userID,
            fingerprint,
            armoredKey
          )
        switch accountSaveResult {
        // swiftlint:disable:next explicit_type_interface
        case let .success(account):
          currentAccountSubject.send(account)
          return Just(Void()).setFailureType(to: TheError.self).eraseToAnyPublisher()
        // swiftlint:disable:next explicit_type_interface
        case let .failure(error):
          return Fail<Void, TheError>(error: error).eraseToAnyPublisher()
        }
      }
      .eraseToAnyPublisher()
    }
    
    func signIn(
      account: Account,
      passphrase: Passphrase
    ) -> AnyPublisher<Void, TheError> {
      #warning("TODO: [PAS-131]")
      Commons.placeholder("TODO: [PAS-131]")
    }
    
    func signOut() -> AnyPublisher<Void, TheError> {
      #warning("TODO: [PAS-131]")
      Commons.placeholder("TODO: [PAS-131]")
    }
    
    return Self(
      currentAccountPublisher: Commons.placeholder(),
      completeAccountTransfer: completeAccountTransfer(domain:userID:fingerprint:armoredKey:passphrase:),
      signIn: signIn(account:passphrase:),
      signOut: signOut
    )
  }
  
  #if DEBUG
  public static var placeholder: AccountSession {
    Self(
      currentAccountPublisher: Commons.placeholder("You have to provide mocks for used methods"),
      completeAccountTransfer: Commons.placeholder("You have to provide mocks for used methods"),
      signIn: Commons.placeholder("You have to provide mocks for used methods"),
      signOut: Commons.placeholder("You have to provide mocks for used methods")
    )
  }
  #endif
}
