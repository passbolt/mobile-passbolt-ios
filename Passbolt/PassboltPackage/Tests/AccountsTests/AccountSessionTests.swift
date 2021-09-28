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


import Commons
import Crypto
import Features
import NetworkClient
import TestExtensions
import XCTest

@testable import Accounts

// swift-format-ignore: AlwaysUseLowerCamelCase, NeverUseImplicitlyUnwrappedOptionals
final class AccountSessionTests: TestCase {

  var accountsDataStore: AccountsDataStore!
  var passphraseCache: PassphraseCache!
  var networkClient: NetworkClient!
  var networkSession: NetworkSession!

  override func setUp() {
    super.setUp()
    accountsDataStore = .placeholder
    accountsDataStore.loadLastUsedAccount = always(validAccount)
    passphraseCache = .placeholder
    networkClient = .placeholder
    networkClient.setAuthorizationRequest = always(Void())
    networkClient.setMFARequest = always(Void())
    networkClient.updateSession = always(Void())
    networkSession = .placeholder
    environment.appLifeCycle.lifeCyclePublisher = always(Empty().eraseToAnyPublisher())
    environment.time.timestamp = always(0)
  }

  override func tearDown() {
    accountsDataStore = nil
    passphraseCache = nil
    networkClient = nil
    networkSession = nil
    super.tearDown()
  }

  func test_statePublisher_publishesNoneState_initially() {
    accountsDataStore.loadLastUsedAccount = always(.none)
    features.use(accountsDataStore)
    features.use(passphraseCache)
    features.use(networkClient)
    features.use(networkSession)

    let feature: AccountSession = testInstance()

    var result: AccountSession.State?
    feature
      .statePublisher()
      .sink { state in
        result = state
      }
      .store(in: cancellables)

    XCTAssertEqual(result, .some(.none(lastUsed: .none)))
  }

  func test_statePublisher_publishesLastUsedAccount_initially() {
    accountsDataStore.loadLastUsedAccount = always(validAccount)
    features.use(accountsDataStore)
    features.use(passphraseCache)
    features.use(networkClient)
    features.use(networkSession)

    let feature: AccountSession = testInstance()

    var result: Account?
    feature
      .statePublisher()
      .sink { state in
        guard case let .none(lastUsed) = state
        else { return }
        result = lastUsed
      }
      .store(in: cancellables)

    XCTAssertEqual(result, validAccount)
  }

  func test_statePublisher_publishesAuthorized_whenAuthorizationSucceeds() {
    accountsDataStore.storeLastUsedAccount = always(Void())
    features.use(accountsDataStore)
    passphraseCache.store = always(Void())
    passphraseCache.passphrasePublisher = always(CurrentValueSubject<Passphrase?, Never>("passphrase").eraseToAnyPublisher())
    features.use(passphraseCache)
    features.use(networkClient)
    networkSession.createSession = always(
      Just(Array<MFAProvider>())
        .setFailureType(to: TheError.self)
        .eraseToAnyPublisher()
    )
    features.use(networkSession)

    let feature: AccountSession = testInstance()

    var result: Account?
    feature
      .statePublisher()
      .sink { state in
        guard case let .authorized(account) = state
        else { return }
        result = account
      }
      .store(in: cancellables)


    feature
      .authorize(validAccount, .adHoc("passphrase", "private key"))
      .sinkDrop()
      .store(in: cancellables)

    XCTAssertEqual(result, validAccount)
  }

  func test_statePublisher_publishesNone_whenClosingSession() {
    accountsDataStore.storeLastUsedAccount = always(Void())
    features.use(accountsDataStore)
    passphraseCache.store = always(Void())
    passphraseCache.passphrasePublisher = always(CurrentValueSubject<Passphrase?, Never>("passphrase").eraseToAnyPublisher())
    passphraseCache.clear = always(Void())
    features.use(passphraseCache)
    features.use(networkClient)
    networkSession.createSession = always(
      Just(Array<MFAProvider>())
        .setFailureType(to: TheError.self)
        .eraseToAnyPublisher()
    )
    networkSession.closeSession = always(
      Just(Void())
        .setFailureType(to: TheError.self)
        .eraseToAnyPublisher()
    )
    features.use(networkSession)

    let feature: AccountSession = testInstance()

    feature
      .authorize(validAccount, .adHoc("passphrase", "private key"))
      .sinkDrop()
      .store(in: cancellables)

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

    feature.close()

    XCTAssertNotNil(result)
  }

