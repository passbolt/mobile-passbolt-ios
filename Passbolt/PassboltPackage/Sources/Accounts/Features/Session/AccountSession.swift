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

import CommonDataModels
import Crypto
import Features
import NetworkClient

import class Foundation.NSRecursiveLock

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
  // Encrypt and sign message using provided public key with current session user signature.
  public var encryptAndSignMessage: (String, ArmoredPGPPublicKey) -> AnyPublisher<ArmoredPGPMessage, TheError>
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

    let sessionStateSubject: CurrentValueSubject<State, Never> = .init(
      .none(lastUsed: accountsDataStore.loadLastUsedAccount())
    )
    let sessionStateLock: NSRecursiveLock = .init()
    // synchronizing access to session state due to possible race conditions
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
    func withSessionState<Returned>(
      _ access: (inout State) -> Returned
    ) -> Returned {
      sessionStateLock.lock()
      defer { sessionStateLock.unlock() }
      var value: State = sessionStateSubject.value
      defer { sessionStateSubject.send(value) }
      return access(&value)
    }
    // swift-format-ignore: NoLeadingUnderscores
    var _authorizationCancellable: AnyCancellable?
    var authorizationCancellable: AnyCancellable? {
      get {
        sessionStateLock.lock()
        defer { sessionStateLock.unlock() }
        return _authorizationCancellable
      }
      set {
        sessionStateLock.lock()
        _authorizationCancellable = newValue
        sessionStateLock.unlock()
      }
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

    // bind passphrase cache expiration with authorizationRequired state change
    sessionStatePublisher
      .compactMap { state -> AnyPublisher<State, Never>? in
        switch state {
        case let .authorized(account), let .authorizedMFARequired(account, _):
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
      diagnostics.diagnosticLog("Clearing current session state.")
      authorizationCancellable = nil
      passphraseCache.clear()
      features.unload(AccountDatabase.self)

      switch sessionState {
      case .authorized, .authorizationRequired, .authorizedMFARequired:
        networkSession
          .closeSession()
          .collectErrorLog(using: diagnostics)
          .ignoreOutput()
          .sinkDrop()
          .store(in: cancellables)

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
      diagnostics.diagnosticLog("Beginning authorization...")
      diagnostics.debugLog("Signing in to: \(account.localID)")

      return withSessionState { sessionState in
        // cancel previous authorization if any
        // there can't be more than a single ongoing authorization
        // intentionally using variable without lock,
        // required locking is made for the scope of this function
        _authorizationCancellable = nil

        switch sessionState {
        case let .authorized(currentAccount),
          let .authorizedMFARequired(currentAccount, _),
          let .authorizationRequired(currentAccount):
          if currentAccount.userID != account.userID
            || (currentAccount.userID == account.userID && currentAccount.domain != account.domain)
            || (currentAccount.localID != account.localID && !accountsDataStore.loadAccounts().contains(currentAccount))
          {
            diagnostics.diagnosticLog("...switching account...")
            diagnostics.debugLog("Signing out \(currentAccount.localID)")
            // signout from current account on switching accounts
            _clearCurrentSession()
          }
          else {
            break
          }

        case .none:
          break
        }

        // since we are trying to sign in we change current session state
        // to a new one with authorizationRequired state to indicate
        // that we are signing in and to change network client base url / domain if needed
        sessionState = .authorizationRequired(account)

        // prepare passphrase and armored private key
        let passphrase: Passphrase
        let armoredPrivateKey: ArmoredPGPPrivateKey
        switch authorizationMethod {
        case let .adHoc(pass, privateKey):
          diagnostics.diagnosticLog("...using ad-hoc credentials...")
          passphrase = pass
          armoredPrivateKey = privateKey
        case let .passphrase(value):
          diagnostics.diagnosticLog("...using passphrase...")
          passphrase = value
          switch accountsDataStore.loadAccountPrivateKey(account.localID) {
          case let .success(armoredKey):
            diagnostics.diagnosticLog("...account private key found...")
            armoredPrivateKey = armoredKey
          case let .failure(error):
            diagnostics.diagnosticLog("...account private key unavailable!")
            diagnostics.debugLog(
              "Failed to retrieve private key for account: \(account.localID)"
                + " - status: \(error.osStatus.map(String.init(describing:)) ?? "N/A")"
            )
            return Fail<Bool, TheError>(error: error)
              .eraseToAnyPublisher()
          }

        case .biometrics:
          diagnostics.diagnosticLog("...using biometrics...")
          switch accountsDataStore.loadAccountPassphrase(account.localID) {
          case let .success(value):
            diagnostics.diagnosticLog("...account passphrase found...")
            passphrase = value
          case let .failure(error):
            diagnostics.diagnosticLog("...account passphrase unavailable!")
            return Fail<Bool, TheError>(error: error)
              .eraseToAnyPublisher()
          }
          switch accountsDataStore.loadAccountPrivateKey(account.localID) {
          case let .success(armoredKey):
            diagnostics.diagnosticLog("...account private key found...")
            armoredPrivateKey = armoredKey
          case let .failure(error):
            diagnostics.diagnosticLog("...account private key unavailable!")
            diagnostics.debugLog(
              "Failed to retrieve private key for account: \(account.localID)"
                + " - status: \(error.osStatus.map(String.init(describing:)) ?? "N/A")"
            )
            return Fail<Bool, TheError>(error: error)
              .eraseToAnyPublisher()
          }
        }

        // verify passphrase
        switch pgp.verifyPassphrase(armoredPrivateKey, passphrase) {
        case .success:
          break  // continue process

        case let .failure(error):
          diagnostics.diagnosticLog("...invalid passphrase!")
          return Fail(error: error)
            .eraseToAnyPublisher()
        }

        func createSession() -> AnyPublisher<Bool, TheError> {
          networkSession
            .createSession(
              account,
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
                  diagnostics.diagnosticLog("...authorization succeeded!")
                  withSessionState { sessionState in
                    sessionState = .authorized(account)
                  }
                }
                else {
                  diagnostics.diagnosticLog("...MFA authorization required!")
                  withSessionState { sessionState in
                    sessionState = .authorizedMFARequired(account, providers: mfaProviders)
                  }
                  requestMFA(with: mfaProviders)
                }
              }
            )
            .map { mfaProviders in
              !mfaProviders.isEmpty  // if array is not empty MFA authorization is required
            }
            .eraseToAnyPublisher()
        }

        func refreshSessionIfNeeded() -> AnyPublisher<Void, TheError> {
          networkSession
            .refreshSessionIfNeeded(account)
            .handleEvents(
              receiveOutput: {
                passphraseCache
                  .store(
                    passphrase,
                    account.localID,
                    .init(
                      timeIntervalSince1970: .init(time.timestamp())
                        + PassphraseCache.defaultExpirationTimeInterval
                    )
                  )
                withSessionState { sessionState in
                  sessionState = .authorized(account)
                }
                diagnostics.diagnosticLog("...authorization succeeded!")
              }
            )
            .eraseToAnyPublisher()
        }

        // to ensure that only single authorization is in progress
        // we delegate result to the additional subject
        // and control cancellation internally
        let authorizationResultSubject: PassthroughSubject<Bool, TheError> = .init()

        // check if session can be refreshed for provided account
        if networkSession.sessionRefreshAvailable(account) {
          authorizationCancellable =
            refreshSessionIfNeeded()
            // MFA in response is not possible, it is handled by error path
            .map { false }
            .catch { error -> AnyPublisher<Bool, TheError> in
              if case .canceled = error {
                return Fail(error: error)
                  .eraseToAnyPublisher()
              }
              else {
                return createSession()
              }
            }
            .subscribe(authorizationResultSubject)
        }
        else {
          authorizationCancellable = createSession()
            .subscribe(authorizationResultSubject)
        }

        return
          authorizationResultSubject
          .handleEvents(
            receiveCancel: {
              authorizationCancellable?.cancel()
              diagnostics.diagnosticLog("...authorization canceled!")
            }
          )
          .eraseToAnyPublisher()
      }
    }

    func mfaAuthorize(
      method: MFAAuthorizationMethod,
      rememberDevice: Bool
    ) -> AnyPublisher<Void, TheError> {
      diagnostics.diagnosticLog("Beginning MFA authorization...")
      let account: Account
      switch sessionState {
      case let .authorized(currentAccount),
        let .authorizedMFARequired(currentAccount, _),
        let .authorizationRequired(currentAccount):
        account = currentAccount
      case .none:
        diagnostics.diagnosticLog("...authorization required!")
        return Fail<Void, TheError>(error: .authorizationRequired())
          .eraseToAnyPublisher()
      }

      return
        networkSession
        .createMFAToken(account, method, rememberDevice)
        .map { _ -> AnyPublisher<Void, TheError> in
          withSessionState { state -> AnyPublisher<Void, TheError> in
            switch state {
            case let .authorized(currentAccount) where currentAccount == account,
              let .authorizedMFARequired(currentAccount, _) where currentAccount == account:
              // here we make side effect in this map
              // unfortunately due to race condition we have
              // to read the state and update it under same lock
              // to avoid invalid session state
              state = .authorized(account)
              diagnostics.diagnosticLog("...MFA authorization succeeded!")
              return Just(Void())
                .setFailureType(to: TheError.self)
                .eraseToAnyPublisher()

            case .authorized, .authorizedMFARequired:
              diagnostics.diagnosticLog("...MFA authorization failed due to account switch!")
              return Fail<Void, TheError>(error: .sessionClosed())
                .eraseToAnyPublisher()

            case .none, .authorizationRequired:
              diagnostics.diagnosticLog("...MFA authorization failed!")
              return Fail<Void, TheError>(error: .authorizationRequired())
                .eraseToAnyPublisher()
            }
          }
        }
        .switchToLatest()
        .eraseToAnyPublisher()
    }

    func decryptMessage(
      _ encryptedMessage: String,
      publicKey: ArmoredPGPPublicKey?
    ) -> AnyPublisher<String, TheError> {
      switch sessionState {
      case let .authorized(account), let .authorizedMFARequired(account, _):
        switch accountsDataStore.loadAccountPrivateKey(account.localID) {
        case let .success(armoredKey):
          return
            passphraseCache
            .passphrasePublisher(account.localID)
            .first()
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
            .map {
              (armoredPrivateKey: ArmoredPGPPrivateKey, passphrase: Passphrase) -> AnyPublisher<String, TheError> in
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

        case let .failure(error):
          diagnostics.debugLog(
            "Failed to retrieve private key for account: \(account.localID)"
              + " - status: \(error.osStatus.map(String.init(describing:)) ?? "N/A")"
          )
          return Fail<String, TheError>(error: error)
            .eraseToAnyPublisher()
        }

      case .authorizationRequired, .none:
        requestAuthorization(message: nil)
        return Fail<String, TheError>(error: .authorizationRequired())
          .eraseToAnyPublisher()
      }
    }

    func encryptAndSignMessage(
      _ message: String,
      publicKey: ArmoredPGPPublicKey
    ) -> AnyPublisher<ArmoredPGPMessage, TheError> {
      switch sessionState {
      case let .authorized(account), let .authorizedMFARequired(account, _):
        switch accountsDataStore.loadAccountPrivateKey(account.localID) {
        case let .success(armoredKey):
          return
            passphraseCache
            .passphrasePublisher(account.localID)
            .first()
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
            .map { armoredPrivateKey, passphrase -> AnyPublisher<ArmoredPGPMessage, TheError> in
              let encryptionResult: Result<String, TheError> = pgp.encryptAndSign(
                message,
                passphrase,
                armoredPrivateKey,
                publicKey
              )

              switch encryptionResult {
              case let .success(encrypted):
                return Just(.init(rawValue: encrypted))
                  .setFailureType(to: TheError.self)
                  .eraseToAnyPublisher()

              case let .failure(error):
                return Fail<ArmoredPGPMessage, TheError>(error: error)
                  .eraseToAnyPublisher()
              }
            }
            .switchToLatest()
            .eraseToAnyPublisher()

        case let .failure(error):
          diagnostics.debugLog(
            "Failed to retrieve private key for account: \(account.localID)"
              + " - status: \(error.osStatus.map(String.init(describing:)) ?? "N/A")"
          )
          return Fail<ArmoredPGPMessage, TheError>(error: error)
            .eraseToAnyPublisher()
        }

      case .authorizationRequired, .none:
        requestAuthorization(message: nil)
        return Fail<ArmoredPGPMessage, TheError>(error: .authorizationRequired())
          .eraseToAnyPublisher()
      }
    }

    func authorizationPromptPresentationPublisher() -> AnyPublisher<AuthorizationPromptRequest, Never> {
      authorizationPromptPresentationSubject
        .eraseToAnyPublisher()
    }

    func requestAuthorization(message: LocalizedMessage?) {
      switch sessionState {
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
      encryptAndSignMessage: encryptAndSignMessage(_:publicKey:),
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
      encryptAndSignMessage: Commons.placeholder("You have to provide mocks for used methods"),
      authorizationPromptPresentationPublisher: Commons.placeholder("You have to provide mocks for used methods"),
      requestAuthorizationPrompt: Commons.placeholder("You have to provide mocks for used methods"),
      close: Commons.placeholder("You have to provide mocks for used methods")
    )
  }
}
#endif

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
