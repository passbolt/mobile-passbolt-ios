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

public enum AuthorizationPromptRequest {

  case passphraseRequest(account: Account, message: LocalizedMessage?)
  case mfaRequest(account: Account, providers: Array<MFAProvider>)

  public var account: Account {
    switch self {
    case let .passphraseRequest(account, _):
      return account
    case let .mfaRequest(account, _):
      return account
    }
  }

  public var message: LocalizedMessage? {
    switch self {
    case let .passphraseRequest(_, message):
      return message
    case .mfaRequest:
      return .none
    }
  }

  public var mfaProviders: Array<MFAProvider> {
    switch self {
    case .passphraseRequest:
      return []
    case let .mfaRequest(_, providers):
      return providers
    }
  }
}

public struct AccountSession {
  // Publishes current account and associated network session token.
  public var statePublisher: () -> AnyPublisher<State, Never>
  // Used for sign in (including switch to other account) and unlocking whichever is required.
  // Returns true if MFA authorization is required, otherwise false.
  public var authorize: (Account, AuthorizationMethod) -> AnyPublisher<Bool, TheError>
  // Used for MFA authorization if required. Executed always in context of current account.
  public var mfaAuthorize: (MFAAuthorizationMethod, Bool) -> AnyPublisher<Void, TheError>
  // Decrypt message with current session context if any. Optionally verify signature if public key was provided.
  public var decryptMessage: (String, ArmoredPGPPublicKey?) -> AnyPublisher<String, TheError>
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
    case authorizedMFARequired(Account, providers: Array<MFAProvider>)
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

  public enum MFAAuthorizationMethod: Equatable {

    case totp(String)
    case yubikeyOTP(String)
  }
}

extension AccountSession: Feature {