  func test_statePublisher_publishesNoLastUsedAccount_whenClosingSession() {
    accountsDataStore.storeLastUsedAccount = always(Void())
    features.use(accountsDataStore)
    passphraseCache.store = always(Void())
    passphraseCache.passphrasePublisher = always(CurrentValueSubject<Passphrase?, Never>("passphrase").eraseToAnyPublisher())
    passphraseCache.clear = always(Void())
    features.use(passphraseCache)
    features.use(networkClient)
    networkSession.createSession = always(
      Just(Array<MFAProvider>())
        .setFailureType(to: TheError.self)
        .eraseToAnyPublisher()
    )
    networkSession.closeSession = always(
      Just(Void())
        .setFailureType(to: TheError.self)
        .eraseToAnyPublisher()
    )
    features.use(networkSession)

    let feature: AccountSession = testInstance()

    feature
      .authorize(validAccount, .adHoc("passphrase", "private key"))
      .sinkDrop()
      .store(in: cancellables)

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

    feature.close()

    XCTAssertNil(result)
  }

  func test_statePublisher_publishesAuthorizationRequired_whenPassphraseCacheIsCleared() {
    accountsDataStore.storeLastUsedAccount = always(Void())
    features.use(accountsDataStore)
    passphraseCache.store = always(Void())
    passphraseCache.clear = always(Void())
    let passphraseCacheSubject: CurrentValueSubject<Passphrase?, Never> = .init("passphrase")
    passphraseCache.passphrasePublisher = always(passphraseCacheSubject.eraseToAnyPublisher())
    features.use(passphraseCache)
    features.use(networkClient)
    networkSession.createSession = always(
      Just(Array<MFAProvider>())
        .setFailureType(to: TheError.self)
        .eraseToAnyPublisher()
    )
    networkSession.closeSession = always(
      Just(Void())
        .setFailureType(to: TheError.self)
        .eraseToAnyPublisher()
    )
    features.use(networkSession)

    let feature: AccountSession = testInstance()

    feature
      .authorize(validAccount, .adHoc("passphrase", "private key"))
      .sinkDrop()
      .store(in: cancellables)

    var result: Account?
    feature
      .statePublisher()
      .sink { state in
        guard case let .authorizationRequired(account) = state
        else { return }
        result = account
      }
      .store(in: cancellables)

    passphraseCacheSubject.send(nil)

    XCTAssertEqual(result, validAccount)
  }

  func test_decryptMessage_fails_withoutActiveSession() {
    features.use(accountsDataStore)
    features.use(passphraseCache)
    features.use(networkClient)
    features.use(networkSession)

    let feature: AccountSession = testInstance()

    var result: TheError?
    feature
      .decryptMessage("encrypted message", nil)
      .sink(
        receiveCompletion: { completion in
          guard case let .failure(error) = completion
          else { return }
          result = error
        },
        receiveValue: { _ in }
      )
      .store(in: cancellables)

    XCTAssertEqual(result?.identifier, .authorizationRequired)
  }

  func test_decryptMessage_fails_whenLoadingAccountPrivateKeyFails() {
    accountsDataStore.storeLastUsedAccount = always(Void())
    accountsDataStore.loadAccountPrivateKey = always(.failure(.testError()))
    features.use(accountsDataStore)
    passphraseCache.store = always(Void())
    passphraseCache.passphrasePublisher = always(
      CurrentValueSubject<Passphrase?, Never>("passphrase")
        .eraseToAnyPublisher()
    )
    features.use(passphraseCache)
    features.use(networkClient)
    networkSession.createSession = always(
      Just(Array<MFAProvider>())
        .setFailureType(to: TheError.self)
        .eraseToAnyPublisher()
    )
    features.use(networkSession)

    let feature: AccountSession = testInstance()

    feature
      .authorize(validAccount, .adHoc("passphrase", "private key"))
      .sinkDrop()
      .store(in: cancellables)

    var result: TheError?
    feature
      .decryptMessage("encrypted message", nil)
      .sink(
        receiveCompletion: { completion in
          guard case let .failure(error) = completion
          else { return }
          result = error
        },
        receiveValue: { _ in }
      )
      .store(in: cancellables)

    XCTAssertEqual(result?.identifier, .testError)
  }

  func test_decryptMessage_fails_whenDecryptionFails() {
    accountsDataStore.storeLastUsedAccount = always(Void())
    accountsDataStore.loadAccountPrivateKey = always(.success(armoredPGPPrivateKey))
    features.use(accountsDataStore)
    passphraseCache.store = always(Void())
    passphraseCache.passphrasePublisher = always(
      CurrentValueSubject<Passphrase?, Never>("passphrase")
        .eraseToAnyPublisher()
    )
    features.use(passphraseCache)
    features.use(networkClient)
    networkSession.createSession = always(
      Just(Array<MFAProvider>())
        .setFailureType(to: TheError.self)
        .eraseToAnyPublisher()
    )
    features.use(networkSession)

    environment.pgp.decrypt = always(.failure(.testError()))

    let feature: AccountSession = testInstance()

    feature
      .authorize(validAccount, .adHoc("passphrase", "private key"))
      .sinkDrop()
      .store(in: cancellables)

    var result: TheError?
    feature
      .decryptMessage("encrypted message", nil)
      .sink(
        receiveCompletion: { completion in
          guard case let .failure(error) = completion
          else { return }
          result = error
        },
        receiveValue: { _ in }
      )
      .store(in: cancellables)

    XCTAssertEqual(result?.identifier, .testError)
  }

