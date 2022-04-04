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
import Features
import NetworkClient
import TestExtensions
import XCTest

@testable import Accounts

// swift-format-ignore: AlwaysUseLowerCamelCase, NeverUseImplicitlyUnwrappedOptionals
final class AccountSessionTests: TestCase {

  var accountsDataStore: AccountsDataStore!
  var networkClient: NetworkClient!

  override func featuresActorSetUp() async throws {
    try await super.featuresActorSetUp()
    accountsDataStore = .placeholder
    accountsDataStore.loadLastUsedAccount = always(validAccount)
    accountsDataStore.loadAccounts = always([])
    networkClient = .placeholder
    networkClient.setAuthorizationRequest = always(Void())
    networkClient.setMFARequest = always(Void())
    networkClient.setSessionStateSource = always(Void())
    environment.appLifeCycle.lifeCyclePublisher = always(Empty().eraseToAnyPublisher())
    environment.time.timestamp = always(0)
    environment.pgp.verifyPassphrase = always(.success)
    features.patch(\NetworkSession.refreshSessionIfNeeded, with: alwaysThrow(MockIssue.error()))
  }

  override func featuresActorTearDown() async throws {
    accountsDataStore = nil
    networkClient = nil
    try await super.featuresActorTearDown()
  }

  func test_statePublisher_publishesNoneState_initially() async throws {
    await features.patch(
      \AccountsDataStore.loadLastUsedAccount,
      with: always(.none)
    )
    await features.use(networkClient)
    await features.usePlaceholder(for: NetworkSession.self)

    let feature: AccountSession = try await testInstance()

    var result: AccountSessionState?
    feature
      .statePublisher()
      .sink { state in
        result = state
      }
      .store(in: cancellables)

    // temporary wait for detached tasks
    try await Task.sleep(nanoseconds: 100 * NSEC_PER_MSEC)

    XCTAssertEqual(result, .some(.none(lastUsed: .none)))
  }

  func test_statePublisher_publishesLastUsedAccount_initially() async throws {
    await features.patch(
      \AccountsDataStore.loadLastUsedAccount,
      with: always(validAccount)
    )
    await features.use(networkClient)
    await features.usePlaceholder(for: NetworkSession.self)

    let feature: AccountSession = try await testInstance()

    var result: Account?
    feature
      .statePublisher()
      .sink { state in
        guard case let .none(lastUsed) = state
        else { return }
        result = lastUsed
      }
      .store(in: cancellables)

    // temporary wait for detached tasks
    try await Task.sleep(nanoseconds: 100 * NSEC_PER_MSEC)

    XCTAssertEqual(result, validAccount)
  }

  func test_statePublisher_publishesAuthorized_whenAuthorizationSucceeds() async throws {
    accountsDataStore.storeLastUsedAccount = always(Void())
    await features.use(accountsDataStore)
    await features.use(networkClient)
    await features.patch(
      \NetworkSession.createSession,
      with: always(
        Array<MFAProvider>()
      )
    )
    let feature: AccountSession = try await testInstance()

    var result: Account?
    feature
      .statePublisher()
      .sink { state in
        guard case let .authorized(account) = state
        else { return }
        result = account
      }
      .store(in: cancellables)

    _ =
      try await feature
      .authorize(validAccount, .adHoc("passphrase", "private key"))

    XCTAssertEqual(result, validAccount)
  }

  func test_statePublisher_publishesAuthorizationRequired_whenAppGoesIntoBackgroundWithSession() async throws {
    accountsDataStore.storeLastUsedAccount = always(Void())
    await features.use(accountsDataStore)
    await features.use(networkClient)
    await features.patch(
      \NetworkSession.createSession,
      with: always(
        Array<MFAProvider>()
      )
    )
    let lifeCycleSubject: PassthroughSubject<AppLifeCycle.Transition, Never> = .init()
    try await FeaturesActor.execute {
      self.features.environment.appLifeCycle.lifeCyclePublisher = {
        lifeCycleSubject.eraseToAnyPublisher()
      }
    }

    let feature: AccountSession = try await testInstance()

    var result: Account?
    feature
      .statePublisher()
      .sink { state in
        guard case let .authorizationRequired(account) = state
        else { return }
        result = account
      }
      .store(in: cancellables)

    _ =
      try await feature
      .authorize(validAccount, .adHoc("passphrase", "private key"))

    lifeCycleSubject.send(.didEnterBackground)

    // temporary wait for detached tasks
    try await Task.sleep(nanoseconds: 100 * NSEC_PER_MSEC)

    XCTAssertEqual(result, validAccount)
  }

  func test_statePublisher_publishesNone_whenClosingSession() async throws {
    accountsDataStore.storeLastUsedAccount = always(Void())
    await features.use(accountsDataStore)
    await features.use(networkClient)
    await features.patch(
      \NetworkSession.createSession,
      with: always(
        Array<MFAProvider>()
      )
    )
    await features.patch(
      \NetworkSession.closeSession,
      with: always(
        Void()
      )
    )

    let feature: AccountSession = try await testInstance()

    var result: Void?
    feature
      .statePublisher()
      .dropFirst()
      .sink { state in
        guard case .none = state
        else { return }
        result = Void()
      }
      .store(in: cancellables)

    _ =
      try await feature
      .authorize(validAccount, .adHoc("passphrase", "private key"))

    await feature.close()

    // temporary wait for detached tasks
    try await Task.sleep(nanoseconds: 100 * NSEC_PER_MSEC)

    XCTAssertNotNil(result)
  }

