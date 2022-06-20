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

import CommonModels
import Crypto
import CryptoKit
import Features
import NetworkClient

import struct Foundation.Date
import struct Foundation.TimeInterval

public struct AccountSession {
  // Get currently used account with its authorization state.
  public var currentState: @AccountSessionActor () -> AccountSessionState
  // Publishes currently used account with its authorization state.
  public var statePublisher: () -> AnyPublisher<AccountSessionState, Never>
  // Used for sign in (including switch to other account) and unlocking whichever is required.
  // Returns true if MFA authorization is required, otherwise false.
  public var authorize: @AccountSessionActor (Account, AuthorizationMethod) async throws -> Bool
  // Used for MFA authorization if required. Executed always in context of current account.
  public var mfaAuthorize: @AccountSessionActor (MFAAuthorizationMethod, Bool) async throws -> Void
  // Decrypt message with current session context if any. Optionally verify signature if public key was provided.
  public var decryptMessage: @AccountSessionActor (String, ArmoredPGPPublicKey?) async throws -> String
  // Encrypt and sign message using provided public key with current session user signature.
  public var encryptAndSignMessage: @AccountSessionActor (String, ArmoredPGPPublicKey) async throws -> ArmoredPGPMessage
  // Set current account passphrase storage with biometry. Succeeds only if passphrase is in cache.
  // Storage is cleared when called with false. warning: it does not request proper permissions.
  internal var storePassphraseWithBiometry: @AccountSessionActor (Bool) async throws -> Void
  // Get the database encyption key for current account if able.
  internal var databaseKey: @AccountSessionActor () throws -> String
  // Publishes current account ID each time access to its private key
  // is required and cannot be handled automatically (passphrase cache is expired)
  public var authorizationPromptPresentationPublisher: () -> AnyPublisher<AuthorizationPromptRequest, Never>
  // Manual trigger for authorization prompt with proivided message.
  public var requestAuthorizationPrompt: @AccountSessionActor (DisplayableString?) -> Void
  // Closes current session and removes associated temporary data.
  // Not required for account switch, in that case use `authorize` with different account.
  public var close: @AccountSessionActor () async -> Void
}

extension AccountSession {

  internal static let passphraseCacheExpirationTimeInterval: TimeInterval = 5 * 60  // 5 minutes