  func test_decryptMessage_succeeds_whenDecryptionSucceeds() {
    accountsDataStore.storeLastUsedAccount = always(Void())
    accountsDataStore.loadAccountPrivateKey = always(.success(armoredPGPPrivateKey))
    features.use(accountsDataStore)
    passphraseCache.store = always(Void())
    passphraseCache.passphrasePublisher = always(
      CurrentValueSubject<Passphrase?, Never>("passphrase")
        .eraseToAnyPublisher()
    )
    features.use(passphraseCache)
    features.use(networkClient)
    networkSession.createSession = always(
      Just(Array<MFAProvider>())
        .setFailureType(to: TheError.self)
        .eraseToAnyPublisher()
    )
    features.use(networkSession)

    environment.pgp.decrypt = always(.success("decrypted"))

    let feature: AccountSession = testInstance()

    feature
      .authorize(validAccount, .adHoc("passphrase", "private key"))
      .sinkDrop()
      .store(in: cancellables)

    var result: String?
    feature
      .decryptMessage("encrypted message", nil)
      .sink(
        receiveCompletion: { _ in },
        receiveValue: { decrypted in
          result = decrypted
        }
      )
      .store(in: cancellables)

    XCTAssertEqual(result, "decrypted")
  }

  func test_authorizationPromptPresentationPublisher_publishesCurrentAccount_whenDecryptMessage_fails_withSessionAuthorizationRequired() {
    accountsDataStore.storeLastUsedAccount = always(Void())
    features.use(accountsDataStore)
    passphraseCache.store = always(Void())
    let passphraseCacheSubject: CurrentValueSubject<Passphrase?, Never> = .init("passphrase")
    passphraseCache.passphrasePublisher = always(passphraseCacheSubject.eraseToAnyPublisher())
    features.use(passphraseCache)
    features.use(networkClient)
    networkSession.createSession = always(
      Just(Array<MFAProvider>())
        .setFailureType(to: TheError.self)
        .eraseToAnyPublisher()
    )
    features.use(networkSession)

    let feature: AccountSession = testInstance()

    feature
      .authorize(validAccount, .adHoc("passphrase", armoredPGPPrivateKey))
      .sinkDrop()
      .store(in: cancellables)

    var result: AuthorizationPromptRequest?
    feature
      .authorizationPromptPresentationPublisher()
      .sink { request in
        result = request
      }
      .store(in: cancellables)

    passphraseCacheSubject.send(nil)

    feature
      .decryptMessage("message", nil)
      .sink(
        receiveCompletion: { _ in },
        receiveValue: { _ in }
      )
      .store(in: cancellables)

    XCTAssertEqual(result?.account, validAccount)
  }

  func test_authorize_fails_whenSessionCreateFails() {
    features.use(accountsDataStore)
    features.use(passphraseCache)
    features.use(networkClient)
    networkSession.createSession = always(Fail(error: .testError()).eraseToAnyPublisher())
    features.use(networkSession)

    let feature: AccountSession = testInstance()

    var resultError: TheError?
    feature
      .authorize(validAccount, .adHoc("passphrase", "private key"))
      .sink(
        receiveCompletion: { completion in
          guard case let .failure(error) = completion
          else { return }
          resultError = error
        },
        receiveValue: { _ in }
      )
      .store(in: cancellables)

    XCTAssertEqual(resultError?.identifier, .testError)
  }

  func test_authorize_succeeds_whenSessionCreateSucceeds() {
    accountsDataStore.storeLastUsedAccount = always(Void())
    features.use(accountsDataStore)
    passphraseCache.store = always(Void())
    passphraseCache.passphrasePublisher = always(CurrentValueSubject<Passphrase?, Never>("passphrase").eraseToAnyPublisher())
    features.use(passphraseCache)
    features.use(networkClient)
    networkSession.createSession = always(
      Just(Array<MFAProvider>())
        .setFailureType(to: TheError.self)
        .eraseToAnyPublisher()
    )
    features.use(networkSession)

    let feature: AccountSession = testInstance()

    var resultError: TheError?
    var result: Void?
    feature
      .authorize(validAccount, .adHoc("passphrase", "private key"))
      .sink(
        receiveCompletion: { completion in
          guard case let .failure(error) = completion
          else { return }
          resultError = error
        },
        receiveValue: { _ in
          result = Void()
        }
      )
      .store(in: cancellables)

    XCTAssertNil(resultError)
    XCTAssertNotNil(result)
  }