  func test_statePublisher_publishesNoLastUsedAccount_whenClosingSession() async throws {
    accountsDataStore.storeLastUsedAccount = always(Void())
    await features.use(accountsDataStore)
    await features.use(networkClient)
    await features.patch(
      \NetworkSession.createSession,
      with: always(
        Array<MFAProvider>()
      )
    )
    await features.patch(
      \NetworkSession.closeSession,
      with: always(
        Void()
      )
    )

    let feature: AccountSession = try await testInstance()

    _ =
      try await feature
      .authorize(validAccount, .adHoc("passphrase", "private key"))

    var result: Account?
    feature
      .statePublisher()
      .dropFirst()
      .sink { state in
        guard case let .none(lastUsed) = state
        else { return }
        result = lastUsed
      }
      .store(in: cancellables)

    await feature.close()

    XCTAssertNil(result)
  }

  func test_statePublisher_publishesAuthorizationRequired_whenPassphraseCacheIsExpired() async throws {
    accountsDataStore.storeLastUsedAccount = always(Void())
    await features.use(accountsDataStore)
    await features.use(networkClient)
    await features.patch(
      \NetworkSession.createSession,
      with: always(
        Array<MFAProvider>()
      )
    )
    await features.patch(
      \NetworkSession.closeSession,
      with: always(
        Void()
      )
    )
    var currentTimestamp: Timestamp = 0
    try await FeaturesActor.execute {
      self.environment.time.timestamp = always(currentTimestamp)
    }

    let feature: AccountSession = try await testInstance()

    _ =
      try await feature
      .authorize(validAccount, .adHoc("passphrase", "private key"))

    currentTimestamp = Timestamp(rawValue: 5 * 60)  // expired time

    var result: Account?
    feature
      .statePublisher()
      .sink { state in
        guard case let .authorizationRequired(account) = state
        else { return }
        result = account
      }
      .store(in: cancellables)

    // temporary wait for detached tasks
    try await Task.sleep(nanoseconds: 100 * NSEC_PER_MSEC)

    XCTAssertEqual(result, validAccount)
  }

  func test_decryptMessage_fails_whenPassphraseCacheIsExpired() async throws {
    accountsDataStore.storeLastUsedAccount = always(Void())
    await features.use(accountsDataStore)
    await features.use(networkClient)
    await features.patch(
      \NetworkSession.createSession,
      with: always(
        Array<MFAProvider>()
      )
    )
    await features.patch(
      \NetworkSession.closeSession,
      with: always(
        Void()
      )
    )

    var currentTimestamp: Timestamp = 0
    try await FeaturesActor.execute {
      self.environment.time.timestamp = always(currentTimestamp)
    }

    let feature: AccountSession = try await testInstance()

    _ =
      try await feature
      .authorize(validAccount, .adHoc("passphrase", "private key"))

    currentTimestamp = Timestamp(rawValue: 5 * 60)  // expired time

    var result: Error?
    do {
      _ =
        try await feature
        .decryptMessage("encrypted message", nil)
    }
    catch {
      result = error
    }

    XCTAssertError(result, matches: SessionAuthorizationRequired.self)
  }

  func test_decryptMessage_fails_withoutActiveSession() async throws {
    await features.use(accountsDataStore)
    await features.use(networkClient)
    await features.usePlaceholder(for: NetworkSession.self)

    let feature: AccountSession = try await testInstance()

    var result: Error?
    do {
      _ =
        try await feature
        .decryptMessage("encrypted message", nil)
    }
    catch {
      result = error
    }

    XCTAssertError(result, matches: SessionMissing.self)
  }

  func test_decryptMessage_fails_whenLoadingAccountPrivateKeyFails() async throws {
    accountsDataStore.storeLastUsedAccount = always(Void())
    accountsDataStore.loadAccountPrivateKey = always(.failure(MockIssue.error()))
    await features.use(accountsDataStore)
    await features.use(networkClient)
    await features.patch(
      \NetworkSession.createSession,
      with: always(
        Array<MFAProvider>()
      )
    )

    let feature: AccountSession = try await testInstance()

    _ =
      try await feature
      .authorize(validAccount, .adHoc("passphrase", "private key"))

    var result: Error?
    do {
      _ =
        try await feature
        .decryptMessage("encrypted message", nil)
    }
    catch {
      result = error
    }

    XCTAssertError(result, matches: MockIssue.self)
  }

  func test_decryptMessage_fails_whenDecryptionFails() async throws {
    accountsDataStore.storeLastUsedAccount = always(Void())
    accountsDataStore.loadAccountPrivateKey = always(.success(armoredPGPPrivateKey))
    await features.use(accountsDataStore)
    await features.use(networkClient)
    await features.patch(
      \NetworkSession.createSession,
      with: always(
        Array<MFAProvider>()
      )
    )

    try await FeaturesActor.execute {
      self.environment.pgp.decrypt = always(.failure(MockIssue.error()))
    }

    let feature: AccountSession = try await testInstance()

    _ =
      try await feature
      .authorize(validAccount, .adHoc("passphrase", "private key"))

    var result: Error?
    do {
      _ =
        try await feature
        .decryptMessage("encrypted message", nil)
    }
    catch {
      result = error
    }

    XCTAssertError(result, matches: MockIssue.self)
  }

  func test_decryptMessage_succeeds_whenDecryptionSucceeds() async throws {
    accountsDataStore.storeLastUsedAccount = always(Void())
    accountsDataStore.loadAccountPrivateKey = always(.success(armoredPGPPrivateKey))
    await features.use(accountsDataStore)
    await features.use(networkClient)
    await features.patch(
      \NetworkSession.createSession,
      with: always(
        Array<MFAProvider>()
      )
    )

    try await FeaturesActor.execute {
      self.environment.pgp.decrypt = always(.success("decrypted"))
    }

    let feature: AccountSession = try await testInstance()

    _ =
      try await feature
      .authorize(validAccount, .adHoc("passphrase", "private key"))

    let result: String? =
      try? await feature
      .decryptMessage("encrypted message", nil)

    XCTAssertEqual(result, "decrypted")
  }

