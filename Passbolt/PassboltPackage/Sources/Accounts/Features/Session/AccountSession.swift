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
  // Publishes current account ID each time access to its private key
  // is required and cannot be handled automatically (passphrase cache is expired)
  public var authorizationPromptPresentationPublisher: () -> AnyPublisher<Account.LocalID, Never>
  // Select account for network requests without authorization (each account can have a unique domain etc)
  #warning("Determine if 'select' can be removed")
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

  public static func load(
    in environment: Environment,
    using features: FeatureFactory,
    cancellables: Cancellables
  ) -> AccountSession {
    let time: Time = environment.time
    let appLifeCycle: AppLifeCycle = environment.appLifeCycle

    let diagnostics: Diagnostics = features.instance()
    let passphraseCache: PassphraseCache = features.instance()
    let accountsDataStore: AccountsDataStore = features.instance()
    let networkClient: NetworkClient = features.instance()
    let signIn: SignIn = features.instance()
    var signOutCancellable: AnyCancellable?

    _ = signOutCancellable  // Silence warning

    let stateSubject: CurrentValueSubject<State, Never> = .init(
      .none(lastUsed: accountsDataStore.loadLastUsedAccount())
    )

    let authorizationPromptPresentationSubject: PassthroughSubject<Account.LocalID, Never> = .init()

    let sessionSubject: CurrentValueSubject<SessionTokens?, Never> = .init(nil)

    stateSubject
      .removeDuplicates()
      .map { state -> NetworkSessionVariable? in
        switch state {
        case let .authorized(account), let .authorizationRequired(account):
          return NetworkSessionVariable(domain: account.domain)

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
        case let .authorized(account):
          return
            passphraseCache
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

    appLifeCycle
      .lifeCyclePublisher()
      .compactMap { transition -> Account.LocalID? in
        guard case .didEnterBackground = transition
        else { return nil }
        switch stateSubject.value {
        case let .authorizationRequired(account), let .authorized(account):
          return account.localID

        case .none:
          return nil
        }
      }
      .sink { accountID in
        authorizationPromptPresentationSubject.send(accountID)
      }
      .store(in: cancellables)

    // swift-format-ignore: NoLeadingUnderscores
    func _close(using features: FeatureFactory) {
      features.unload(AccountDatabase.self)

      switch stateSubject.value {
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
      case let .authorizationRequired(account):
        stateSubject.send(.none(lastUsed: account))
        sessionSubject.send(nil)

      case .none:
        break  // do nothing
      }
    }
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
      case let .adHoc(pass, privateKey):
        passphrase = pass
        armoredPrivateKey = privateKey
      case let .passphrase(value):
        passphrase = value
        switch accountsDataStore.loadAccountPrivateKey(account.localID) {
        case let .success(armoredKey):
          armoredPrivateKey = armoredKey
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
        case let .success(value):
          passphrase = value
        case let .failure(error):
          return Fail<Void, TheError>(error: error)
            .eraseToAnyPublisher()
        }
        switch accountsDataStore.loadAccountPrivateKey(account.localID) {
        case let .success(armoredKey):
          armoredPrivateKey = armoredKey
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

      #warning("TODO: [PAS-160] temporarily disable token refresh, always sign in")
      let method: SignIn.Method = .challenge
      //      let method: SignIn.Method
      //      if let token: String = sessionSubject.value?.refreshToken {
      //        method = .refreshToken(token)
      //      }
      //      else {
      //        method = .challenge
      //      }

      let tokensPublisher: AnyPublisher<NetworkClient.Tokens?, Never> =
        sessionSubject
        .eraseToAnyPublisher()
        .map { (sessionTokens: SessionTokens?) -> AnyPublisher<SessionTokens?, Never> in
          #warning("TODO: [PAS-160] temporarily disable token refresh, always sign in")
          let method: SignIn.Method = .challenge
          //          let method: SignIn.Method
          //
          //          switch sessionTokens {
          //          case let .some(tokens):
          //            method = .refreshToken(tokens.refreshToken)
          //
          //          case .none:
          //            method = .challenge
          //          }

          let signInPublisher: AnyPublisher<SessionTokens?, Never> =
            signIn.signIn(
              account.userID,
              account.domain,
              armoredPrivateKey,
              passphrase,
              method
            )
            .map { sessionTokens -> SessionTokens? in
              sessionTokens  // switching type to optional
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

    func authorizationPromptPresentationPublisher() -> AnyPublisher<Account.LocalID, Never> {
      authorizationPromptPresentationSubject.eraseToAnyPublisher()
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
      authorizationPromptPresentationPublisher: authorizationPromptPresentationPublisher,
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
      authorizationPromptPresentationPublisher: Commons.placeholder("You have to provide mocks for used methods"),
      select: Commons.placeholder("You have to provide mocks for used methods"),
      close: Commons.placeholder("You have to provide mocks for used methods")
    )
  }
}
#endif