  func test_authorize_succeedsWithAuthorized_whenSessionCreateSucceedsWithNoMFAProviders() {
    accountsDataStore.storeLastUsedAccount = always(Void())
    features.use(accountsDataStore)
    passphraseCache.store = always(Void())
    passphraseCache.passphrasePublisher = always(CurrentValueSubject<Passphrase?, Never>("passphrase").eraseToAnyPublisher())
    features.use(passphraseCache)
    features.use(networkClient)
    networkSession.createSession = always(
      Just(Array<MFAProvider>())
        .setFailureType(to: TheError.self)
        .eraseToAnyPublisher()
    )
    features.use(networkSession)

    let feature: AccountSession = testInstance()

    var result: AccountSession.State?
    feature
      .statePublisher()
      .sink { state in
        result = state
      }
      .store(in: cancellables)

    feature
      .authorize(validAccount, .adHoc("passphrase", "private key"))
      .sinkDrop()
      .store(in: cancellables)

    guard case .authorized = result
    else { return XCTFail() }
  }

  func test_authorize_succeedsWithAuthorizedMFARequired_whenSessionCreateSucceedsWithMFAProviders() {
    accountsDataStore.storeLastUsedAccount = always(Void())
    features.use(accountsDataStore)
    passphraseCache.store = always(Void())
    passphraseCache.passphrasePublisher = always(CurrentValueSubject<Passphrase?, Never>("passphrase").eraseToAnyPublisher())
    features.use(passphraseCache)
    features.use(networkClient)
    networkSession.createSession = always(
      Just(Array<MFAProvider>([.totp]))
        .setFailureType(to: TheError.self)
        .eraseToAnyPublisher()
    )
    features.use(networkSession)

    let feature: AccountSession = testInstance()

    var result: AccountSession.State?
    feature
      .statePublisher()
      .sink { state in
        result = state
      }
      .store(in: cancellables)

    feature
      .authorize(validAccount, .adHoc("passphrase", "private key"))
      .sinkDrop()
      .store(in: cancellables)

    XCTAssertEqual(result, .authorizedMFARequired(validAccount, providers: [.totp]))
  }

  func test_authorize_fails_whenPrivateKeyIsInaccessibleWhileUsingPassphrase() {
    accountsDataStore.loadAccountPrivateKey = always(.failure(.testError()))
    features.use(accountsDataStore)
    passphraseCache.store = always(Void())
    features.use(passphraseCache)
    features.use(networkClient)
    networkSession.createSession = always(
      Just(Array<MFAProvider>())
        .setFailureType(to: TheError.self)
        .eraseToAnyPublisher()
    )
    features.use(networkSession)

    let feature: AccountSession = testInstance()

    var result: TheError?
    feature
      .authorize(validAccount, .passphrase("passphrase"))
      .sink(
        receiveCompletion: { completion in
          guard case let .failure(error) = completion
          else { return }
          result = error
        },
        receiveValue: { _ in }
      )
      .store(in: cancellables)

    XCTAssertEqual(result?.identifier, .testError)
  }

  func test_authorize_succeeds_whenPrivateKeyIsAccessibleWhileUsingPassphrase() {
    accountsDataStore.storeLastUsedAccount = always(Void())
    accountsDataStore.loadAccountPrivateKey = always(.success(armoredPGPPrivateKey))
    features.use(accountsDataStore)
    passphraseCache.store = always(Void())
    passphraseCache.passphrasePublisher = always(CurrentValueSubject<Passphrase?, Never>("passphrase").eraseToAnyPublisher())
    features.use(passphraseCache)
    features.use(networkClient)
    networkSession.createSession = always(
      Just(Array<MFAProvider>())
        .setFailureType(to: TheError.self)
        .eraseToAnyPublisher()
    )
    features.use(networkSession)

    let feature: AccountSession = testInstance()

    var result: TheError?
    feature
      .authorize(validAccount, .passphrase("passphrase"))
      .sink(
        receiveCompletion: { completion in
          guard case let .failure(error) = completion
          else { return }
          result = error
        },
        receiveValue: { _ in }
      )
      .store(in: cancellables)

    XCTAssertNil(result)
  }

  func test_authorize_fails_whenPrivateKeyIsInaccessibleWhileUsingBiometrics() {
    accountsDataStore.loadAccountPassphrase = always(.success("passphrase"))
    accountsDataStore.loadAccountPrivateKey = always(.failure(.testError()))
    features.use(accountsDataStore)
    passphraseCache.store = always(Void())
    features.use(passphraseCache)
    features.use(networkClient)
    networkSession.createSession = always(
      Just(Array<MFAProvider>())
        .setFailureType(to: TheError.self)
        .eraseToAnyPublisher()
    )
    features.use(networkSession)

    let feature: AccountSession = testInstance()

    var result: TheError?
    feature
      .authorize(validAccount, .biometrics)
      .sink(
        receiveCompletion: { completion in
          guard case let .failure(error) = completion
          else { return }
          result = error
        },
        receiveValue: { _ in }
      )
      .store(in: cancellables)

    XCTAssertEqual(result?.identifier, .testError)
  }