  func
    test_authorizationPromptPresentationPublisher_publishesCurrentAccount_whenDecryptMessage_fails_withSessionAuthorizationRequired()
    async throws
  {
    accountsDataStore.storeLastUsedAccount = always(Void())
    accountsDataStore.loadAccountPrivateKey = always(.success("PRIVATE KEY"))
    await features.use(accountsDataStore)
    await features.use(networkClient)
    await features.patch(
      \NetworkSession.createSession,
      with: always(
        Array<MFAProvider>()
      )
    )

    var currentTimestamp: Timestamp = 0
    try await FeaturesActor.execute {
      self.environment.time.timestamp = always(currentTimestamp)
    }

    let feature: AccountSession = try await testInstance()

    _ =
      try await feature
      .authorize(validAccount, .adHoc("passphrase", armoredPGPPrivateKey))

    var result: AuthorizationPromptRequest?
    feature
      .authorizationPromptPresentationPublisher()
      .sink { request in
        result = request
      }
      .store(in: cancellables)

    currentTimestamp = Timestamp(rawValue: 5 * 60)  // expired time

    _ =
      try? await feature
      .decryptMessage("message", nil)

    XCTAssertEqual(result?.account, validAccount)
  }

  func test_authorize_fails_whenSessionCreateFails() async throws {
    await features.use(accountsDataStore)
    await features.use(networkClient)
    await features.patch(
      \NetworkSession.createSession,
      with: alwaysThrow(
        MockIssue.error()
      )
    )

    let feature: AccountSession = try await testInstance()

    var result: Error?
    do {
      _ =
        try await feature
        .authorize(validAccount, .adHoc("passphrase", "private key"))
    }
    catch {
      result = error
    }

    XCTAssertError(result, matches: MockIssue.self)
  }

  func test_authorize_succeeds_whenSessionCreateSucceeds() async throws {
    accountsDataStore.storeLastUsedAccount = always(Void())
    await features.use(accountsDataStore)
    await features.use(networkClient)
    await features.patch(
      \NetworkSession.createSession,
      with: always(
        Array<MFAProvider>()
      )
    )

    let feature: AccountSession = try await testInstance()

    let result: Bool? =
      try? await feature
      .authorize(validAccount, .adHoc("passphrase", "private key"))

    XCTAssertNotNil(result)
  }

  func test_authorize_succeedsWithAuthorized_whenSessionCreateSucceedsWithNoMFAProviders() async throws {
    accountsDataStore.storeLastUsedAccount = always(Void())
    await features.use(accountsDataStore)
    await features.use(networkClient)
    await features.patch(
      \NetworkSession.createSession,
      with: always(
        Array<MFAProvider>()
      )
    )
    await features.patch(
      \NetworkSession.closeSession,
      with: always(
        Void()
      )
    )

    let feature: AccountSession = try await testInstance()

    var result: AccountSessionState?
    feature
      .statePublisher()
      .sink { state in
        result = state
      }
      .store(in: cancellables)

    _ =
      try await feature
      .authorize(validAccount, .adHoc("passphrase", "private key"))

    guard case .authorized = result
    else { return XCTFail() }
  }

  func test_authorize_succeedsWithAuthorizedMFARequired_whenSessionCreateSucceedsWithMFAProviders() async throws {
    accountsDataStore.storeLastUsedAccount = always(Void())
    await features.use(accountsDataStore)
    await features.use(networkClient)
    await features.patch(
      \NetworkSession.createSession,
      with: always(
        Array<MFAProvider>([.totp])
      )
    )

    let feature: AccountSession = try await testInstance()

    var result: AccountSessionState?
    feature
      .statePublisher()
      .sink { state in
        result = state
      }
      .store(in: cancellables)

    _ =
      try await feature
      .authorize(validAccount, .adHoc("passphrase", "private key"))

    XCTAssertEqual(result, .authorizedMFARequired(validAccount, providers: [.totp]))
  }

  func test_authorize_fails_whenPrivateKeyIsInaccessibleWhileUsingPassphrase() async throws {
    accountsDataStore.loadAccountPrivateKey = always(.failure(MockIssue.error()))
    await features.use(accountsDataStore)
    await features.use(networkClient)
    await features.patch(
      \NetworkSession.createSession,
      with: always(
        Array<MFAProvider>()
      )
    )

    let feature: AccountSession = try await testInstance()

    var result: Error?
    do {
      _ =
        try await feature
        .authorize(validAccount, .passphrase("passphrase"))
    }
    catch {
      result = error
    }

    XCTAssertError(result, matches: MockIssue.self)
  }

  func test_authorize_succeeds_whenPrivateKeyIsAccessibleWhileUsingPassphrase() async throws {
    accountsDataStore.storeLastUsedAccount = always(Void())
    accountsDataStore.loadAccountPrivateKey = always(.success(armoredPGPPrivateKey))
    await features.use(accountsDataStore)
    await features.use(networkClient)
    await features.patch(
      \NetworkSession.createSession,
      with: always(
        Array<MFAProvider>()
      )
    )

    let feature: AccountSession = try await testInstance()

    var result: Error?
    do {
      _ =
        try await feature
        .authorize(validAccount, .passphrase("passphrase"))
    }
    catch {
      result = error
    }

    XCTAssertNil(result)
  }

