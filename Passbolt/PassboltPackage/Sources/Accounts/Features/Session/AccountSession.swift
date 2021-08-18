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

import class Foundation.NSRecursiveLock

public struct AuthorizationPromptRequest {

  public var account: Account
  public var message: LocalizedMessage?
}

public struct AccountSession {
  // Publishes current account and associated network session token.
  public var statePublisher: () -> AnyPublisher<State, Never>
  // Used for sign in (including switch to other account) and unlocking whichever is required.
  public var authorize: (Account, AuthorizationMethod) -> AnyPublisher<Void, TheError>
  // Publishes current account ID each time access to its private key
  // is required and cannot be handled automatically (passphrase cache is expired)
  public var authorizationPromptPresentationPublisher: () -> AnyPublisher<AuthorizationPromptRequest, Never>
  // Manual trigger for authorization prompt
  public var requestAuthorizationPrompt: (LocalizedMessage?) -> Void
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
    case adHoc(Passphrase, ArmoredPGPPrivateKey)
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
    let networkSession: NetworkSession = features.instance()

    let authorizationCancellableLock: NSRecursiveLock = .init()
    // swift-format-ignore: NoLeadingUnderscores
    var _authorizationCancellable: AnyCancellable?
    var authorizationCancellable: AnyCancellable? {
      get {
        authorizationCancellableLock.lock()
        defer { authorizationCancellableLock.unlock() }
        return _authorizationCancellable
      }
      set {
        authorizationCancellableLock.lock()
        _authorizationCancellable = newValue
        authorizationCancellableLock.unlock()
      }
    }
    let signOutCancellableLock: NSRecursiveLock = .init()
    // swift-format-ignore: NoLeadingUnderscores
    var _signOutCancellable: AnyCancellable?
    var signOutCancellable: AnyCancellable? {
      get {
        signOutCancellableLock.lock()
        defer { signOutCancellableLock.unlock() }
        return _signOutCancellable
      }
      set {
        signOutCancellableLock.lock()
        _signOutCancellable = newValue
        signOutCancellableLock.unlock()
      }
    }

    let sessionStateSubject: CurrentValueSubject<State, Never> = .init(
      .none(lastUsed: accountsDataStore.loadLastUsedAccount())
    )
    let sessionStatePublisher: AnyPublisher<State, Never> =
      sessionStateSubject
      .removeDuplicates()
      .eraseToAnyPublisher()

    let authorizationPromptPresentationSubject: PassthroughSubject<AuthorizationPromptRequest, Never> = .init()

    networkClient.setAuthorizationRequest({
      requestAuthorization(
        message: .init(
          key: "authorization.prompt.refresh.session.reason",
          bundle: .main
        )
      )
    })

    // connect current account base url / domain with network client
    // to perform requests in correct contexts
    sessionStatePublisher
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
    sessionStatePublisher
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
      .sink { [weak sessionStateSubject] newState in
        // it will only publish authorizationRequired state
        sessionStateSubject?.send(newState)
      }
      .store(in: cancellables)

    // request authorization prompt when going back to the application
    // from the background with active session (includes authorizationRequired)
    // when going to background cancel ongoing authorization if any
    appLifeCycle
      .lifeCyclePublisher()
      .compactMap { transition -> AuthorizationPromptRequest? in
        switch transition {
        case .willEnterForeground:
          switch sessionStateSubject.value {
          case let .authorizationRequired(account), let .authorized(account):
            return .init(account: account, message: nil)  // request authorization prompt for that account

          case .none:
            return nil  // do nothing
          }

        case .didEnterBackground:
          // cancel previous authorization if any
          // we should not authorize in background
          authorizationCancellable = nil
          return nil  // do nothing

        case _:
          return nil  // do nothing
        }
      }
      .sink { accountID in
        authorizationPromptPresentationSubject.send(accountID)
      }
      .store(in: cancellables)