  func test_authorize_fails_whenPassphraseIsInaccessibleWhileUsingBiometrics() {
    accountsDataStore.loadAccountPassphrase = always(.failure(.testError()))
    accountsDataStore.loadAccountPrivateKey = always(.success(armoredPGPPrivateKey))
    features.use(accountsDataStore)
    passphraseCache.store = always(Void())
    features.use(passphraseCache)
    features.use(networkClient)
    networkSession.createSession = always(
      Just(Array<MFAProvider>())
        .setFailureType(to: TheError.self)
        .eraseToAnyPublisher()
    )
    features.use(networkSession)

    let feature: AccountSession = testInstance()

    var result: TheError?
    feature
      .authorize(validAccount, .biometrics)
      .sink(
        receiveCompletion: { completion in
          guard case let .failure(error) = completion
          else { return }
          result = error
        },
        receiveValue: { _ in }
      )
      .store(in: cancellables)

    XCTAssertEqual(result?.identifier, .testError)
  }

  func test_authorize_succeeds_whenPrivateKeyAndPassphraseIsAccessibleWhileUsingBiometrics() {
    accountsDataStore.storeLastUsedAccount = always(Void())
    accountsDataStore.loadAccountPassphrase = always(.success("passphrase"))
    accountsDataStore.loadAccountPrivateKey = always(.success(armoredPGPPrivateKey))
    features.use(accountsDataStore)
    passphraseCache.store = always(Void())
    passphraseCache.passphrasePublisher = always(CurrentValueSubject<Passphrase?, Never>("passphrase").eraseToAnyPublisher())
    features.use(passphraseCache)
    features.use(networkClient)
    networkSession.createSession = always(
      Just(Array<MFAProvider>())
        .setFailureType(to: TheError.self)
        .eraseToAnyPublisher()
    )
    features.use(networkSession)

    let feature: AccountSession = testInstance()

    var result: TheError?
    feature
      .authorize(validAccount, .biometrics)
      .sink(
        receiveCompletion: { completion in
          guard case let .failure(error) = completion
          else { return }
          result = error
        },
        receiveValue: { _ in }
      )
      .store(in: cancellables)

    XCTAssertNil(result)
  }

  func test_close_callsNetworkSessionClose() {
    accountsDataStore.storeLastUsedAccount = always(Void())
    features.use(accountsDataStore)
    passphraseCache.store = always(Void())
    passphraseCache.passphrasePublisher = always(CurrentValueSubject<Passphrase?, Never>("passphrase").eraseToAnyPublisher())
    passphraseCache.clear = always(Void())
    features.use(passphraseCache)
    features.use(networkClient)
    networkSession.createSession = always(
      Just(Array<MFAProvider>())
        .setFailureType(to: TheError.self)
        .eraseToAnyPublisher()
    )
    var result: Void?
    networkSession.closeSession = {
      result = Void()
      return Just(Void())
        .setFailureType(to: TheError.self)
        .eraseToAnyPublisher()
    }
    features.use(networkSession)

    let feature: AccountSession = testInstance()

    feature
      .authorize(validAccount, .adHoc("passphrase", "private key"))
      .sinkDrop()
      .store(in: cancellables)

    feature
      .statePublisher()
      .dropFirst()
      .sink { _ in }
      .store(in: cancellables)

    feature.close()

    XCTAssertNotNil(result)
  }

  func test_close_doesNothing_withoutActiveSession() {
    accountsDataStore.loadLastUsedAccount = always(nil)
    features.use(accountsDataStore)
    passphraseCache.clear = always(Void())
    features.use(passphraseCache)
    features.use(networkClient)
    features.use(networkSession)

    let feature: AccountSession = testInstance()

    var result: Void?
    feature
      .statePublisher()
      .dropFirst()
      .sink { session in
        result = Void()
      }
      .store(in: cancellables)

    feature.close()

    XCTAssertNil(result)
  }

  func test_authorizationPromptPresentationPublisher_doesNotPublish_initially() {
    features.use(accountsDataStore)
    features.use(passphraseCache)
    features.use(networkClient)
    features.use(networkSession)

    let feature: AccountSession = testInstance()

    var result: AuthorizationPromptRequest?
    feature
      .authorizationPromptPresentationPublisher()
      .sink { authorizationPromptRequest in
        result = authorizationPromptRequest
      }
      .store(in: cancellables)

    XCTAssertNil(result)
  }

  func test_authorizationPromptPresentationPublisher_doesNotPublish_whenRequestingExplicitlyWithoutActiveSession() {
    features.use(accountsDataStore)
    features.use(passphraseCache)
    features.use(networkClient)
    features.use(networkSession)

    let feature: AccountSession = testInstance()

    var result: AuthorizationPromptRequest?
    feature
      .authorizationPromptPresentationPublisher()
      .sink { authorizationPromptRequest in
        result = authorizationPromptRequest
      }
      .store(in: cancellables)

    feature.requestAuthorizationPrompt(.init(key: "message", bundle: .main))

    XCTAssertNil(result)
  }