  func test_authorize_fails_whenPrivateKeyIsInaccessibleWhileUsingBiometrics() async throws {
    accountsDataStore.loadAccountPassphrase = always(.success("passphrase"))
    accountsDataStore.loadAccountPrivateKey = always(.failure(MockIssue.error()))
    await features.use(accountsDataStore)
    await features.use(networkClient)
    await features.patch(
      \NetworkSession.createSession,
      with: always(
        Array<MFAProvider>()
      )
    )

    let feature: AccountSession = try await testInstance()

    var result: Error?
    do {
      _ =
        try await feature
        .authorize(validAccount, .biometrics)
    }
    catch {
      result = error
    }

    XCTAssertError(result, matches: MockIssue.self)
  }

  func test_authorize_fails_whenPassphraseIsInaccessibleWhileUsingBiometrics() async throws {
    accountsDataStore.loadAccountPassphrase = always(.failure(MockIssue.error()))
    accountsDataStore.loadAccountPrivateKey = always(.success(armoredPGPPrivateKey))
    await features.use(accountsDataStore)
    await features.use(networkClient)
    await features.patch(
      \NetworkSession.createSession,
      with: always(
        Array<MFAProvider>()
      )
    )

    let feature: AccountSession = try await testInstance()

    var result: Error?
    do {
      _ =
        try await feature
        .authorize(validAccount, .biometrics)
    }
    catch {
      result = error
    }

    XCTAssertError(result, matches: MockIssue.self)
  }

  func test_authorize_succeeds_whenPrivateKeyAndPassphraseIsAccessibleWhileUsingBiometrics() async throws {
    accountsDataStore.storeLastUsedAccount = always(Void())
    accountsDataStore.loadAccountPassphrase = always(.success("passphrase"))
    accountsDataStore.loadAccountPrivateKey = always(.success(armoredPGPPrivateKey))
    await features.use(accountsDataStore)
    await features.use(networkClient)
    await features.patch(
      \NetworkSession.createSession,
      with: always(
        Array<MFAProvider>()
      )
    )

    let feature: AccountSession = try await testInstance()

    var result: Error?
    do {
      _ =
        try await feature
        .authorize(validAccount, .biometrics)
    }
    catch {
      result = error
    }

    XCTAssertNil(result)
  }

  func test_close_callsNetworkSessionClose() async throws {
    accountsDataStore.storeLastUsedAccount = always(Void())
    await features.use(accountsDataStore)
    await features.use(networkClient)
    await features.patch(
      \NetworkSession.createSession,
      with: always(
        Array<MFAProvider>()
      )
    )

    var result: Void?
    await features.patch(
      \NetworkSession.closeSession,
      with: {
        result = Void()
        return Void()
      }
    )

    let feature: AccountSession = try await testInstance()

    _ =
      try await feature
      .authorize(validAccount, .adHoc("passphrase", "private key"))

    feature
      .statePublisher()
      .dropFirst()
      .sink { _ in }
      .store(in: cancellables)

    await feature.close()

    XCTAssertNotNil(result)
  }

  func test_close_doesNothing_withoutActiveSession() async throws {
    accountsDataStore.loadLastUsedAccount = always(nil)
    await features.use(accountsDataStore)
    await features.use(networkClient)
    await features.usePlaceholder(for: NetworkSession.self)

    let feature: AccountSession = try await testInstance()

    var result: Void?
    feature
      .statePublisher()
      .dropFirst()
      .sink { session in
        result = Void()
      }
      .store(in: cancellables)

    await feature.close()

    XCTAssertNil(result)
  }

  func test_authorizationPromptPresentationPublisher_doesNotPublish_initially() async throws {
    await features.use(accountsDataStore)
    await features.use(networkClient)
    await features.usePlaceholder(for: NetworkSession.self)

    let feature: AccountSession = try await testInstance()

    var result: AuthorizationPromptRequest?
    feature
      .authorizationPromptPresentationPublisher()
      .sink { authorizationPromptRequest in
        result = authorizationPromptRequest
      }
      .store(in: cancellables)

    XCTAssertNil(result)
  }

  func test_authorizationPromptPresentationPublisher_doesNotPublish_whenRequestingExplicitlyWithoutActiveSession()
    async throws
  {
    await features.use(accountsDataStore)
    await features.use(networkClient)
    await features.usePlaceholder(for: NetworkSession.self)

    let feature: AccountSession = try await testInstance()

    var result: AuthorizationPromptRequest?
    feature
      .authorizationPromptPresentationPublisher()
      .sink { authorizationPromptRequest in
        result = authorizationPromptRequest
      }
      .store(in: cancellables)

    await feature.requestAuthorizationPrompt(.testMessage())

    XCTAssertNil(result)
  }

  func test_authorizationPromptPresentationPublisher_publishesRequest_whenRequestingExplicitly() async throws {
    accountsDataStore.storeLastUsedAccount = always(Void())
    await features.use(accountsDataStore)
    await features.use(networkClient)
    await features.patch(
      \NetworkSession.createSession,
      with: always(
        Array<MFAProvider>()
      )
    )

    let feature: AccountSession = try await testInstance()

    _ =
      try await feature
      .authorize(validAccount, .adHoc("passphrase", "private key"))

    var result: AuthorizationPromptRequest?
    feature
      .authorizationPromptPresentationPublisher()
      .sink { authorizationPromptRequest in
        result = authorizationPromptRequest
      }
      .store(in: cancellables)

    await feature.requestAuthorizationPrompt(.testMessage())

    // temporary wait for detached tasks
    try await Task.sleep(nanoseconds: 100 * NSEC_PER_MSEC)

    XCTAssertEqual(result?.account, validAccount)
    XCTAssertEqual(result?.message?.string(), "testLocalizationKey")
  }