    // Clear current session data without changing session state
    // as preparation for other session relates event (sign out or account switch)
    // We are doing it separately from closeSession to avoid
    // session state change triggers.
    // swift-format-ignore: NoLeadingUnderscores
    let _clearCurrentSession: () -> Void = { [unowned features] in
      passphraseCache.clear()
      features.unload(AccountDatabase.self)

      switch sessionStateSubject.value {
      case .authorized, .authorizationRequired:
        signOutCancellable =
          networkSession
          .closeSession()
          .collectErrorLog(using: diagnostics)
          .ignoreOutput()
          .sinkDrop()

      case .none:
        break  // do nothing
      }
    }
    // Close current session and change session state (sign out)
    let closeSession: () -> Void = {
      _clearCurrentSession()

      // we provide none for last used to avoid skipping
      // account list for given account
      // when navigating to initial screen again
      // that account will be still used as last used
      // when launching application again anyway
      sessionStateSubject.send(.none(lastUsed: .none))
    }

    func authorize(
      account: Account,
      authorizationMethod: AuthorizationMethod
    ) -> AnyPublisher<Void, TheError> {
      // cancel previous authorization if any
      // there can't be more than a single ongoing authorization
      authorizationCancellable = nil

      switch sessionStateSubject.value {
      case let .authorized(currentAccount) where currentAccount.localID != account.localID,
        let .authorizationRequired(currentAccount) where currentAccount.localID != account.localID:
        diagnostics.debugLog("Signing out \(currentAccount.localID)")
        // signout from current account on switching accounts
        _clearCurrentSession()
      case _:
        break
      }

      diagnostics.debugLog("Signing in \(account.localID)")

      // since we are trying to sign in we change current session state
      // to a new one with authorizationRequired state to indicate
      // that we are signing in and to change network client base url / domain
      sessionStateSubject.send(.authorizationRequired(account))

      #warning("TODO: [PAS-154] verify if token is expired and reuse or use session refresh if needed")
      #warning("TODO: [PAS-160] temporarily disable token refresh, always sign in")

      // sign in process

      // prepare passphrase and armored private key
      let passphrase: Passphrase
      let armoredPrivateKey: ArmoredPGPPrivateKey
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

      // to ensure that only single authorization is in progress
      // we delegate result to the additional subject
      // and control cancellation internally
      let signInResultSubject: PassthroughSubject<Void, TheError> = .init()

      authorizationCancellable =
        networkSession
        .createSession(
          account.userID,
          account.domain,
          armoredPrivateKey,
          passphrase
        )
        .handleEvents(
          receiveOutput: { sessionTokens in
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

            sessionStateSubject
              .send(
                .authorized(account)
              )
          }
        )
        .mapToVoid()
        .subscribe(signInResultSubject)

      return
        signInResultSubject
        .handleEvents(receiveCancel: {
          // When we cancel authorization we have to
          // cancel internal authorization publisher as well
          authorizationCancellable = nil
        })
        .eraseToAnyPublisher()
    }

    func authorizationPromptPresentationPublisher() -> AnyPublisher<AuthorizationPromptRequest, Never> {
      authorizationPromptPresentationSubject
        .eraseToAnyPublisher()
    }

    func requestAuthorization(message: LocalizedMessage?) {
      switch sessionStateSubject.value {
      case let .authorized(account):
        passphraseCache.clear()
        authorizationPromptPresentationSubject.send(
          .init(account: account, message: message)
        )
      case let .authorizationRequired(account):
        authorizationPromptPresentationSubject.send(
          .init(account: account, message: message)
        )
      case .none:
        break
      }
    }

    return Self(
      statePublisher: { sessionStatePublisher },
      authorize: authorize(account:authorizationMethod:),
      authorizationPromptPresentationPublisher: authorizationPromptPresentationPublisher,
      requestAuthorizationPrompt: requestAuthorization,
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
      requestAuthorizationPrompt: Commons.placeholder("You have to provide mocks for used methods"),
      close: Commons.placeholder("You have to provide mocks for used methods")
    )
  }
}
#endif