  func test_authorizationPromptPresentationPublisher_publishesRequest_whenRequestingExplicitly() {
    accountsDataStore.storeLastUsedAccount = always(Void())
    features.use(accountsDataStore)
    passphraseCache.store = always(Void())
    passphraseCache.passphrasePublisher = always(CurrentValueSubject<Passphrase?, Never>("passphrase").eraseToAnyPublisher())
    passphraseCache.clear = always(Void())
    features.use(passphraseCache)
    features.use(networkClient)
    networkSession.createSession = always(
      Just(Array<MFAProvider>())
        .setFailureType(to: TheError.self)
        .eraseToAnyPublisher()
    )
    features.use(networkSession)

    let feature: AccountSession = testInstance()

    feature
      .authorize(validAccount, .adHoc("passphrase", "private key"))
      .sinkDrop()
      .store(in: cancellables)

    var result: AuthorizationPromptRequest?
    feature
      .authorizationPromptPresentationPublisher()
      .sink { authorizationPromptRequest in
        result = authorizationPromptRequest
      }
      .store(in: cancellables)

    feature.requestAuthorizationPrompt(.init(key: "message", bundle: .main))

    XCTAssertEqual(result?.account, validAccount)
    XCTAssertEqual(result?.message?.key.rawValue, "message")
  }

  // test appLifeCycle change

  func test_authorize_succeeds_whenSwitchingSession() {
    accountsDataStore.storeLastUsedAccount = always(Void())
    accountsDataStore.loadServerFingerprint = always(.success(.init(rawValue: "FINGERPRINT")))
    accountsDataStore.loadAccounts = always([validAccount, validAccountAlternative])
    features.use(accountsDataStore)
    passphraseCache.store = always(Void())
    passphraseCache.clear = always(Void())
    passphraseCache.passphrasePublisher = always(CurrentValueSubject<Passphrase?, Never>("passphrase").eraseToAnyPublisher())
    features.use(passphraseCache)
    features.use(networkClient)
    networkSession.createSession = always(
      Just(Array<MFAProvider>())
        .setFailureType(to: TheError.self)
        .eraseToAnyPublisher()
    )
    networkSession.closeSession = always(
      Just(Void())
        .setFailureType(to: TheError.self)
        .eraseToAnyPublisher()
    )
    features.use(networkSession)

    let feature: AccountSession = testInstance()

    feature
      .authorize(validAccountAlternative, .adHoc("passphrase", "private key"))
      .sinkDrop()
      .store(in: cancellables)

    var resultError: TheError?
    var result: Void?
    feature
      .authorize(validAccount, .adHoc("passphrase", "private key"))
      .sink(
        receiveCompletion: { completion in
          guard case let .failure(error) = completion
          else { return }
          resultError = error
        },
        receiveValue: { _ in
          result = Void()
        }
      )
      .store(in: cancellables)

    XCTAssertNil(resultError)
    XCTAssertNotNil(result)
  }

  func test_statePublisher_publishesAuthorizationRequiredForNewAccount_whenTryingToSwitchSession() {
    accountsDataStore.storeLastUsedAccount = always(Void())
    accountsDataStore.loadAccounts = always([])
    features.use(accountsDataStore)
    passphraseCache.store = always(Void())
    passphraseCache.clear = always(Void())
    passphraseCache.passphrasePublisher = always(CurrentValueSubject<Passphrase?, Never>("passphrase").eraseToAnyPublisher())
    features.use(passphraseCache)
    features.use(networkClient)
    networkSession.createSession = always(
      Just(Array<MFAProvider>())
        .setFailureType(to: TheError.self)
        .eraseToAnyPublisher()
    )
    networkSession.closeSession = always(
      Just(Void())
        .setFailureType(to: TheError.self)
        .eraseToAnyPublisher()
    )
    features.use(networkSession)

    let feature: AccountSession = testInstance()

    feature
      .authorize(validAccountAlternative, .adHoc("passphrase", "private key"))
      .sinkDrop()
      .store(in: cancellables)

    var result: Account?
    feature
      .statePublisher()
      .dropFirst()
      .first()
      .sink { state in
        guard case let .authorizationRequired(account) = state
        else { return }
        result = account
      }
      .store(in: cancellables)

    feature
      .authorize(validAccount, .adHoc("passphrase", "private key"))
      .sinkDrop()
      .store(in: cancellables)

    XCTAssertEqual(result, validAccount)
  }