  func test_authorize_succeeds_whenSwitchingSession() async throws {
    accountsDataStore.storeLastUsedAccount = always(Void())
    accountsDataStore.loadServerFingerprint = always(.success(.init(rawValue: "FINGERPRINT")))
    accountsDataStore.loadAccounts = always([validAccount, validAccountAlternative])
    await features.use(accountsDataStore)
    await features.use(networkClient)
    await features.patch(
      \NetworkSession.createSession,
      with: always(
        Array<MFAProvider>()
      )
    )
    await features.patch(
      \NetworkSession.closeSession,
      with: always(
        Void()
      )
    )

    let feature: AccountSession = try await testInstance()

    _ =
      try await feature
      .authorize(validAccountAlternative, .adHoc("passphrase", "private key"))

    let result: Bool? =
      try? await feature
      .authorize(validAccount, .adHoc("passphrase", "private key"))

    XCTAssertNotNil(result)
  }

  func test_authorize_doesNotClosePreviousSession_whenSwitchingToSameAccount() async throws {
    accountsDataStore.storeLastUsedAccount = always(Void())
    accountsDataStore.loadAccounts = always([validAccountAlternative])
    await features.use(accountsDataStore)
    await features.use(networkClient)
    await features.patch(
      \NetworkSession.createSession,
      with: always(
        Array<MFAProvider>()
      )
    )
    var result: Void?
    await features.patch(
      \NetworkSession.closeSession,
      with: {
        result = Void()
        return Void()
      }
    )

    let feature: AccountSession = try await testInstance()

    _ =
      try await feature
      .authorize(validAccount, .adHoc("passphrase", "private key"))

    _ =
      try await feature
      .authorize(validAccount, .adHoc("passphrase", "private key"))

    XCTAssertNil(result)
  }

  func test_authorizationPromptPresentationPublisher_publishesCurrentAccount_whenApplicationWillEnterForeground()
    async throws
  {
    accountsDataStore.storeLastUsedAccount = always(Void())
    await features.use(accountsDataStore)
    await features.use(networkClient)
    await features.patch(
      \NetworkSession.createSession,
      with: always(
        Array<MFAProvider>()
      )
    )

    let appLifeCycleSubject: PassthroughSubject<AppLifeCycle.Transition, Never> = .init()
    try await FeaturesActor.execute {
      self.environment.appLifeCycle.lifeCyclePublisher = always(appLifeCycleSubject.eraseToAnyPublisher())
    }

    let feature: AccountSession = try await testInstance()

    _ =
      try await feature
      .authorize(validAccount, .adHoc("passphrase", "private key"))

    var result: AuthorizationPromptRequest?
    feature
      .authorizationPromptPresentationPublisher()
      .sink { request in
        result = request
      }
      .store(in: cancellables)

    appLifeCycleSubject.send(.willEnterForeground)

    // temporary wait for detached tasks
    try await Task.sleep(nanoseconds: 100 * NSEC_PER_MSEC)

    XCTAssertEqual(result?.account, validAccount)
  }

  func test_mfaAuthorization_fails_withNoActiveSession() async throws {
    await features.use(accountsDataStore)
    await features.use(networkClient)
    await features.patch(
      \NetworkSession.createSession,
      with: always(
        Array<MFAProvider>()
      )
    )
    await features.patch(
      \NetworkSession.createMFAToken,
      with: always(
        Void()
      )
    )

    let feature: AccountSession = try await testInstance()

    var result: Error?
    do {
      try await feature
        .mfaAuthorize(.totp("OTP"), false)
    }
    catch {
      result = error
    }

    XCTAssertError(result, matches: SessionMissing.self)
  }

  func test_mfaAuthorization_isForwardedToNetworkSession() async throws {
    accountsDataStore.storeLastUsedAccount = always(Void())
    await features.use(accountsDataStore)
    await features.use(networkClient)
    await features.patch(
      \NetworkSession.createSession,
      with: always(
        Array<MFAProvider>()
      )
    )

    var result: (account: Account, authorization: AccountSession.MFAAuthorizationMethod, remember: Bool)?
    await features.patch(
      \NetworkSession.createMFAToken,
      with: { account, authorization, remember in
        result = (account, authorization, remember)
        return Void()
      }
    )

    let feature: AccountSession = try await testInstance()

    _ =
      try await feature
      .authorize(validAccount, .adHoc("passphrase", "private key"))

    try await feature
      .mfaAuthorize(.totp("OTP"), false)

    XCTAssertEqual(result?.account, validAccount)
    XCTAssertEqual(result?.authorization, .totp("OTP"))
    XCTAssertEqual(result?.remember, false)
  }

  func test_authorize_fails_whenSessionRefreshIsAvailableAndPassphraseIsNotValid() async throws {
    try await FeaturesActor.execute {
      self.environment.pgp.verifyPassphrase = always(.failure(MockIssue.error()))
    }
    accountsDataStore.storeLastUsedAccount = always(Void())
    accountsDataStore.loadAccounts = always([validAccount, validAccountAlternative])
    await features.use(accountsDataStore)
    await features.use(networkClient)
    await features.patch(
      \NetworkSession.createSession,
      with: always(
        Array<MFAProvider>()
      )
    )

    let feature: AccountSession = try await testInstance()

    var result: Error?
    do {
      _ =
        try await feature
        .authorize(validAccount, .adHoc("passphrase", "private key"))
    }
    catch {
      result = error
    }

    XCTAssertError(result, matches: MockIssue.self)
  }

