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
import NetworkClient

public struct AccountSession {
  // Publishes current account and associated network session token.
  public var statePublisher: () -> AnyPublisher<State, Never>
  // Used for sign in (including switch to other account) and unlocking whichever is required.
  public var authorize: (Account, AuthorizationMethod) -> AnyPublisher<Void, TheError>
  // Select account for network requests without authorization (each account can have a unique domain etc)
  public var select: (Account) -> Void
  // Closes current session and removes associated temporary data.
  // Not required for account switch, in that case use `authorize` with different account.
  public var close: () -> Void
}

extension AccountSession {

  public enum State: Equatable {
    
    case authorized(Account)
    case authorizationRequired(Account)
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

  
  // swiftlint:disable:next function_body_length
  public static func load(
    in environment: Environment,
    using features: FeatureFactory,
    cancellables: Cancellables
  ) -> AccountSession {
    let time: Time = environment.time
    
    let diagnostics: Diagnostics = features.instance()
    let passphraseCache: PassphraseCache = features.instance()
    let accountsDataStore: AccountsDataStore = features.instance()
    let networkClient: NetworkClient = features.instance()
    let signIn: SignIn = features.instance()
    var signOutCancellable: AnyCancellable?
    
    _ = signOutCancellable // Silence warning
    
    let stateSubject: CurrentValueSubject<State, Never> = .init(
      .none(lastUsed: accountsDataStore.loadLastUsedAccount())
    )
    
    let sessionSubject: CurrentValueSubject<SessionTokens?, Never> = .init(nil)
    
    stateSubject
      .removeDuplicates()
      .map { state -> NetworkSessionVariable? in
        switch state {
        // swiftlint:disable:next explicit_type_interface
        case let .authorized(account), let .authorizationRequired(account):
          return NetworkSessionVariable(domain: account.domain)
        // swiftlint:disable:next explicit_type_interface
  
        case .none:
          return nil
        }
      }
      .sink { sessionVariable in
        networkClient.updateSession(sessionVariable)
      }
      .store(in: cancellables)
    
    // bind passphrase cache expiration with authorizationRequired state change
    stateSubject
      .removeDuplicates()
      .compactMap { state -> AnyPublisher<State, Never>? in
        switch state {
        // swiftlint:disable:next explicit_type_interface
        case let .authorized(account):
          return passphraseCache
            .passphrasePublisher(account.localID)
            .compactMap { passphrase -> State? in
              switch passphrase {
              case .some:
                return nil
                
              case .none:
                return .authorizationRequired(account)
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
      case let .authorized(account):
        
        if let refreshToken: String = sessionSubject.value?.refreshToken {
          signOutCancellable = networkClient.signOutRequest.make(
            using: .init(
              refreshToken: refreshToken
            )
          )
          .ignoreOutput()
          .sink { _ in }
        }
      
        stateSubject.send(.none(lastUsed: account))
        sessionSubject.send(nil)
        passphraseCache.clear()
      // swiftlint:disable:next explicit_type_interface
      case let .authorizationRequired(account):
        stateSubject.send(.none(lastUsed: account))
        sessionSubject.send(nil)
        
      case .none:
        break // do nothing
      }
      
      sessionSubject.send(nil)
    }
    // swiftlint:disable:next unowned_variable_capture
    let closeSession: () -> Void = { [unowned features] in
      _close(using: features)
    }
    
    func authorize(
      account: Account,
      authorizationMethod: AuthorizationMethod
    ) -> AnyPublisher<Void, TheError> {
      #warning("TODO: [PAS-154] verify if token is expired and reuse or use session refresh if needed")
      
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
      
      // Authorization required for a new / switched account
      stateSubject.send(.authorizationRequired(account))
      
      #warning("TODO: Determine if session should be deleted (sessionSubject.send(nil)")
      
      let method: SignIn.Method
      if let token: String = sessionSubject.value?.refreshToken {
        method = .refreshToken(token)
      } else {
        method = .challenge
      }

      let tokensPublisher: AnyPublisher<NetworkClient.Tokens?, Never> =
        sessionSubject
        .eraseToAnyPublisher()
        .map { (sessionTokens: SessionTokens?) -> AnyPublisher<SessionTokens?, Never> in
          let method: SignIn.Method
          
          switch sessionTokens {
          // swiftlint:disable:next explicit_type_interface
          case let .some(tokens):
            method = .refreshToken(tokens.refreshToken)
            
          case .none:
            method = .challenge
          }
          
          let signInPublisher: AnyPublisher<SessionTokens?, Never> =
            // swiftlint:disable:next array_init
            signIn.signIn(
              account.userID,
              account.domain,
              armoredPrivateKey,
              passphrase,
              method
            )
            .map { sessionTokens -> SessionTokens? in
              sessionTokens // switching type to optional
            }
            .collectErrorLog(using: diagnostics)
            .replaceError(with: nil)
            .eraseToAnyPublisher()
          
          return signInPublisher
        }
        .switchToLatest()
        .map { (sessionTokens: SessionTokens?) -> NetworkClient.Tokens? in
          guard let sessionTokens = sessionTokens else {
            return nil
          }
          
          return NetworkClient.Tokens(
            accessToken: sessionTokens.accessToken.rawValue,
            isExpired: { sessionTokens.accessToken.isExpired(timestamp: time.timestamp()) },
            refreshToken: sessionTokens.refreshToken
          )
        }
        .setFailureType(to: Never.self)
        .eraseToAnyPublisher()
      
      networkClient.setTokensPublisher(tokensPublisher)
  
      return signIn.signIn(
        account.userID,
        account.domain,
        armoredPrivateKey,
        passphrase,
        method
      )
      .handleEvents(receiveOutput: { sessionTokens in
        accountsDataStore.storeLastUsedAccount(account.localID)
        passphraseCache
          .store(
            passphrase,
            account.localID,
            .init(
              timeIntervalSince1970: .init(time.timestamp())
                + PassphraseCache.defaultExpirationTimeInterval
            )
          )

        sessionSubject.send(sessionTokens)
        
        stateSubject.send(
          .authorized(account)
        )
      })
      .map { _ in Void() }
      .eraseToAnyPublisher()
    }
    
    func select(account: Account) {
      switch stateSubject.value {
      case .authorizationRequired, .authorized:
        closeSession()
        
      case .none:
        break
      }
      
      stateSubject.send(.authorizationRequired(account))
    }
    
    return Self(
      statePublisher: stateSubject.removeDuplicates().eraseToAnyPublisher,
      authorize: authorize(account:authorizationMethod:),
      select: select(account:),
      close: closeSession
    )
  }
}

#if DEBUG
extension AccountSession {

  public static var placeholder: AccountSession {
    Self(
      statePublisher: Commons.placeholder("You have to provide mocks for used methods"),
      authorize: Commons.placeholder("You have to provide mocks for used methods"),
      select: Commons.placeholder("You have to provide mocks for used methods"),
      close: Commons.placeholder("You have to provide mocks for used methods")
    )
  }
}
#endif