  fileprivate enum InternalState: Equatable {

    case authorized(Account, Passphrase, expiration: Date)
    case authorizedMFARequired(Account, Passphrase, expiration: Date, providers: Array<MFAProvider>)
    case authorizationRequired(Account)
    case none(lastUsed: Account?)

    @AccountSessionActor fileprivate func withExpiration(
      dateNow: Date,
      requestAuthorization: @AccountSessionActor () -> Void
    ) -> Self {
      switch self {
      case let .authorized(account, passphrase, expiration):
        if expiration.distance(to: dateNow) < 0 {
          return .authorized(account, passphrase, expiration: expiration)
        }
        else {
          defer { requestAuthorization() }
          return .authorizationRequired(account)
        }

      case let .authorizedMFARequired(account, passphrase, expiration, mfaProviders):
        if expiration.distance(to: dateNow) < 0 {
          return .authorizedMFARequired(account, passphrase, expiration: expiration, providers: mfaProviders)
        }
        else {
          defer { requestAuthorization() }
          return .authorizationRequired(account)
        }

      case let .authorizationRequired(account):
        return .authorizationRequired(account)

      case let .none(lastUsedAccount):
        return .none(lastUsed: lastUsedAccount)
      }
    }

    // Warning: expiration time verification has to be done separately
    @AccountSessionActor fileprivate var asPublicState: AccountSessionState {
      switch self {
      case let .authorized(account, _, _):
        return .authorized(account)

      case let .authorizedMFARequired(account, _, _, mfaProviders):
        return .authorizedMFARequired(account, providers: mfaProviders)

      case let .authorizationRequired(account):
        return .authorizationRequired(account)

      case let .none(lastUsedAccount):
        return .none(lastUsed: lastUsedAccount)
      }
    }
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

extension AccountSession: LegacyFeature {

  public static func load(
    in environment: AppEnvironment,
    using features: FeatureFactory,
    cancellables: Cancellables
  ) async throws -> AccountSession {
    let pgp: PGP = environment.pgp
    let time: Time = environment.time
    let appLifeCycle: AppLifeCycle = environment.appLifeCycle

    let diagnostics: Diagnostics = try await features.instance()
    let accountsDataStore: AccountsDataStore = try await features.instance()
    let networkClient: NetworkClient = try await features.instance()
    let networkSession: NetworkSession = try await features.instance()

    let sessionCancellables: Cancellables = .init()

    // WARNING: always use currentSessionState method for accessing
    let internalSessionStateSubject: CurrentValueSubject<InternalState, Never> = await .init(
      .none(lastUsed: accountsDataStore.loadLastUsedAccount())
    )

    let authorizationTask: ManagedTask<Bool> = .init()

    let authorizationPromptPresentationSubject: PassthroughSubject<AuthorizationPromptRequest, Never> = .init()

    nonisolated func sessionStatePublisher() -> AnyPublisher<AccountSessionState, Never> {
      internalSessionStateSubject
        .map(\.asPublicState)
        .handleEvents(
          receiveSubscription: { [weak internalSessionStateSubject] _ in
            sessionCancellables.executeOnAccountSessionActor { [weak internalSessionStateSubject] in
              // force refresh state if needed
              // TODO: we should more proactively change status
              // on publisher by using timer instead
              guard let internalSessionStateSubject = internalSessionStateSubject, !Task.isCancelled
              else { return }

              let current: InternalState = internalSessionStateSubject.value
              let updated: InternalState =
                current
                .withExpiration(
                  dateNow: time.dateNow(),
                  requestAuthorization: {
                    requestAuthorization(message: nil)
                  }
                )
              if updated != current {
                internalSessionStateSubject.value = updated
              }
              else { /* NOP */
              }
            }
          }
        )
        .removeDuplicates()
        .eraseToAnyPublisher()
    }

    @AccountSessionActor func currentSessionState() -> InternalState {
      let current: InternalState =
        internalSessionStateSubject.value
      let updated: InternalState =
        current.withExpiration(
          dateNow: time.dateNow(),
          requestAuthorization: {
            requestAuthorization(message: nil)
          }
        )
      if updated != current {
        internalSessionStateSubject.value = updated
      }
      else { /* NOP */
      }
      return updated
    }

    // if we have passphrase in cache but network client requests auth
    // we could automatically refresh session in background
    await networkClient.setAuthorizationRequest({
      requestAuthorization(
        message: .localized("authorization.prompt.refresh.session.reason")
      )
    })

    await networkClient.setMFARequest(requestMFA(with:))

    // request authorization prompt when going back to the application
    // from the background with active session (includes authorizationRequired)
    // when going to background cancel ongoing authorization if any and change session state
    appLifeCycle
      .lifeCyclePublisher()
      .sink { transition in
        switch transition {
        case .willEnterForeground:
          sessionCancellables.executeOnAccountSessionActor {
            switch currentSessionState() {
            case let .authorizationRequired(account), let .authorized(account, _, _),
              let .authorizedMFARequired(account, _, _, _):
              internalSessionStateSubject.value = .authorizationRequired(account)
              // request authorization prompt for that account
              authorizationPromptPresentationSubject.send(.passphraseRequest(account: account, message: nil))

            case .none:
              return  // do nothing
            }
          }

        case .didEnterBackground:
          sessionCancellables.executeOnAccountSessionActor {
            // cancel previous authorization if any
            // we should not authorize in background
            await authorizationTask.cancel()
            switch currentSessionState() {
            case let .authorized(account, _, _),
              let .authorizedMFARequired(account, _, _, _):
              internalSessionStateSubject.value = .authorizationRequired(account)

            case .none, .authorizationRequired:
              break
            }
          }

        case _:
          break
        }
      }
      .store(in: cancellables)

    // Close current session and change session state (sign out)
    let closeSession: @AccountSessionActor () async -> Void = { [weak features] in
      diagnostics.diagnosticLog("Closing current session...")
      await features?.clearScope()  // cleanup features

      switch internalSessionStateSubject.value {
      case .authorized, .authorizationRequired, .authorizedMFARequired:
        await networkSession.closeSession()

      case .none:
        break  // do nothing
      }

      await sessionCancellables.cancelAll()
      await authorizationTask.cancel()  // cancel ongoing authorization if any

      // we provide none for last used to avoid skipping
      // account list in favor of the last account
      // when navigating to initial screen again
      // that account will be still used as last used
      // when launching application again anyway
      internalSessionStateSubject.value = .none(lastUsed: .none)
    }

    @AccountSessionActor func authorize(
      account: Account,
      authorizationMethod: AuthorizationMethod
    ) async throws -> Bool {
      diagnostics.diagnosticLog("Beginning authorization...")
      diagnostics.debugLog("Signing in to: \(account.localID)")

      // cancel previous authorization if any
      // there can't be more than a single ongoing authorization
      // intentionally using variable without lock,
      // required locking is made for the scope of this function
      await authorizationTask.cancel()

      let storedAccounts: Array<Account> = await accountsDataStore.loadAccounts()

      let switchingAccount: Bool
      switch currentSessionState() {
      case let .authorized(currentAccount, _, _),
        let .authorizedMFARequired(currentAccount, _, _, _),
        let .authorizationRequired(currentAccount):
        if currentAccount.userID != account.userID
          || (currentAccount.userID == account.userID && currentAccount.domain != account.domain)
          || (currentAccount.localID != account.localID && !storedAccounts.contains(currentAccount))
        {
          diagnostics.diagnosticLog("...switching account...")
          switchingAccount = true
        }
        else {
          switchingAccount = false
        }

      case .none:
        switchingAccount = true
      }

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
        switch await accountsDataStore.loadAccountPrivateKey(account.localID) {
        case let .success(armoredKey):
          diagnostics.diagnosticLog("...account private key found...")
          armoredPrivateKey = armoredKey

        case let .failure(error):
          diagnostics.diagnosticLog("...account private key unavailable!")
          diagnostics.debugLog(
            "Failed to retrieve private key for account: \(account.localID) - error: \(error)"
          )
          throw error
        }

      case .biometrics:
        diagnostics.diagnosticLog("...using biometrics...")
        switch await accountsDataStore.loadAccountPassphrase(account.localID) {
        case let .success(value):
          diagnostics.diagnosticLog("...account passphrase found...")
          passphrase = value

        case let .failure(error):
          diagnostics.diagnosticLog("...account passphrase unavailable!")
          throw error
        }
        switch await accountsDataStore.loadAccountPrivateKey(account.localID) {
        case let .success(armoredKey):
          diagnostics.diagnosticLog("...account private key found...")
          armoredPrivateKey = armoredKey

        case let .failure(error):
          diagnostics.diagnosticLog("...account private key unavailable!")
          diagnostics.debugLog(
            "Failed to retrieve private key for account: \(account.localID) - error: \(error)"
          )
          throw error
        }
      }

      // verify passphrase
      switch pgp.verifyPassphrase(armoredPrivateKey, passphrase) {
      case .success:
        break  // continue process

      case let .failure(error):
        diagnostics.diagnosticLog("...invalid passphrase!")
        throw
          error
          .asTheError()
          .pushing(.message("Invalid passphrase used for authorization"))
          .recording(account, for: "account")
      }

      @AccountSessionActor func createSession() async throws -> Bool {
        let mfaProviders: Array<MFAProvider> =
          try await networkSession
          .createSession(
            account,
            armoredPrivateKey,
            passphrase
          )

        await accountsDataStore.storeLastUsedAccount(account.localID)

        // FIXME: retain cycle with features
        await features.ensureScope(identifier: account)

        if mfaProviders.isEmpty {
          diagnostics.diagnosticLog("...authorization succeeded!")

          internalSessionStateSubject.value = .authorized(
            account,
            passphrase,
            expiration:
              time
              .dateNow()
              .addingTimeInterval(AccountSession.passphraseCacheExpirationTimeInterval)
          )
        }
        else {
          diagnostics.diagnosticLog("...MFA authorization required!")

          internalSessionStateSubject.value = .authorizedMFARequired(
            account,
            passphrase,
            expiration:
              time
              .dateNow()
              .addingTimeInterval(AccountSession.passphraseCacheExpirationTimeInterval),
            providers: mfaProviders
          )

          requestMFA(with: mfaProviders)
        }

        return !mfaProviders.isEmpty  // if array is not empty MFA authorization is required
      }

      @AccountSessionActor func refreshSessionIfNeeded() async throws {
        try await networkSession.refreshSessionIfNeeded(account)

        diagnostics.diagnosticLog("...authorization succeeded!")

        internalSessionStateSubject.value = .authorized(
          account,
          passphrase,
          expiration:
            time
            .dateNow()
            .addingTimeInterval(AccountSession.passphraseCacheExpirationTimeInterval)
        )
      }

      if switchingAccount {
        await sessionCancellables.cancelAll()
        return try await authorizationTask.run(replacingCurrent: true) {
          do {
            return try await createSession()
          }
          catch is CancellationError, is Cancelled {
            diagnostics.diagnosticLog("...authorization canceled!")
            throw CancellationError()
          }
          catch {
            throw error
          }
        }
      }
      else {
        return try await authorizationTask.run {
          do {
            try await refreshSessionIfNeeded()
            return false  // successful session refresh either does not
            // require MFA (and further authorization)
            // or fails by throwing error
          }
          catch is CancellationError, is Cancelled {
            diagnostics.diagnosticLog("...authorization canceled!")
            throw CancellationError()
          }
          catch {
            do {
              return try await createSession()
            }
            catch is CancellationError, is Cancelled {
              diagnostics.diagnosticLog("...authorization canceled!")
              throw CancellationError()
            }
            catch {
              throw error
            }
          }
        }
      }
    }

    @AccountSessionActor func mfaAuthorize(
      method: MFAAuthorizationMethod,
      rememberDevice: Bool
    ) async throws {
      diagnostics.diagnosticLog("Beginning MFA authorization...")

      let account: Account
      switch currentSessionState() {
      case let .authorized(currentAccount, _, _),
        let .authorizedMFARequired(currentAccount, _, _, _),
        let .authorizationRequired(currentAccount):
        account = currentAccount

      case .none:
        diagnostics.diagnosticLog("...authorization required!")
        throw
          SessionMissing
          .error("Missing session for MFA authorization")
      }

      try await networkSession.createMFAToken(account, method, rememberDevice)

      switch currentSessionState() {
      case let .authorized(currentAccount, passphrase, _) where currentAccount == account,
        let .authorizedMFARequired(currentAccount, passphrase, _, _) where currentAccount == account:
        internalSessionStateSubject.value = .authorized(
          account,
          passphrase,
          expiration:
            time
            .dateNow()
            .addingTimeInterval(AccountSession.passphraseCacheExpirationTimeInterval)
        )
        diagnostics.diagnosticLog("...MFA authorization succeeded!")

      case let .authorized(currentAccount, _, _),
        let .authorizedMFARequired(currentAccount, _, _, _),
        let .authorizationRequired(currentAccount):
        diagnostics.diagnosticLog("...MFA authorization failed due to account switch!")
        throw
          SessionClosed
          .error(
            "Closed session used for MFA authorization",
            account: account
          )
          .recording(currentAccount, for: "currentAccount")
          .recording(account, for: "expectedAccount")

      case .none:
        diagnostics.diagnosticLog("...MFA authorization failed!")
        throw
          SessionClosed
          .error(
            "Closed session used for MFA authorization",
            account: account
          )
      }
    }

    @AccountSessionActor func decryptMessage(
      _ encryptedMessage: String,
      publicKey: ArmoredPGPPublicKey?
    ) async throws -> String {
      switch currentSessionState() {
      case let .authorized(account, passphrase, _), let .authorizedMFARequired(account, passphrase, _, _):
        switch await accountsDataStore.loadAccountPrivateKey(account.localID) {
        case let .success(armoredPrivateKey):
          let decryptionResult: Result<String, Error>
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
            return decrypted

          case let .failure(error):
            throw error
          }

        case let .failure(error):
          diagnostics.debugLog(
            "Failed to retrieve private key for account: \(account.localID) - error: \(error)"
          )
          throw error
        }

      case let .authorizationRequired(account):
        throw
          SessionAuthorizationRequired
          .error(
            "Session authorization required for decrypting message",
            account: account
          )

      case .none:
        throw
          SessionMissing
          .error("No session provided for decrypting message")
      }
    }

    @AccountSessionActor func encryptAndSignMessage(
      _ message: String,
      publicKey: ArmoredPGPPublicKey
    ) async throws -> ArmoredPGPMessage {
      switch currentSessionState() {
      case let .authorized(account, passphrase, _), let .authorizedMFARequired(account, passphrase, _, _):
        switch await accountsDataStore.loadAccountPrivateKey(account.localID) {
        case let .success(armoredPrivateKey):
          let encryptionResult: Result<String, Error> = pgp.encryptAndSign(
            message,
            passphrase,
            armoredPrivateKey,
            publicKey
          )

          switch encryptionResult {
          case let .success(encrypted):
            return .init(rawValue: encrypted)

          case let .failure(error):
            throw error
          }

        case let .failure(error):
          diagnostics.debugLog(
            "Failed to retrieve private key for account: \(account.localID) - error: \(error)"
          )
          throw error
        }

      case let .authorizationRequired(account):
        throw
          SessionAuthorizationRequired
          .error(
            "Session authorization required for decrypting message",
            account: account
          )

      case .none:
        throw
          SessionMissing
          .error("No session provided for encrypting message")
      }
    }

    @AccountSessionActor func storePassphraseWithBiometry(_ store: Bool) async throws {
      let currentAccount: Account
      let cachedPassphrase: Passphrase

      switch currentSessionState() {
      case let .authorized(account, passphrase, _),
        let .authorizedMFARequired(account, passphrase, _, _):
        currentAccount = account
        cachedPassphrase = passphrase

      case let .authorizationRequired(account):
        authorizationPromptPresentationSubject
          .send(
            .passphraseRequest(
              account: account,
              message: nil
            )
          )

        throw
          SessionAuthorizationRequired
          .error(
            "Session authorization required for storing passphrase",
            account: account
          )

      case .none:
        throw
          SessionMissing
          .error("No session provided for storing passphrase")
      }

      if store {
        return try await accountsDataStore.storeAccountPassphrase(currentAccount.localID, cachedPassphrase)
          .get()
      }
      else {
        return try await accountsDataStore.deleteAccountPassphrase(currentAccount.localID)
          .get()
      }
    }

    @AccountSessionActor func databaseKey() throws -> String {
      switch currentSessionState() {
      case let .authorized(_, passphrase, _),
        let .authorizedMFARequired(_, passphrase, _, _):
        // prepare hash from passphrase
        // to be used as database key
        let key: String? = passphrase
          .rawValue
          .data(using: .utf8)
          .map { data in
            SHA512
              .hash(data: data)
              .compactMap { String(format: "%02x", $0) }
              .joined()
          }
        if let databaseKey: String = key {
          return databaseKey
        }
        else {
          throw
            InternalInconsistency
            .error("Failed to prepare database key")
        }

      case let .authorizationRequired(account):
        throw
          SessionAuthorizationRequired
          .error(account: account)

      case .none:
        throw
          SessionMissing
          .error()
      }
    }

    nonisolated func authorizationPromptPresentationPublisher() -> AnyPublisher<AuthorizationPromptRequest, Never> {
      authorizationPromptPresentationSubject
        .eraseToAnyPublisher()
    }

    @AccountSessionActor func requestAuthorization(
      message: DisplayableString?
    ) {
      let sessionState: InternalState =
        internalSessionStateSubject
        .value
        .withExpiration(
          dateNow: time.dateNow(),
          requestAuthorization: {
            /* NOP - don't trigger recursion */
          }
        )
      switch sessionState {
      case let .authorized(account, _, _), let .authorizedMFARequired(account, _, _, _):
        internalSessionStateSubject.value = .authorizationRequired(account)
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

    @AccountSessionActor func requestMFA(with providers: Array<MFAProvider>) {
      switch currentSessionState() {
      case let .authorized(account, passphrase, expiration),
        let .authorizedMFARequired(account, passphrase, expiration, _):
        internalSessionStateSubject.value = .authorizedMFARequired(
          account,
          passphrase,
          expiration: expiration,
          providers: providers
        )
        authorizationPromptPresentationSubject.send(
          .mfaRequest(account: account, providers: providers)
        )

      case let .authorizationRequired(account):
        authorizationPromptPresentationSubject.send(
          .mfaRequest(account: account, providers: providers)
        )

      case .none:
        break
      }
    }

    return Self(
      currentState: { @AccountSessionActor in
        currentSessionState()
          .asPublicState
      },
      statePublisher: sessionStatePublisher,
      authorize: authorize(account:authorizationMethod:),
      mfaAuthorize: mfaAuthorize(method:rememberDevice:),
      decryptMessage: decryptMessage,
      encryptAndSignMessage: encryptAndSignMessage(_:publicKey:),
      storePassphraseWithBiometry: storePassphraseWithBiometry(_:),
      databaseKey: databaseKey,
      authorizationPromptPresentationPublisher: authorizationPromptPresentationPublisher,
      requestAuthorizationPrompt: { message in
        sessionCancellables.executeOnAccountSessionActor {
          requestAuthorization(message: message)
        }
      },
      close: closeSession
    )
  }
}

#if DEBUG
extension AccountSession {

  public static var placeholder: AccountSession {
    Self(
      currentState: unimplemented("You have to provide mocks for used methods"),
      statePublisher: unimplemented("You have to provide mocks for used methods"),
      authorize: unimplemented("You have to provide mocks for used methods"),
      mfaAuthorize: unimplemented("You have to provide mocks for used methods"),
      decryptMessage: unimplemented("You have to provide mocks for used methods"),
      encryptAndSignMessage: unimplemented("You have to provide mocks for used methods"),
      storePassphraseWithBiometry: unimplemented("You have to provide mocks for used methods"),
      databaseKey: unimplemented("You have to provide mocks for used methods"),
      authorizationPromptPresentationPublisher: unimplemented("You have to provide mocks for used methods"),
      requestAuthorizationPrompt: unimplemented("You have to provide mocks for used methods"),
      close: unimplemented("You have to provide mocks for used methods")
    )
  }
}
#endif

public enum AuthorizationPromptRequest {

  case passphraseRequest(account: Account, message: DisplayableString?)
  case mfaRequest(account: Account, providers: Array<MFAProvider>)

  public var account: Account {
    switch self {
    case let .passphraseRequest(account, _):
      return account
    case let .mfaRequest(account, _):
      return account
    }
  }

  public var message: DisplayableString? {
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