  func test_authorize_fallbacksToCreateSession_whenSessionRefreshIsAvailableAndSessionRefreshFails() async throws {
    accountsDataStore.storeLastUsedAccount = always(Void())
    accountsDataStore.loadAccounts = always([validAccount, validAccountAlternative])
    await features.use(accountsDataStore)
    await features.use(networkClient)
    var result: Void?
    await features.patch(
      \NetworkSession.createSession,
      with: { _, _, _ in
        result = Void()
        return Array<MFAProvider>()
      }
    )
    await features.patch(
      \NetworkSession.refreshSessionIfNeeded,
      with: alwaysThrow(
        MockIssue.error()
      )
    )

    let feature: AccountSession = try await testInstance()

    _ =
      try await feature
      .authorize(validAccount, .adHoc("passphrase", "private key"))

    XCTAssertNotNil(result)
  }

  func test_authorize_doesSessionRefresh_whenSessionRefreshIsAvailableAndPassphraseIsValid() async throws {
    accountsDataStore.storeLastUsedAccount = always(Void())
    accountsDataStore.loadAccounts = always([validAccount, validAccountAlternative])
    await features.use(accountsDataStore)
    await features.use(networkClient)
    await features.patch(
      \NetworkSession.createSession,
      with: always(
        Array<MFAProvider>()
      )
    )

    var result: Void?
    await features.patch(
      \NetworkSession.refreshSessionIfNeeded,
      with: { _ in
        result = Void()
        return Void()
      }
    )

    let feature: AccountSession = try await testInstance()

    _ =
      try await feature
      .authorize(validAccount, .adHoc("passphrase", "private key"))

    _ =
      try await feature
      .authorize(validAccount, .adHoc("passphrase", "private key"))

    XCTAssertNotNil(result)
  }

  func test_authorize_succeeds_whenSessionRefreshSucceeds() async throws {
    accountsDataStore.storeLastUsedAccount = always(Void())
    accountsDataStore.loadAccounts = always([validAccount, validAccountAlternative])
    await features.use(accountsDataStore)
    await features.use(networkClient)
    await features.patch(
      \NetworkSession.createSession,
      with: always(
        Array<MFAProvider>()
      )
    )
    await features.patch(
      \NetworkSession.refreshSessionIfNeeded,
      with: always(
        Void()
      )
    )

    let feature: AccountSession = try await testInstance()

    let result: Bool? =
      try? await feature
      .authorize(validAccount, .adHoc("passphrase", "private key"))

    XCTAssertNotNil(result)
  }

  func test_storePassphraseWithBiometry_failsStore_withoutSession() async throws {
    accountsDataStore.loadAccounts = always([validAccount, validAccountAlternative])
    await features.use(accountsDataStore)
    await features.use(networkClient)
    await features.usePlaceholder(for: NetworkSession.self)

    let feature: AccountSession = try await testInstance()

    let result: Error?
    do {
      try await feature
        .storePassphraseWithBiometry(true)
      result = nil
    }
    catch {
      result = error
    }

    XCTAssertNotNil(result)
  }

  func test_storePassphraseWithBiometry_failsStore_whenPassphraseExpires() async throws {
    await features.use(accountsDataStore)
    await features.patch(
      \AccountsDataStore.storeLastUsedAccount,
      with: always(Void())
    )
    await features.patch(
      \AccountsDataStore.loadAccounts,
      with: always([validAccount, validAccountAlternative])
    )
    await features.use(networkClient)
    await features.patch(
      \NetworkSession.createSession,
      with: always(
        Array<MFAProvider>()
      )
    )

    var currentTimestamp: Timestamp = 0
    try await FeaturesActor.execute {
      self.environment.time.timestamp = always(currentTimestamp)
    }

    let feature: AccountSession = try await testInstance()

    _ =
      try await feature
      .authorize(validAccount, .adHoc("passphrase", "private key"))

    currentTimestamp = Timestamp(rawValue: 5 * 60)  // expired time

    let result: Error?
    do {
      try await feature
        .storePassphraseWithBiometry(true)
      result = nil
    }
    catch {
      result = error
    }

    XCTAssertNotNil(result)
  }

  func test_storePassphraseWithBiometry_failsStore_whenPassphraseStoreFails() async throws {
    await features.use(accountsDataStore)
    await features.patch(
      \AccountsDataStore.storeAccountPassphrase,
      with: always(.failure(MockIssue.error()))
    )
    await features.patch(
      \AccountsDataStore.storeLastUsedAccount,
      with: always(Void())
    )
    await features.patch(
      \AccountsDataStore.loadAccounts,
      with: always([validAccount, validAccountAlternative])
    )
    await features.use(networkClient)
    await features.patch(
      \NetworkSession.createSession,
      with: always(
        Array<MFAProvider>()
      )
    )

    let feature: AccountSession = try await testInstance()

    _ =
      try await feature
      .authorize(validAccount, .adHoc("passphrase", "private key"))

    let result: Error?
    do {
      try await feature
        .storePassphraseWithBiometry(true)
      result = nil
    }
    catch {
      result = error
    }

    XCTAssertNotNil(result)
  }

  func test_storePassphraseWithBiometry_succeedsStore_whenPassphraseStoreSucceeds() async throws {
    await features.use(accountsDataStore)
    await features.patch(
      \AccountsDataStore.storeAccountPassphrase,
      with: always(.success)
    )
    await features.patch(
      \AccountsDataStore.storeLastUsedAccount,
      with: always(Void())
    )
    await features.patch(
      \AccountsDataStore.loadAccounts,
      with: always([validAccount, validAccountAlternative])
    )
    await features.use(networkClient)
    await features.patch(
      \NetworkSession.createSession,
      with: always(
        Array<MFAProvider>()
      )
    )

    let feature: AccountSession = try await testInstance()

    _ =
      try await feature
      .authorize(validAccount, .adHoc("passphrase", "private key"))

    let result: Void? =
      try? await feature
      .storePassphraseWithBiometry(true)

    XCTAssertNotNil(result)
  }