  public static func load(
    in environment: Environment,
    using features: FeatureFactory,
    cancellables: Cancellables
  ) -> AccountSession {
    let pgp: PGP = environment.pgp
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
    let sessionStateLock: NSRecursiveLock = .init()
    // synchonizing access to session state due to race conditions
    // CurrentValueSubject is thread safe but in some cases
    // we have to ensure state changes happen in sync with previous value
    // while other threads might try to access it in the mean time
    var sessionState: State {
      get {
        sessionStateLock.lock()
        defer { sessionStateLock.unlock() }
        return sessionStateSubject.value
      }
      set {
        sessionStateLock.lock()
        sessionStateSubject.value = newValue
        sessionStateLock.unlock()
      }
    }
    func withSessionState<Returned>(_ access: (inout State) -> Returned) -> Returned {
      sessionStateLock.lock()
      defer { sessionStateLock.unlock() }
      return access(&sessionStateSubject.value)
    }

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

    networkClient.setMFARequest(requestMFA(with:))

    // connect current account base url / domain with network client
    // to perform requests in correct contexts
    sessionStatePublisher
      .map { state -> NetworkSessionVariable? in
        switch state {
        case let .authorized(account), let .authorizedMFARequired(account, _), let .authorizationRequired(account):
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
        case let .authorized(account), let .authorizedMFARequired(account, _):
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
      .sink { newState in
        // it will only publish authorizationRequired state
        sessionState = newState
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
          switch sessionState {
          case let .authorizationRequired(account), let .authorized(account), let .authorizedMFARequired(account, _):
            // request authorization prompt for that account
            return .passphraseRequest(account: account, message: nil)

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

      switch sessionState {
      case .authorized, .authorizationRequired, .authorizedMFARequired:
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
      sessionState = .none(lastUsed: .none)
    }

    func authorize(
      account: Account,
      authorizationMethod: AuthorizationMethod
    ) -> AnyPublisher<Bool, TheError> {
      // cancel previous authorization if any
      // there can't be more than a single ongoing authorization
      authorizationCancellable = nil

      switch sessionState {
      case let .authorized(currentAccount) where currentAccount.userID != account.userID || (currentAccount.localID != account.localID
        && !accountsDataStore.loadAccounts().contains(currentAccount)),
        let .authorizationRequired(currentAccount) where currentAccount.userID != account.userID || (currentAccount.localID != account.localID
        && !accountsDataStore.loadAccounts().contains(currentAccount)):
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
      sessionState = .authorizationRequired(account)

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
          return Fail<Bool, TheError>(error: error)
            .eraseToAnyPublisher()
        }

      case .biometrics:
        switch accountsDataStore.loadAccountPassphrase(account.localID) {
        case let .success(value):
          passphrase = value
        case let .failure(error):
          return Fail<Bool, TheError>(error: error)
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
          return Fail<Bool, TheError>(error: error)
            .eraseToAnyPublisher()
        }
      }

      // to ensure that only single authorization is in progress
      // we delegate result to the additional subject
      // and control cancellation internally
      let signInResultSubject: PassthroughSubject<Bool, TheError> = .init()

      authorizationCancellable =
        networkSession
        .createSession(
          account,
          account.domain,
          armoredPrivateKey,
          passphrase
        )
        .handleEvents(
          receiveOutput: { mfaProviders in
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

            if mfaProviders.isEmpty {
              sessionState = .authorized(account)
            }
            else {
              sessionState = .authorizedMFARequired(account, providers: mfaProviders)
              requestMFA(with: mfaProviders)
            }
          }
        )
        .map { mfaProviders in
          !mfaProviders.isEmpty // if array is not empty MFA authorization is required
        }
        .subscribe(signInResultSubject)

      return
        signInResultSubject
        .handleEvents(
          receiveCancel: {
            // When we cancel authorization we have to
            // cancel internal authorization publisher as well
            authorizationCancellable = nil
          }
        )
        .eraseToAnyPublisher()
    }

    func mfaAuthorize(
      method: MFAAuthorizationMethod,
      rememberDevice: Bool
    ) -> AnyPublisher<Void, TheError> {
      sessionStateSubject
        .first()
        .map { (sessionState: State) -> AnyPublisher<Void, TheError> in
          let account: Account
          switch sessionState {
          case let .authorized(currentAccount), let .authorizedMFARequired(currentAccount, _):
            account = currentAccount
          case .authorizationRequired, .none:
            return Fail<Void, TheError>(error: .authorizationRequired())
              .eraseToAnyPublisher()
          }

          return networkSession
            .createMFAToken(account, method, rememberDevice)
            .map { _  -> AnyPublisher<Void, TheError> in
              withSessionState { state -> AnyPublisher<Void, TheError> in
                switch sessionStateSubject.value {
                case let .authorized(currentAccount) where currentAccount == account,
                  let .authorizedMFARequired(currentAccount, _) where currentAccount == account:
                  // here we make side effect in this map
                  // unfortunately due to race condition we have
                  // to read the state and update it under same lock
                  // to avoid invalid session state
                  state = .authorized(account)
                  return Just(Void())
                    .setFailureType(to: TheError.self)
                    .eraseToAnyPublisher()
                case _:
                  return Fail<Void, TheError>(error: .authorizationRequired())
                    .eraseToAnyPublisher()
                }
              }
            }
            .switchToLatest()
            .eraseToAnyPublisher()
        }
        .switchToLatest()
        .eraseToAnyPublisher()
    }

    func decryptMessage(
      _ encryptedMessage: String,
      publicKey: ArmoredPGPPublicKey?
    ) -> AnyPublisher<String, TheError> {
      sessionStatePublisher
        .map { sessionState -> AnyPublisher<(ArmoredPGPPrivateKey, Passphrase), TheError> in
          switch sessionState {
          case let .authorized(account), let .authorizedMFARequired(account, _):
            switch accountsDataStore.loadAccountPrivateKey(account.localID) {
            case let .success(armoredKey):
              return passphraseCache
                .passphrasePublisher(account.localID)
                .setFailureType(to: TheError.self)
                .map { passphrase -> AnyPublisher<(ArmoredPGPPrivateKey, Passphrase), TheError> in
                  guard let passphrase: Passphrase = passphrase
                  else {
                    requestAuthorization(message: nil)
                    return Fail<(ArmoredPGPPrivateKey, Passphrase), TheError>(error: .authorizationRequired())
                      .eraseToAnyPublisher()
                  }
                  return Just((armoredKey, passphrase))
                    .setFailureType(to: TheError.self)
                    .eraseToAnyPublisher()
                }
                .switchToLatest()
                .eraseToAnyPublisher()

            case let .failure(error):
              diagnostics.debugLog(
                "Failed to retrieve private key for account: \(account.localID)"
                  + " - status: \(error.osStatus.map(String.init(describing:)) ?? "N/A")"
              )
              return Fail<(ArmoredPGPPrivateKey, Passphrase), TheError>(error: error)
                .eraseToAnyPublisher()
            }

          case .authorizationRequired, .none:
            requestAuthorization(message: nil)
            return Fail<(ArmoredPGPPrivateKey, Passphrase), TheError>(error: .authorizationRequired())
              .eraseToAnyPublisher()
          }
        }
        .switchToLatest()
        .map { armoredPrivateKey, passphrase -> AnyPublisher<String, TheError> in
          let decryptionResult: Result<String, TheError>
          if let publicKey: ArmoredPGPPublicKey = publicKey {
            decryptionResult = pgp.decryptAndVerify(
              encryptedMessage,
              passphrase,
              armoredPrivateKey,
              publicKey
            )
          }
          else {
            decryptionResult = pgp.decrypt(
              encryptedMessage,
              passphrase,
              armoredPrivateKey
            )
          }

          switch decryptionResult {
          case let .success(decrypted):
            return Just(decrypted)
              .setFailureType(to: TheError.self)
              .eraseToAnyPublisher()

          case let .failure(error):
            return Fail<String, TheError>(error: error)
              .eraseToAnyPublisher()
          }
        }
        .switchToLatest()
        .eraseToAnyPublisher()
    }

    func authorizationPromptPresentationPublisher() -> AnyPublisher<AuthorizationPromptRequest, Never> {
      authorizationPromptPresentationSubject
        .eraseToAnyPublisher()
    }

    func requestAuthorization(message: LocalizedMessage?) {
      switch sessionStateSubject.value {
      case let .authorized(account), let .authorizedMFARequired(account, _):
        passphraseCache.clear()
        authorizationPromptPresentationSubject.send(
          .passphraseRequest(account: account, message: message)
        )
      case let .authorizationRequired(account):
        authorizationPromptPresentationSubject.send(
          .passphraseRequest(account: account, message: message)
        )
      case .none:
        break
      }
    }

    func requestMFA(with providers: Array<MFAProvider>) {
      assert(
        !providers.isEmpty,
        "Cannot request MFA without providers"
      )

      withSessionState { state in
        switch state {
        case let .authorized(account),
          let .authorizedMFARequired(account, _),
          let .authorizationRequired(account):
          state = .authorizedMFARequired(account, providers: providers)
          authorizationPromptPresentationSubject.send(
            .mfaRequest(account: account, providers: providers)
          )

        case .none:
          break
        }
      }
    }

    return Self(
      statePublisher: { sessionStatePublisher },
      authorize: authorize(account:authorizationMethod:),
      mfaAuthorize: mfaAuthorize(method:rememberDevice:),
      decryptMessage: decryptMessage,
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
      mfaAuthorize: Commons.placeholder("You have to provide mocks for used methods"),
      decryptMessage: Commons.placeholder("You have to provide mocks for used methods"),
      authorizationPromptPresentationPublisher: Commons.placeholder("You have to provide mocks for used methods"),
      requestAuthorizationPrompt: Commons.placeholder("You have to provide mocks for used methods"),
      close: Commons.placeholder("You have to provide mocks for used methods")
    )
  }
}
#endif