  func test_authorize_closesPreviousSession_whenSwitchingAccount() {
    accountsDataStore.storeLastUsedAccount = always(Void())
    accountsDataStore.loadServerFingerprint = always(.success(.init(rawValue: "FINGERPRINT")))
    accountsDataStore.loadAccounts = always([])
    features.use(accountsDataStore)
    passphraseCache.store = always(Void())
    passphraseCache.clear = always(Void())
    passphraseCache.passphrasePublisher = always(CurrentValueSubject<Passphrase?, Never>("passphrase").eraseToAnyPublisher())
    features.use(passphraseCache)
    features.use(networkClient)
    networkSession.createSession = always(
      Just(Array<MFAProvider>())
        .setFailureType(to: TheError.self)
        .eraseToAnyPublisher()
    )
    var result: Void?
    networkSession.closeSession = {
      result = Void()
      return Just(Void())
        .setFailureType(to: TheError.self)
        .eraseToAnyPublisher()
    }
    features.use(networkSession)

    let feature: AccountSession = testInstance()

    feature
      .authorize(validAccountAlternative, .adHoc("passphrase", "private key"))
      .sinkDrop()
      .store(in: cancellables)

    feature
      .authorize(validAccount, .adHoc("passphrase", "private key"))
      .sinkDrop()
      .store(in: cancellables)

    XCTAssertNotNil(result)
  }

  func test_authorize_doesNotClosePreviousSession_whenSwitchingSameAccount() {
    accountsDataStore.storeLastUsedAccount = always(Void())
    accountsDataStore.loadAccounts = always([validAccountAlternative])
    features.use(accountsDataStore)
    passphraseCache.store = always(Void())
    passphraseCache.clear = always(Void())
    passphraseCache.passphrasePublisher = always(CurrentValueSubject<Passphrase?, Never>("passphrase").eraseToAnyPublisher())
    features.use(passphraseCache)
    features.use(networkClient)
    networkSession.createSession = always(
      Just(Array<MFAProvider>())
        .setFailureType(to: TheError.self)
        .eraseToAnyPublisher()
    )
    var result: Void?
    networkSession.closeSession = {
      result = Void()
      return Just(Void())
        .setFailureType(to: TheError.self)
        .eraseToAnyPublisher()
    }
    features.use(networkSession)

    let feature: AccountSession = testInstance()

    feature
      .authorize(validAccount, .adHoc("passphrase", "private key"))
      .sinkDrop()
      .store(in: cancellables)

    feature
      .authorize(validAccount, .adHoc("passphrase", "private key"))
      .sinkDrop()
      .store(in: cancellables)

    XCTAssertNil(result)
  }

  func test_authorize_doesClosePreviousSession_whenSwitchingToNotStoredAccount() {
    accountsDataStore.storeLastUsedAccount = always(Void())
    accountsDataStore.loadAccounts = always([validAccountAlternative])
    features.use(accountsDataStore)
    passphraseCache.store = always(Void())
    passphraseCache.clear = always(Void())
    passphraseCache.passphrasePublisher = always(CurrentValueSubject<Passphrase?, Never>("passphrase").eraseToAnyPublisher())
    features.use(passphraseCache)
    features.use(networkClient)
    networkSession.createSession = always(
      Just(Array<MFAProvider>())
        .setFailureType(to: TheError.self)
        .eraseToAnyPublisher()
    )
    var result: Void?
    networkSession.closeSession = {
      result = Void()
      return Just(Void())
        .setFailureType(to: TheError.self)
        .eraseToAnyPublisher()
    }
    features.use(networkSession)

    let feature: AccountSession = testInstance()

    feature
      .authorize(validAccountAlternative, .adHoc("passphrase", "private key"))
      .sinkDrop()
      .store(in: cancellables)

    feature
      .authorize(validAccount, .adHoc("passphrase", "private key"))
      .sinkDrop()
      .store(in: cancellables)

    XCTAssertNotNil(result)
  }

  func test_authorize_doesClosePreviousSession_whenSwitchingToAlreadyStoredAccount() {
    accountsDataStore.storeLastUsedAccount = always(Void())
    accountsDataStore.loadAccounts = always([validAccount, validAccountAlternative])
    features.use(accountsDataStore)
    passphraseCache.store = always(Void())
    passphraseCache.clear = always(Void())
    passphraseCache.passphrasePublisher = always(CurrentValueSubject<Passphrase?, Never>("passphrase").eraseToAnyPublisher())
    features.use(passphraseCache)
    features.use(networkClient)
    networkSession.createSession = always(
      Just(Array<MFAProvider>())
        .setFailureType(to: TheError.self)
        .eraseToAnyPublisher()
    )
    var result: Void?
    networkSession.closeSession = {
      result = Void()
      return Just(Void())
        .setFailureType(to: TheError.self)
        .eraseToAnyPublisher()
    }
    features.use(networkSession)

    let feature: AccountSession = testInstance()

    feature
      .authorize(validAccountAlternative, .adHoc("passphrase", "private key"))
      .sinkDrop()
      .store(in: cancellables)

    feature
      .authorize(validAccount, .adHoc("passphrase", "private key"))
      .sinkDrop()
      .store(in: cancellables)

    XCTAssertNotNil(result)
  }