  func test_storePassphraseWithBiometry_failsDelete_withoutSession() async throws {
    accountsDataStore.loadAccounts = always([validAccount, validAccountAlternative])
    await features.use(accountsDataStore)
    await features.use(networkClient)
    await features.usePlaceholder(for: NetworkSession.self)

    let feature: AccountSession = try await testInstance()

    let result: Error?
    do {
      try await feature
        .storePassphraseWithBiometry(false)
      result = nil
    }
    catch {
      result = error
    }

    XCTAssertNotNil(result)
  }

  func test_storePassphraseWithBiometry_failsDelete_whenPassphraseStoreFails() async throws {
    await features.use(accountsDataStore)
    await features.patch(
      \AccountsDataStore.deleteAccountPassphrase,
      with: always(.failure(MockIssue.error()))
    )
    await features.patch(
      \AccountsDataStore.storeLastUsedAccount,
      with: always(Void())
    )
    await features.patch(
      \AccountsDataStore.loadAccounts,
      with: always([validAccount, validAccountAlternative])
    )
    await features.use(networkClient)
    await features.patch(
      \NetworkSession.createSession,
      with: always(
        Array<MFAProvider>()
      )
    )

    let feature: AccountSession = try await testInstance()

    _ =
      try await feature
      .authorize(validAccount, .adHoc("passphrase", "private key"))

    let result: Error?
    do {
      try await feature
        .storePassphraseWithBiometry(false)
      result = nil
    }
    catch {
      result = error
    }

    XCTAssertNotNil(result)
  }

  func test_storePassphraseWithBiometry_succeedsDelete_whenPassphraseDeleteSucceeds() async throws {
    await features.use(accountsDataStore)
    await features.patch(
      \AccountsDataStore.deleteAccountPassphrase,
      with: always(.success)
    )
    await features.patch(
      \AccountsDataStore.storeLastUsedAccount,
      with: always(Void())
    )
    await features.patch(
      \AccountsDataStore.loadAccounts,
      with: always([validAccount, validAccountAlternative])
    )
    await features.use(networkClient)
    await features.patch(
      \NetworkSession.createSession,
      with: always(
        Array<MFAProvider>()
      )
    )

    let feature: AccountSession = try await testInstance()

    _ =
      try await feature
      .authorize(validAccount, .adHoc("passphrase", "private key"))

    let result: Void? =
      try? await feature
      .storePassphraseWithBiometry(false)

    XCTAssertNotNil(result)
  }

  func test_encryptAndSignMessage_fails_withoutSession() async throws {
    await features.use(accountsDataStore)
    await features.patch(
      \AccountsDataStore.storeLastUsedAccount,
      with: always(Void())
    )
    await features.patch(
      \AccountsDataStore.loadAccounts,
      with: always([validAccount, validAccountAlternative])
    )
    await features.use(networkClient)
    await features.usePlaceholder(for: NetworkSession.self)

    let feature: AccountSession = try await testInstance()

    var result: Error?
    do {
      _ =
        try await feature
        .encryptAndSignMessage("message", "public key")
        .asAsyncValue()
    }
    catch {
      result = error
    }

    XCTAssertError(result, matches: SessionMissing.self)
  }

  func test_encryptAndSignMessage_fails_whenLoadingPrivateKeyFails() async throws {
    await features.use(accountsDataStore)
    await features.patch(
      \AccountsDataStore.loadAccountPrivateKey,
      with: always(.failure(MockIssue.error()))
    )
    await features.patch(
      \AccountsDataStore.storeLastUsedAccount,
      with: always(Void())
    )
    await features.patch(
      \AccountsDataStore.loadAccounts,
      with: always([validAccount, validAccountAlternative])
    )
    await features.use(networkClient)
    await features.patch(
      \NetworkSession.createSession,
      with: always(
        Array<MFAProvider>()
      )
    )

    let feature: AccountSession = try await testInstance()

    _ =
      try await feature
      .authorize(validAccount, .adHoc("passphrase", "private key"))

    var result: Error?
    do {
      _ =
        try await feature
        .encryptAndSignMessage("message", "public key")
        .asAsyncValue()
    }
    catch {
      result = error
    }

    XCTAssertError(result, matches: MockIssue.self)
  }

  func test_encryptAndSignMessage_fails_whenEncryptAndSignFails() async throws {
    await features.use(accountsDataStore)
    await features.patch(
      \AccountsDataStore.loadAccountPrivateKey,
      with: always(.success("private key"))
    )
    await features.patch(
      \AccountsDataStore.storeLastUsedAccount,
      with: always(Void())
    )
    await features.patch(
      \AccountsDataStore.loadAccounts,
      with: always([validAccount, validAccountAlternative])
    )
    await features.use(networkClient)
    await features.patch(
      \NetworkSession.createSession,
      with: always(
        Array<MFAProvider>()
      )
    )
    try await FeaturesActor.execute {
      self.environment.pgp.encryptAndSign = always(.failure(MockIssue.error()))
    }

    let feature: AccountSession = try await testInstance()

    _ =
      try await feature
      .authorize(validAccount, .adHoc("passphrase", "private key"))

    var result: Error?
    do {
      _ =
        try await feature
        .encryptAndSignMessage("message", "public key")
        .asAsyncValue()
    }
    catch {
      result = error
    }

    XCTAssertError(result, matches: MockIssue.self)
  }

