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

import Crypto
import Features

public struct AccountSession {
  // Publishes current account and associated network session token.
  public var statePublisher: () -> AnyPublisher<State, Never>
  // Used for sign in (including switch to other account) and unlocking whichever is required.
  public var authorize: (Account, AuthorizationMethod) -> AnyPublisher<Void, TheError>
  // Closes current session and removes associated temporary data.
  // Not required for account switch, in that case use `authorize` with different account.
  public var close: () -> Void
}

extension AccountSession {
  
  #warning("TODO: [PAS-131] It might be changed to struct which can be used to verify expiration time")
  public typealias Token = Tagged<String, Self>
  
  public enum State {
    
    case authorized(Account, token: Token)
    case authorizationRequired(Account, token: Token?)
    case none(lastUsed: Account?)
  }
  
  public enum AuthorizationMethod {
    // for unstored accounts
    case adHoc(Passphrase, ArmoredPrivateKey)
    // for stored account
    case passphrase(Passphrase)
    // for account stored with passphrase
    case biometrics
  }
}

extension AccountSession: Feature {
  
  public typealias Environment = Time
  
  public static func environmentScope(
    _ rootEnvironment: RootEnvironment
  ) -> Environment {
    rootEnvironment.time
  }
  
  // swiftlint:disable:next function_body_length
  public static func load(
    in environment: Environment,
    using features: FeatureFactory,
    cancellables: Cancellables
  ) -> AccountSession {
    let diagnostics: Diagnostics = features.instance()
    let passphraseCache: PassphraseCache = features.instance()
    let accountsDataStore: AccountsDataStore = features.instance()
    
    let stateSubject: CurrentValueSubject<State, Never> = .init(
      .none(lastUsed: accountsDataStore.loadLastUsedAccount())
    )
    
    #warning("TODO: [PAS-131] - add timer for token expire with auto refresh")
    
    // bind passphrase cache expiration with authorizationRequired state change
    stateSubject
      .compactMap { state -> AnyPublisher<State, Never>? in
        switch state {
        // swiftlint:disable:next explicit_type_interface
        case let .authorized(account, token):
          return passphraseCache
            .passphrasePublisher(account.localID)
            .compactMap { passphrase -> State? in
              switch passphrase {
              case .some:
                return nil
                
              case .none:
                return .authorizationRequired(account, token: token)
              }
            }
            .eraseToAnyPublisher()
          
        case .authorizationRequired, .none:
          return nil
        }
      }
      .switchToLatest()
      .sink { [weak stateSubject] newState in
        // it will only publish authorizationRequired state
        stateSubject?.send(newState)
      }
      .store(in: cancellables)
    
    func _close(using features: FeatureFactory) {
      features.unload(AccountDatabase.self)
      switch stateSubject.value {
      // swiftlint:disable:next explicit_type_interface
      case let .authorized(account, token: _), let .authorizationRequired(account, token: .some):
        #warning("TODO: [PAS-131] send request for sign out")
        stateSubject.send(.none(lastUsed: account))
        passphraseCache.clear()
      // swiftlint:disable:next explicit_type_interface
      case let .authorizationRequired(account, token: .none):
        stateSubject.send(.none(lastUsed: account))
        
      case .none:
        break // do nothing
      }
    }
    // swiftlint:disable:next unowned_variable_capture
    let closeSession: () -> Void = { [unowned features] in
      _close(using: features)
    }
    
    func signInPlaceholder(
      domain: String,
      armoredKey: ArmoredPrivateKey,
      passphrase: Passphrase
    ) -> AnyPublisher<Token, TheError> {
      #warning("TODO: [PAS-131] temporary placeholder for sign-in process")
      return Just("signInPlaceholderToken")
        .setFailureType(to: TheError.self)
        .eraseToAnyPublisher()
    }
    
    func authorize(
      account: Account,
      authorizationMethod: AuthorizationMethod
    ) -> AnyPublisher<Void, TheError> {
      #warning("TODO: [PAS-131] verify token and reuse or use session refresh if needed")
      
      // sign in process
      let passphrase: Passphrase
      let armoredPrivateKey: ArmoredPrivateKey
      switch authorizationMethod {
      // swiftlint:disable:next explicit_type_interface
      case let .adHoc(pass, privateKey):
        passphrase = pass
        armoredPrivateKey = privateKey
      // swiftlint:disable:next explicit_type_interface
      case let .passphrase(value):
        passphrase = value
        switch accountsDataStore.loadAccountPrivateKey(account.localID) {
        // swiftlint:disable:next explicit_type_interface
        case let .success(armoredKey):
          armoredPrivateKey = armoredKey
        // swiftlint:disable:next explicit_type_interface
        case let .failure(error):
          diagnostics.debugLog(
            "Failed to retrieve private key for account: \(account.localID)"
              + " - status: \(error.osStatus.map(String.init(describing:)) ?? "N/A")"
          )
          return Fail<Void, TheError>(error: error)
            .eraseToAnyPublisher()
        }
        
      case .biometrics:
        switch accountsDataStore.loadAccountPassphrase(account.localID) {
        // swiftlint:disable:next explicit_type_interface
        case let .success(value):
          passphrase = value
        // swiftlint:disable:next explicit_type_interface
        case let .failure(error):
          return Fail<Void, TheError>(error: error)
            .eraseToAnyPublisher()
        }
        switch accountsDataStore.loadAccountPrivateKey(account.localID) {
        // swiftlint:disable:next explicit_type_interface
        case let .success(armoredKey):
          armoredPrivateKey = armoredKey
        // swiftlint:disable:next explicit_type_interface
        case let .failure(error):
          diagnostics.debugLog(
            "Failed to retrieve private key for account: \(account.localID)"
              + " - status: \(error.osStatus.map(String.init(describing:)) ?? "N/A")"
          )
          return Fail<Void, TheError>(error: error)
            .eraseToAnyPublisher()
        }
      }
      
      return signInPlaceholder(
        domain: account.domain,
        armoredKey: armoredPrivateKey,
        passphrase: passphrase
      )
      .handleEvents(receiveOutput: { token in
        accountsDataStore.storeLastUsedAccount(account.localID)
        passphraseCache
          .store(
            passphrase,
            account.localID,
            .init(
              timeIntervalSince1970: .init(environment.timestamp())
                + PassphraseCache.defaultExpirationTimeInterval
            )
          )
        stateSubject.send(.authorized(account, token: token))
      })
      .map { _ in Void() }
      .eraseToAnyPublisher()
    }
    
    return Self(
      statePublisher: stateSubject.eraseToAnyPublisher,
      authorize: authorize(account:authorizationMethod:),
      close: closeSession
    )
  }
  
  #if DEBUG
  public static var placeholder: AccountSession {
    Self(
      statePublisher: Commons.placeholder("You have to provide mocks for used methods"),
      authorize: Commons.placeholder("You have to provide mocks for used methods"),
      close: Commons.placeholder("You have to provide mocks for used methods")
    )
  }
  #endif
}