  func test_authorizationPromptPresentationPublisher_publishesCurrentAccount_whenApplicationWillEnterForeground() {
    accountsDataStore.storeLastUsedAccount = always(Void())
    features.use(accountsDataStore)
    passphraseCache.store = always(Void())
    passphraseCache.passphrasePublisher = always(CurrentValueSubject<Passphrase?, Never>("passphrase").eraseToAnyPublisher())
    features.use(passphraseCache)
    features.use(networkClient)
    networkSession.createSession = always(
      Just(Array<MFAProvider>())
        .setFailureType(to: TheError.self)
        .eraseToAnyPublisher()
    )
    features.use(networkSession)
    let appLifeCycleSubject: PassthroughSubject<AppLifeCycle.Transition, Never> = .init()
    environment.appLifeCycle.lifeCyclePublisher = always(appLifeCycleSubject.eraseToAnyPublisher())

    let feature: AccountSession = testInstance()

    feature
      .authorize(validAccount, .adHoc("passphrase", "private key"))
      .sinkDrop()
      .store(in: cancellables)

    var result: AuthorizationPromptRequest?
    feature
      .authorizationPromptPresentationPublisher()
      .sink { request in
        result = request
      }
      .store(in: cancellables)

    appLifeCycleSubject.send(.willEnterForeground)

    XCTAssertEqual(result?.account, validAccount)
  }

  func test_mfaAuthorization_fails_withNoActiveSession() {
    features.use(accountsDataStore)
    features.use(passphraseCache)
    features.use(networkClient)

    networkSession.createMFAToken = { account, authorization, remember in
      return Empty()
        .eraseToAnyPublisher()
    }
    features.use(networkSession)

    let feature: AccountSession = testInstance()

    var result: TheError?
    feature
      .mfaAuthorize(.totp("OTP"), false)
      .sink(
        receiveCompletion: { completion in
          guard case let .failure(error) = completion
          else { return }
          result = error
        },
        receiveValue: {}
      )
      .store(in: cancellables)

    XCTAssertEqual(result?.identifier, .authorizationRequired)
  }

  func test_mfaAuthorization_isForwardedToNetworkSession() {
    accountsDataStore.storeLastUsedAccount = always(Void())
    features.use(accountsDataStore)
    passphraseCache.store = always(Void())
    passphraseCache.passphrasePublisher = always(CurrentValueSubject<Passphrase?, Never>("passphrase").eraseToAnyPublisher())
    features.use(passphraseCache)
    features.use(networkClient)
    networkSession.createSession = always(
      Just(Array<MFAProvider>())
        .setFailureType(to: TheError.self)
        .eraseToAnyPublisher()
    )
    var result: (account: Account, authorization: AccountSession.MFAAuthorizationMethod, remember: Bool)?
    networkSession.createMFAToken = { account, authorization, remember in
      result = (account, authorization, remember)
      return Empty().eraseToAnyPublisher()
    }
    features.use(networkSession)

    let feature: AccountSession = testInstance()

    feature
      .authorize(validAccount, .adHoc("passphrase", "private key"))
      .sinkDrop()
      .store(in: cancellables)

    feature
      .mfaAuthorize(.totp("OTP"), false)
      .sinkDrop()
      .store(in: cancellables)

    XCTAssertEqual(result?.account, validAccount)
    XCTAssertEqual(result?.authorization, .totp("OTP"))
    XCTAssertEqual(result?.remember, false)
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
  domain: "https://passbolt.dev",
  userID: "USER_ID_ALT",
  fingerprint: "FINGERPRINT_ALT"
)

private let validSessionTokens: NetworkSessionTokens = .init(
  accountLocalID: validAccount.localID,
  accessToken: validJWTToken,
  refreshToken: "refresh_token"
)

private let armoredPGPPrivateKey: ArmoredPGPPrivateKey = "private_key"

private let validJWTToken: JWT
= try! .from(rawValue: """
eyJhbGciOiJSUzI1NiIsInR5cCI6IkpXVCJ9.eyJhdWQiOiJpb3MiLCJleHAiOjE1MTYyMzkwMjIsImlzcyI6IlBhc3Nib2x0Iiwic3ViIjoiMTIzNDU2Nzg5MCJ9.mooyAR9uQ1F6sHMaA3Ya4bRKPazydqowEsgm-Sbr7RmED36CShWdF3a-FdxyezcgI85FPyF0Df1_AhTOknb0sPs-Yur1Oa0XwsDsXfpw-xJsnlx9JCylp6C6rm_rypJL1E8t_63QCS_k5rv7hpDc8ctjLW8mXoFXXP_bDkSezyPVUaRDvjLgaDm01Ocin112h1FvQZTittQhhdL-KU5C1HjCJn03zNmH46TihstdK7PZ7mRz2YgIpm9P-5JzYYmSV3eP70_0dVCC_lv0N3VJFLKVB9FP99R4jChJv5DEilEgMwi_73YsP3Z55rGDaoyjhj661rDteq-42LMXcvSmOg
"""
)
.get()