  func test_encryptAndSignMessage_succeeds_withHappyPath() async throws {
    await features.use(accountsDataStore)
    await features.patch(
      \AccountsDataStore.loadAccountPrivateKey,
      with: always(.success("private key"))
    )
    await features.patch(
      \AccountsDataStore.storeLastUsedAccount,
      with: always(Void())
    )
    await features.patch(
      \AccountsDataStore.loadAccounts,
      with: always([validAccount, validAccountAlternative])
    )
    await features.use(networkClient)
    await features.patch(
      \NetworkSession.createSession,
      with: always(
        Array<MFAProvider>()
      )
    )
    try await FeaturesActor.execute {
      self.environment.pgp.encryptAndSign = always(.success("encrypted"))
    }

    let feature: AccountSession = try await testInstance()

    _ =
      try await feature
      .authorize(validAccount, .adHoc("passphrase", "private key"))

    let result =
      try? await feature
      .encryptAndSignMessage("message", "public key")
      .asAsyncValue()

    XCTAssertNotNil(result)
  }

  func test_databaseKey_isNone_withoutSession() async throws {
    await features.use(accountsDataStore)
    await features.patch(
      \AccountsDataStore.storeLastUsedAccount,
      with: always(Void())
    )
    await features.patch(
      \AccountsDataStore.loadAccounts,
      with: always([validAccount, validAccountAlternative])
    )
    await features.use(networkClient)
    await features.usePlaceholder(for: NetworkSession.self)

    let feature: AccountSession = try await testInstance()

    let result: String? = try? await feature.databaseKey()

    XCTAssertNil(result)
  }

  func test_databaseKey_isNone_whenPassphraseCacheExpires() async throws {
    await features.use(accountsDataStore)
    await features.patch(
      \AccountsDataStore.storeLastUsedAccount,
      with: always(Void())
    )
    await features.patch(
      \AccountsDataStore.loadAccounts,
      with: always([validAccount, validAccountAlternative])
    )
    await features.use(networkClient)
    await features.patch(
      \NetworkSession.createSession,
      with: always(
        Array<MFAProvider>()
      )
    )

    var currentTimestamp: Timestamp = 0
    try await FeaturesActor.execute {
      self.environment.time.timestamp = always(currentTimestamp)
    }

    let feature: AccountSession = try await testInstance()

    _ =
      try await feature
      .authorize(validAccount, .adHoc("passphrase", "private key"))

    currentTimestamp = Timestamp(rawValue: 5 * 60)  // expired time

    let result: String? = try? await feature.databaseKey()

    XCTAssertNil(result)
  }

  func test_databaseKey_isAvailable_withValidSession() async throws {
    await features.use(accountsDataStore)
    await features.patch(
      \AccountsDataStore.storeLastUsedAccount,
      with: always(Void())
    )
    await features.patch(
      \AccountsDataStore.loadAccounts,
      with: always([validAccount, validAccountAlternative])
    )
    await features.use(networkClient)
    await features.patch(
      \NetworkSession.createSession,
      with: always(
        Array<MFAProvider>()
      )
    )

    let feature: AccountSession = try await testInstance()

    _ =
      try await feature
      .authorize(validAccount, .adHoc("passphrase", "private key"))

    let result: String = try await feature.databaseKey()

    XCTAssertNotNil(result)
  }
}

private let validAccount: Account = .init(
  localID: .init(rawValue: UUID.test.uuidString),
  domain: "https://passbolt.dev",
  userID: "USER_ID",
  fingerprint: "FINGERPRINT"
)

private let validAccountAlternative: Account = .init(
  localID: .init(rawValue: UUID.testAlt.uuidString),
  domain: "https://alt.passbolt.dev",
  userID: "USER_ID_ALT",
  fingerprint: "FINGERPRINT_ALT"
)

private let validAccountAlternativeWithIDCollision: Account = .init(
  localID: .init(rawValue: UUID.testAlt.uuidString),
  domain: "https://alt.passbolt.dev",
  userID: "USER_ID",  // colliding ID
  fingerprint: "FINGERPRINT_ALT"
)

private let validSessionTokens: NetworkSessionState = .init(
  account: validAccount,
  accessToken: validJWTToken,
  refreshToken: "refresh_token"
)

private let armoredPGPPrivateKey: ArmoredPGPPrivateKey = "private_key"

private let validJWTToken: JWT = try! .from(
  rawValue: """
    eyJhbGciOiJSUzI1NiIsInR5cCI6IkpXVCJ9.eyJhdWQiOiJpb3MiLCJleHAiOjE1MTYyMzkwMjIsImlzcyI6IlBhc3Nib2x0Iiwic3ViIjoiMTIzNDU2Nzg5MCJ9.mooyAR9uQ1F6sHMaA3Ya4bRKPazydqowEsgm-Sbr7RmED36CShWdF3a-FdxyezcgI85FPyF0Df1_AhTOknb0sPs-Yur1Oa0XwsDsXfpw-xJsnlx9JCylp6C6rm_rypJL1E8t_63QCS_k5rv7hpDc8ctjLW8mXoFXXP_bDkSezyPVUaRDvjLgaDm01Ocin112h1FvQZTittQhhdL-KU5C1HjCJn03zNmH46TihstdK7PZ7mRz2YgIpm9P-5JzYYmSV3eP70_0dVCC_lv0N3VJFLKVB9FP99R4jChJv5DEilEgMwi_73YsP3Z55rGDaoyjhj661rDteq-42LMXcvSmOg
    """
)
.get()
