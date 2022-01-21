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
import Features
import TestExtensions
import XCTest

@testable import Accounts
@testable import Crypto
@testable import NetworkClient

// swift-format-ignore: AlwaysUseLowerCamelCase, NeverUseImplicitlyUnwrappedOptionals
final class NetworkSessionCreateSessionTests: TestCase {

  var networkClient: NetworkClient!
  var accountsDataStore: AccountsDataStore!
  var fingerprintStorage: FingerprintStorage!
  var verificationToken: UUID!
  var refreshToken: UUID!
  var domain: URLString!
  var passphrase: Passphrase!
  var tokens: Tokens!

  override func setUp() {
    super.setUp()

    networkClient = .placeholder
    accountsDataStore = .placeholder
    fingerprintStorage = .placeholder

    verificationToken = .test
    refreshToken = .test
    domain = "passbolt.com"
    passphrase = "SECRET PASSPHRASE"
    tokens = .init(
      version: "1.0.0",
      domain: domain.rawValue,
      verificationToken: verificationToken.uuidString,
      accessToken: validToken,
      refreshToken: refreshToken.uuidString
    )

    features.environment.time.timestamp = always(1_516_000_000)

    features.environment.uuidGenerator.uuid = always(self.verificationToken)
    features.environment.pgp.encryptAndSign = always(.success("EncryptedAndSigned"))
    features.environment.pgp.decryptAndVerify = always(
      .success(
        String(
          bytes: try! JSONEncoder()
            .encode(self.tokens),
          encoding: .utf8
        )!
      )
    )
    features.environment.pgp.verifyPublicKeyFingerprint = always(.success(true))
    features.environment.pgp.extractFingerprint = always(.success(.init(rawValue: serverPGPPublicKeyFingerprint)))
    features.environment.signatureVerfication.verify = always(.success(Void()))

    accountsDataStore.loadAccountMFAToken = always(.success(nil))

    networkClient.serverRSAPublicKeyRequest = .respondingWith(
      .init(
        header: .mock(),
        body: .init(keyData: serverRSAPublicKey.rawValue)
      )
    )

    networkClient.serverPGPPublicKeyRequest = .respondingWith(
      .init(
        header: .mock(),
        body: .init(
          keyData: serverPGPPublicKey.rawValue
        )
      )
    )

    networkClient.signInRequest = .respondingWith(
      .init(
        mfaTokenIsValid: false,
        body: .init(
          header: .mock(),
          body: .init(challenge: "")
        )
      )
    )

    networkClient.setAccessTokenInvalidation = always(Void())
    networkClient.setSessionStatePublisher = always(Void())

    fingerprintStorage.loadServerFingerprint = always(.success(.init(rawValue: serverPGPPublicKeyFingerprint)))
    fingerprintStorage.storeServerFingerprint = always(.success(()))
  }

  override func tearDown() {
    networkClient = nil

    verificationToken = nil
    refreshToken = nil
    domain = nil
    passphrase = nil

    super.tearDown()
  }

  func test_createSession_succeeds_withHappyPath() {
    features.use(accountsDataStore)
    features.use(fingerprintStorage)
    features.use(networkClient)

    let networkSession: NetworkSession = testInstance()

    var result: Void?

    networkSession
      .createSession(
        validAccount,
        pgpPrivateKey,
        passphrase
      )
      .sink(
        receiveCompletion: { _ in },
        receiveValue: { sessionToken in
          result = Void()
        }
      )
      .store(in: cancellables)

    XCTAssertNotNil(result)
  }

  func test_createSession_fails_whenSignInFails() {
    accountsDataStore.loadAccountMFAToken = always(.success(nil))
    fingerprintStorage.loadServerFingerprint = always(.success(.init(rawValue: serverPGPPublicKeyFingerprint)))
    fingerprintStorage.storeServerFingerprint = always(.success(()))
    features.use(accountsDataStore)
    features.use(fingerprintStorage)
    networkClient.signInRequest.execute = always(
      Fail<SignInResponse, TheErrorLegacy>(error: .testError()).eraseToAnyPublisher()
    )

    features.use(networkClient)

    let networkSession: NetworkSession = testInstance()

    var result: TheErrorLegacy?

    networkSession
      .createSession(
        validAccount,
        pgpPrivateKey,
        passphrase
      )
      .sink(
        receiveCompletion: { completion in
          guard case let .failure(error) = completion
          else { return }
          result = error
        },
        receiveValue: { _ in
        }
      )
      .store(in: cancellables)

    XCTAssertEqual(result?.identifier, .testError)
  }

  func test_createSession_fails_withoutServerPGPPublicKey() {
    accountsDataStore.loadAccountMFAToken = always(.success(nil))
    features.use(accountsDataStore)
    features.use(fingerprintStorage)
    networkClient.serverPGPPublicKeyRequest = .failingWith(.testError())
    features.use(networkClient)

    let networkSession: NetworkSession = testInstance()

    var result: TheErrorLegacy?

    networkSession
      .createSession(
        validAccount,
        pgpPrivateKey,
        passphrase
      )
      .sink(
        receiveCompletion: { completion in
          guard case let .failure(error) = completion
          else { return }
          result = error
        },
        receiveValue: { _ in
        }
      )
      .store(in: cancellables)

    XCTAssertEqual(result?.identifier, .testError)
  }

  func test_createSession_fails_withoutServerRSAPublicKey() {
    accountsDataStore.loadAccountMFAToken = always(.success(nil))
    features.use(accountsDataStore)
    features.use(fingerprintStorage)
    networkClient.serverRSAPublicKeyRequest = .failingWith(.testError())

    features.use(networkClient)

    let networkSession: NetworkSession = testInstance()

    var result: TheErrorLegacy?

    networkSession
      .createSession(
        validAccount,
        pgpPrivateKey,
        passphrase
      )
      .sink(
        receiveCompletion: { completion in
          guard case let .failure(error) = completion
          else { return }
          result = error
        },
        receiveValue: { _ in
        }
      )
      .store(in: cancellables)

    XCTAssertEqual(result?.identifier, .testError)
  }

  func test_createSession_fails_whenEncryptAndSignFails() {
    accountsDataStore.loadAccountMFAToken = always(.success(nil))
    features.use(accountsDataStore)
    features.environment.pgp.encryptAndSign = always(.failure(.testError()))
    fingerprintStorage.loadServerFingerprint = always(.success(.init(rawValue: serverPGPPublicKeyFingerprint)))
    fingerprintStorage.storeServerFingerprint = always(.success(()))
    features.use(fingerprintStorage)
    features.use(networkClient)

    let networkSession: NetworkSession = testInstance()

    var result: TheErrorLegacy?

    networkSession
      .createSession(
        validAccount,
        pgpPrivateKey,
        passphrase
      )
      .sink(
        receiveCompletion: { completion in
          guard case let .failure(error) = completion
          else { return }
          result = error
        },
        receiveValue: { _ in
        }
      )
      .store(in: cancellables)

    XCTAssertEqual(result?.identifier, .testError)
  }

  func test_createSession_fails_whenDecryptAndVerifyFails_andServerFingerprint_isValid() {
    accountsDataStore.loadAccountMFAToken = always(.success(nil))
    fingerprintStorage.loadServerFingerprint = always(.success(.init(rawValue: serverPGPPublicKeyFingerprint)))
    fingerprintStorage.storeServerFingerprint = always(.success(()))
    features.use(accountsDataStore)
    features.environment.pgp.decryptAndVerify = always(.failure(.testError()))
    features.use(networkClient)
    features.use(fingerprintStorage)

    let networkSession: NetworkSession = testInstance()

    var result: TheErrorLegacy?

    networkSession
      .createSession(
        validAccount,
        pgpPrivateKey,
        passphrase
      )
      .sink(
        receiveCompletion: { completion in
          guard case let .failure(error) = completion
          else { return }
          result = error
        },
        receiveValue: { _ in
        }
      )
      .store(in: cancellables)

    XCTAssertEqual(result?.identifier, .testError)
  }

  func test_createSession_fails_whenSignatureVerificationFails() {
    accountsDataStore.loadAccountMFAToken = always(.success(nil))
    features.use(accountsDataStore)
    features.environment.signatureVerfication.verify = always(.failure(.testError()))
    fingerprintStorage.loadServerFingerprint = always(.success(.init(rawValue: serverPGPPublicKeyFingerprint)))
    fingerprintStorage.storeServerFingerprint = always(.success(()))
    features.use(networkClient)
    features.use(fingerprintStorage)

    let networkSession: NetworkSession = testInstance()

    var result: TheErrorLegacy?

    networkSession
      .createSession(
        validAccount,
        pgpPrivateKey,
        passphrase
      )
      .sink(
        receiveCompletion: { completion in
          guard case let .failure(error) = completion
          else { return }
          result = error
        },
        receiveValue: { _ in
        }
      )
      .store(in: cancellables)

    XCTAssertEqual(result?.identifier, .testError)
  }

  func test_createSession_fails_whenVerificationTokenIsInvalid() {
    accountsDataStore.loadAccountMFAToken = always(.success(nil))
    features.use(accountsDataStore)
    tokens.verificationToken = "invalid"

    fingerprintStorage.loadServerFingerprint = always(.success(.init(rawValue: serverPGPPublicKeyFingerprint)))
    fingerprintStorage.storeServerFingerprint = always(.success(()))
    features.use(fingerprintStorage)
    features.use(networkClient)

    let networkSession: NetworkSession = testInstance()

    var result: TheErrorLegacy?

    networkSession
      .createSession(
        validAccount,
        pgpPrivateKey,
        passphrase
      )
      .sink(
        receiveCompletion: { completion in
          guard case let .failure(error) = completion
          else { return }
          result = error
        },
        receiveValue: { _ in
        }
      )
      .store(in: cancellables)

    XCTAssertEqual(result?.identifier, .signInError)
  }

  func test_createSession_fails_whenServerFingerprintStore_fails_andNoFingerprintIsStored() {
    accountsDataStore.loadAccountMFAToken = always(.success(nil))
    fingerprintStorage.loadServerFingerprint = always(.success(nil))
    fingerprintStorage.storeServerFingerprint = always(.failure(.testError()))
    features.use(accountsDataStore)
    features.use(fingerprintStorage)
    features.use(networkClient)

    let networkSession: NetworkSession = testInstance()

    var result: TheErrorLegacy?

    networkSession
      .createSession(
        validAccount,
        pgpPrivateKey,
        passphrase
      )
      .sink(
        receiveCompletion: { completion in
          guard case let .failure(error) = completion
          else { return }
          result = error
        },
        receiveValue: { _ in
        }
      )
      .store(in: cancellables)

    XCTAssertEqual(result?.identifier, .testError)
  }

  func
    test_createSession_fails_withInvalidServerFingerprintError_whenStoredFingerprint_doesNotMatchReceivedFingerprint()
  {
    let storedFingerprint: Fingerprint = .init(rawValue: otherServerFingerprint)
    accountsDataStore.loadAccountMFAToken = always(.success(nil))
    fingerprintStorage.loadServerFingerprint = always(.success(storedFingerprint))
    fingerprintStorage.storeServerFingerprint = always(.success(()))
    features.environment.pgp.verifyPublicKeyFingerprint = always(.success(false))
    features.use(accountsDataStore)
    features.use(fingerprintStorage)
    features.use(networkClient)

    let networkSession: NetworkSession = testInstance()

    var result: TheErrorLegacy?

    networkSession
      .createSession(
        validAccount,
        pgpPrivateKey,
        passphrase
      )
      .sink(
        receiveCompletion: { completion in
          guard case let .failure(error) = completion
          else { return }
          result = error
        },
        receiveValue: { _ in
        }
      )
      .store(in: cancellables)

    XCTAssertEqual(result?.identifier, .invalidServerFingerprint)
  }

  func test_createSession_fails_whenServerFingerprintLoad_failsWithInvalidServerFingerprintError() {
    accountsDataStore.loadAccountMFAToken = always(.success(nil))
    fingerprintStorage.loadServerFingerprint = always(.failure(.testError()))
    fingerprintStorage.storeServerFingerprint = always(.success(()))
    features.use(accountsDataStore)
    features.use(fingerprintStorage)
    features.use(networkClient)

    let networkSession: NetworkSession = testInstance()

    var result: TheErrorLegacy?

    networkSession
      .createSession(
        validAccount,
        pgpPrivateKey,
        passphrase
      )
      .sink(
        receiveCompletion: { completion in
          guard case let .failure(error) = completion
          else { return }
          result = error
        },
        receiveValue: { _ in
        }
      )
      .store(in: cancellables)

    XCTAssertEqual(result?.identifier, .invalidServerFingerprint)
  }

  func test_createMFAToken_doesNotStoreMFAToken_whenStoreLocallyFlagIsFalse() {
    var result: MFAToken?
    accountsDataStore.storeAccountMFAToken = { _, mfaToken in
      result = mfaToken
      return .success
    }
    features.use(accountsDataStore)
    features.use(fingerprintStorage)

    networkClient.totpAuthorizationRequest.execute = always(
      Just(TOTPAuthorizationResponse(mfaToken: .init(rawValue: "mfa_token")))
        .setFailureType(to: TheErrorLegacy.self)
        .eraseToAnyPublisher()
    )
    features.use(networkClient)

    let networkSession: NetworkSession = testInstance()

    networkSession
      .createMFAToken(
        validAccount,
        .totp("totp"),
        false
      )
      .sinkDrop()
      .store(in: cancellables)

    XCTAssertNil(result)
  }

  func test_createMFAToken_storesMFAToken_whenStoreLocallyFlagIsTrue() {
    var result: MFAToken?
    accountsDataStore.storeAccountMFAToken = { _, mfaToken in
      result = mfaToken
      return .success
    }
    accountsDataStore.loadAccountMFAToken = always(.success(nil))
    features.use(accountsDataStore)
    fingerprintStorage.loadServerFingerprint = always(.success(nil))
    fingerprintStorage.storeServerFingerprint = always(.success)
    features.use(fingerprintStorage)

    networkClient.totpAuthorizationRequest.execute = always(
      Just(TOTPAuthorizationResponse(mfaToken: .init(rawValue: "mfa_token")))
        .setFailureType(to: TheErrorLegacy.self)
        .eraseToAnyPublisher()
    )
    features.use(networkClient)

    let networkSession: NetworkSession = testInstance()
    networkSession
      .createSession(
        validAccount,
        pgpPrivateKey,
        passphrase
      )
      .sinkDrop()
      .store(in: cancellables)

    networkSession
      .createMFAToken(
        validAccount,
        .totp("totp"),
        true
      )
      .sinkDrop()
      .store(in: cancellables)

    XCTAssertEqual(result, .init(rawValue: "mfa_token"))
  }

  func test_createMFAToken_fails_whenThereIsNoMatchingSession() {
    features.use(accountsDataStore)
    features.use(fingerprintStorage)

    networkClient.totpAuthorizationRequest.execute = always(
      Fail(error: .testError())
        .eraseToAnyPublisher()
    )
    features.use(networkClient)

    let networkSession: NetworkSession = testInstance()

    var result: TheErrorLegacy?
    networkSession
      .createMFAToken(
        validAccount,
        .totp("totp"),
        true
      )
      .sink(
        receiveCompletion: { completion in
          guard case let .failure(error) = completion
          else { return }
          result = error
        },
        receiveValue: {}
      )
      .store(in: cancellables)

    XCTAssertEqual(result?.identifier, .missingSessionError)
  }

  func test_createMFAToken_fails_whenTOTPRequestFails() {
    accountsDataStore.loadAccountMFAToken = always(.success(nil))
    features.use(accountsDataStore)
    features.use(fingerprintStorage)

    networkClient.totpAuthorizationRequest.execute = always(
      Fail(error: .testError())
        .eraseToAnyPublisher()
    )
    features.use(networkClient)

    let networkSession: NetworkSession = testInstance()
    networkSession
      .createSession(
        validAccount,
        pgpPrivateKey,
        passphrase
      )
      .sinkDrop()
      .store(in: cancellables)

    var result: TheErrorLegacy?
    networkSession
      .createMFAToken(
        validAccount,
        .totp("totp"),
        true
      )
      .sink(
        receiveCompletion: { completion in
          guard case let .failure(error) = completion
          else { return }
          result = error
        },
        receiveValue: {}
      )
      .store(in: cancellables)

    XCTAssertEqual(result?.identifier, .testError)
  }

  func test_createMFAToken_fails_whenYubikeyOTPRequestFails() {
    accountsDataStore.loadAccountMFAToken = always(.success(nil))
    features.use(accountsDataStore)
    features.use(fingerprintStorage)

    networkClient.yubikeyAuthorizationRequest.execute = always(
      Fail(error: .testError())
        .eraseToAnyPublisher()
    )
    features.use(networkClient)

    let networkSession: NetworkSession = testInstance()
    networkSession
      .createSession(
        validAccount,
        pgpPrivateKey,
        passphrase
      )
      .sinkDrop()
      .store(in: cancellables)

    var result: TheErrorLegacy?
    networkSession
      .createMFAToken(
        validAccount,
        .yubikeyOTP("otp"),
        true
      )
      .sink(
        receiveCompletion: { completion in
          guard case let .failure(error) = completion
          else { return }
          result = error
        },
        receiveValue: {}
      )
      .store(in: cancellables)

    XCTAssertEqual(result?.identifier, .testError)
  }

  func test_createMFAToken_fails_whenMFATokenStoreFails() {
    accountsDataStore.loadAccountMFAToken = always(.success(nil))
    accountsDataStore.storeAccountMFAToken = always(.failure(TheErrorLegacy.testError()))
    features.use(accountsDataStore)
    features.use(fingerprintStorage)

    networkClient.totpAuthorizationRequest.execute = always(
      Just(TOTPAuthorizationResponse(mfaToken: .init(rawValue: "mfa_token")))
        .setFailureType(to: TheErrorLegacy.self)
        .eraseToAnyPublisher()
    )
    features.use(networkClient)

    let networkSession: NetworkSession = testInstance()
    networkSession
      .createSession(
        validAccount,
        pgpPrivateKey,
        passphrase
      )
      .sinkDrop()
      .store(in: cancellables)

    var result: TheErrorLegacy?
    networkSession
      .createMFAToken(
        validAccount,
        .totp("totp"),
        true
      )
      .sink(
        receiveCompletion: { completion in
          guard case let .failure(error) = completion
          else { return }
          result = error
        },
        receiveValue: {}
      )
      .store(in: cancellables)

    XCTAssertEqual(result?.identifier, .testError)
  }

  func test_createMFAToken_succeeds_whenAllTOTPOperationsSucceed() {
    accountsDataStore.loadAccountMFAToken = always(.success(nil))
    accountsDataStore.storeAccountMFAToken = always(.success)
    features.use(accountsDataStore)
    features.use(fingerprintStorage)

    networkClient.totpAuthorizationRequest.execute = always(
      Just(TOTPAuthorizationResponse(mfaToken: .init(rawValue: "mfa_token")))
        .setFailureType(to: TheErrorLegacy.self)
        .eraseToAnyPublisher()
    )
    features.use(networkClient)

    let networkSession: NetworkSession = testInstance()
    networkSession
      .createSession(
        validAccount,
        pgpPrivateKey,
        passphrase
      )
      .sinkDrop()
      .store(in: cancellables)

    var result: Void?
    networkSession
      .createMFAToken(
        validAccount,
        .totp("totp"),
        true
      )
      .sink(
        receiveCompletion: { completion in
          guard case .finished = completion
          else { return }
          result = Void()
        },
        receiveValue: {}
      )
      .store(in: cancellables)

    XCTAssertNotNil(result)
  }

  func test_createMFAToken_succeeds_whenAllYubikeyOTPOperationsSucceed() {
    accountsDataStore.loadAccountMFAToken = always(.success(nil))
    accountsDataStore.storeAccountMFAToken = always(.success)
    features.use(accountsDataStore)
    features.use(fingerprintStorage)

    networkClient.yubikeyAuthorizationRequest.execute = always(
      Just(YubikeyAuthorizationResponse(mfaToken: .init(rawValue: "mfa_token")))
        .setFailureType(to: TheErrorLegacy.self)
        .eraseToAnyPublisher()
    )
    features.use(networkClient)

    let networkSession: NetworkSession = testInstance()
    networkSession
      .createSession(
        validAccount,
        pgpPrivateKey,
        passphrase
      )
      .sinkDrop()
      .store(in: cancellables)

    var result: Void?
    networkSession
      .createMFAToken(
        validAccount,
        .yubikeyOTP("otp"),
        true
      )
      .sink(
        receiveCompletion: { completion in
          guard case .finished = completion
          else { return }
          result = Void()
        },
        receiveValue: {}
      )
      .store(in: cancellables)

    XCTAssertNotNil(result)
  }

  func test_createSession_deletesMFAToken_withSuccessWhenResponseMFATokenIsNotValid() {
    accountsDataStore.loadAccountMFAToken = always(.success("mfa_token"))
    var result: Void?
    accountsDataStore.deleteAccountMFAToken = { _ in
      result = Void()
      return .success
    }
    fingerprintStorage.loadServerFingerprint = always(.success(.init(rawValue: serverPGPPublicKeyFingerprint)))
    fingerprintStorage.storeServerFingerprint = always(.success(()))
    features.use(accountsDataStore)
    features.use(fingerprintStorage)
    networkClient.signInRequest = .respondingWith(
      .init(
        mfaTokenIsValid: false,
        body: .init(
          header: .mock(),
          body: .init(challenge: "")
        )
      )
    )
    features.use(networkClient)

    let networkSession: NetworkSession = testInstance()

    networkSession
      .createSession(
        validAccount,
        pgpPrivateKey,
        passphrase
      )
      .sinkDrop()
      .store(in: cancellables)

    XCTAssertNotNil(result)
  }

  func test_createSession_doesNotDeleteMFAToken_withSuccessWhenResponseMFATokenIsValid() {
    accountsDataStore.loadAccountMFAToken = always(.success("mfa_token"))
    var result: Void?
    accountsDataStore.deleteAccountMFAToken = { _ in
      result = Void()
      return .success
    }
    fingerprintStorage.loadServerFingerprint = always(.success(.init(rawValue: serverPGPPublicKeyFingerprint)))
    fingerprintStorage.storeServerFingerprint = always(.success(()))
    features.use(accountsDataStore)
    features.use(fingerprintStorage)
    networkClient.signInRequest = .respondingWith(
      .init(
        mfaTokenIsValid: true,
        body: .init(
          header: .mock(),
          body: .init(challenge: "")
        )
      )
    )
    features.use(networkClient)

    let networkSession: NetworkSession = testInstance()

    networkSession
      .createSession(
        validAccount,
        pgpPrivateKey,
        passphrase
      )
      .sinkDrop()
      .store(in: cancellables)

    XCTAssertNil(result)
  }

  func test_createSession_doesNotDeleteMFAToken_whenSignInFails() {
    accountsDataStore.loadAccountMFAToken = always(.success("mfa_token"))
    accountsDataStore.loadAccounts = always([validAccount])
    var result: Void?
    accountsDataStore.deleteAccountMFAToken = { _ in
      result = Void()
      return .success
    }
    features.use(accountsDataStore)
    fingerprintStorage.loadServerFingerprint = always(.success(.init(rawValue: serverPGPPublicKeyFingerprint)))
    fingerprintStorage.storeServerFingerprint = always(.success(()))
    features.use(fingerprintStorage)
    networkClient.signInRequest.execute = always(
      Fail<SignInResponse, TheErrorLegacy>(error: .testError()).eraseToAnyPublisher()
    )

    features.use(networkClient)

    let networkSession: NetworkSession = testInstance()

    networkSession
      .createSession(
        validAccount,
        pgpPrivateKey,
        passphrase
      )
      .sinkDrop()
      .store(in: cancellables)

    XCTAssertNil(result)
  }

  func test_saveServerFingerprint_succeeds_whenNoFingerprint_wasPreviouslyStored() {
    var storedFingerprint: Fingerprint?
    accountsDataStore.loadAccountMFAToken = always(.success(nil))
    fingerprintStorage.loadServerFingerprint = always(.success(storedFingerprint))
    fingerprintStorage.storeServerFingerprint = { _, fingerprint in
      storedFingerprint = fingerprint
      return .success(())
    }
    features.use(accountsDataStore)
    features.use(fingerprintStorage)
    features.use(networkClient)

    let networkSession: NetworkSession = testInstance()

    XCTAssertNil(storedFingerprint)

    networkSession
      .createSession(
        validAccount,
        pgpPrivateKey,
        passphrase
      )
      .sinkDrop()
      .store(in: cancellables)

    XCTAssertEqual(storedFingerprint?.rawValue, serverPGPPublicKeyFingerprint)
  }

  func test_sessionRefresh_fails_whenThereIsNoMatchingSession() {
    features.use(accountsDataStore)
    features.use(fingerprintStorage)
    features.use(networkClient)

    let networkSession: NetworkSession = testInstance()

    var result: TheErrorLegacy?
    networkSession
      .refreshSessionIfNeeded(validAccount)
      .sink(
        receiveCompletion: { completion in
          guard case let .failure(error) = completion
          else { return }
          result = error
        },
        receiveValue: { /* NOP */  }
      )
      .store(in: cancellables)

    XCTAssertEqual(result?.identifier, .missingSessionError)
  }

  func test_sessionRefresh_isSkipped_whenAccessTokenIsStillValid() {
    features.use(accountsDataStore)
    features.use(fingerprintStorage)
    var result: Void?
    networkClient.refreshSessionRequest.execute = { _ in
      result = Void()
      return Just(
        RefreshSessionResponse(
          accessToken: "invalid JWT",
          refreshToken: "refreshToken"
        )
      )
      .setFailureType(to: TheErrorLegacy.self)
      .eraseToAnyPublisher()
    }

    features.use(networkClient)

    let networkSession: NetworkSession = testInstance()
    networkSession
      .createSession(
        validAccount,
        pgpPrivateKey,
        passphrase
      )
      .sinkDrop()
      .store(in: cancellables)

    networkSession
      .refreshSessionIfNeeded(validAccount)
      .sinkDrop()
      .store(in: cancellables)

    XCTAssertNil(result)
  }

  func test_sessionRefresh_fails_whenAccessTokenIsNotValidJWT() {
    // make current session (after create session) expired so it will allow session refresh
    environment.time.timestamp = always(1_638_374_700)
    features.use(accountsDataStore)
    features.use(fingerprintStorage)
    networkClient.refreshSessionRequest.execute = always(
      Just(
        RefreshSessionResponse(
          accessToken: "invalid JWT",
          refreshToken: "refreshToken"
        )
      )
      .setFailureType(to: TheErrorLegacy.self)
      .eraseToAnyPublisher()
    )
    features.use(networkClient)

    let networkSession: NetworkSession = testInstance()
    networkSession
      .createSession(
        validAccount,
        pgpPrivateKey,
        passphrase
      )
      .sinkDrop()
      .store(in: cancellables)

    var result: TheErrorLegacy?
    networkSession
      .refreshSessionIfNeeded(validAccount)
      .sink(
        receiveCompletion: { completion in
          guard case let .failure(error) = completion
          else { return }
          result = error
        },
        receiveValue: { /* NOP */  }
      )
      .store(in: cancellables)

    XCTAssertEqual(result?.identifier, .jwtError)
  }

  func test_sessionRefresh_fails_whenSessionRefreshRequestFails() {
    // make current session (after create session) expired so it will allow session refresh
    environment.time.timestamp = always(1_638_374_700)
    features.use(accountsDataStore)
    features.use(fingerprintStorage)
    networkClient.refreshSessionRequest.execute = always(
      Fail(error: .testError())
        .eraseToAnyPublisher()
    )
    features.use(networkClient)

    let networkSession: NetworkSession = testInstance()
    networkSession
      .createSession(
        validAccount,
        pgpPrivateKey,
        passphrase
      )
      .sinkDrop()
      .store(in: cancellables)

    var result: TheErrorLegacy?
    networkSession
      .refreshSessionIfNeeded(validAccount)
      .sink(
        receiveCompletion: { completion in
          guard case let .failure(error) = completion
          else { return }
          result = error
        },
        receiveValue: { /* NOP */  }
      )
      .store(in: cancellables)

    XCTAssertEqual(result?.identifier, .testError)
  }

  func test_sessionRefresh_succeeds_withHappyPath() {
    features.use(accountsDataStore)
    features.use(fingerprintStorage)
    networkClient.refreshSessionRequest.execute = always(
      Just(RefreshSessionResponse(accessToken: validToken, refreshToken: "refreshToken"))
        .setFailureType(to: TheErrorLegacy.self)
        .eraseToAnyPublisher()
    )
    features.use(networkClient)

    let networkSession: NetworkSession = testInstance()
    networkSession
      .createSession(
        validAccount,
        pgpPrivateKey,
        passphrase
      )
      .sinkDrop()
      .store(in: cancellables)

    var result: TheErrorLegacy?
    networkSession
      .refreshSessionIfNeeded(validAccount)
      .sink(
        receiveCompletion: { completion in
          guard case let .failure(error) = completion
          else { return }
          result = error
        },
        receiveValue: { /* NOP */  }
      )
      .store(in: cancellables)

    XCTAssertNil(result)
  }
}

// MARK: Test data

private let validAccount: Account = .init(
  localID: .init(rawValue: UUID.test.uuidString),
  domain: "https://localhost:8443",
  userID: "f848277c-5398-58f8-a82a-72397af2d450",
  fingerprint: "FINGERPRINT"
)

private let serverPGPPublicKey: ArmoredPGPPublicKey = """
  -----BEGIN PGP PUBLIC KEY BLOCK-----\nVersion: OpenPGP.js v4.6.2\nComment: https://openpgpjs.org\n\nxsBNBGBbRe0BCAC/VBEHj95tFp4ykmElcXNxdCcr0WOgSABVDNZVjyvt3ATG\nd8b6geoePfQX9TCDhzR4eoaRs/n5qpbvj6Kb4ZDxcsjAzn7b2Q3+flxg4+VD\nJOr79zEtqcKEmIIlecUPwy3E68oOPpe1CDwuOXI9dK/sOtLRTOWaQcBHIcs6\nw4IfZCnvrovIhuhaWJyA2xYA1MlIcpsK+x7c8snkv09wmzR06tT+i7jkd8Sc\n1j/rOOmSNgQxpCbVfSAiDN+MEGELveNOtrhdbprlB7m+q2tOiypEbnBYoL5v\nRPMDRzoew0duG18ITieFOa5OVXzvfjBdcoDeVl8iR/Kn7crmRYvAgyXVABEB\nAAHNGnRlc3QzIDx0ZXN0M0BwYXNzYm9sdC5jb20+wsB1BBABCAAfBQJgW0Xt\nBgsJBwgDAgQVCAoCAxYCAQIZAQIbAwIeAQAKCRCwLa3NlWXhuJiAB/0f4MKN\nKz7c5qdJjNGPvgExSfDLq1RIfR6pTrBCSpTxv+34n0hmjtS7GbFZWG+/eECs\n55GtFzORNBi589CgBBatNd0S7o5X1u4bau9NjahJ/gZXK8VOVWPleXPSnDmv\ngEeWGHKT+mvOvmS8n+iUdZI444a2s9Nk7OiL3r+q0OMvCOlc02sWhVCa0pE6\nk8ptHgRwdttfJY7UzmEcYvHNpnEgKexnlWCFSYTcXZtB3Gqja/j7+wyzK/Zh\nenRHRB9rwVmOKYlqtwsxZ9vpo9+Ca3kWMq4005FfKUOC+SZMN+19lG42pwrZ\n2/Isgoy4gNSoB/ZmrxcJ7K+lnSSXoRL4r8PNzsBNBGBbRe0BCADKZbs3Lwmv\needZfp/PKuBzrGEwkeTx5r1YwuUF53hWvLHCFH240NmSpgeLnpZsJuMP91yV\ns3EzAiPLbFqI803cQ1+URjciFuFycupcf9lgOsKbxodUz7ivORvmsuROg560\nByfEq69DSgIrRF1Z2aaCtLCFzw0q8lwYKR61ABpvr3rVEKfhsWF45m3esEJ1\neUYucJZ602/qv3Hfm/ephW5dlLn5f2GdKZW7PVbVt1AT62+6s8ges89FWA2F\niRFKf88uhJk1qR++V+uXPccVB6c/+nkO3GIWymKhECUxm62nQvytYlldTmb/\n8OeyBbhn0+ZbGT1bnkUr2POGP3CTA7o7ABEBAAHCwF8EGAEIAAkFAmBbRe0C\nGwwACgkQsC2tzZVl4biaCQgAuJTpcsh2UEqBHqmF6CyHbQz5WVdnXbpQebYb\nVQ3UQgSkEiUT9bwVnl/VMe3KiWlvdX+sLmIqFL9+RRB0eAHE8qgjlB8wf67t\nWwDftFh9vUNvFV1+72GFcN26GVCdVlTtkgDCvEDB/0/IMruGa7BpvD+LsPTJ\n9GUpdGtKXbhbH0QYCmp0CurLdJc0PnRNpUDXRQaZvYyBs8Kctjpbcxyd61/1\nS8t13+75XH/WMCZOXX2HZUm8/nj8CE2OV0z2pxfO08s4Q1DCpV72gnPzrr+E\n/iJQWd+b0qFaJvkjMNH//OoYx4K3ntlkofawTzfFIuBMJgwhvVXSKL/hE0F2\nWxHGgw==\n=bpWG\n-----END PGP PUBLIC KEY BLOCK-----\n\n
  """

private let serverPGPPublicKeyFingerprint: String = "E8FE388E385841B382B674ADB02DADCD9565E1B8"
private let otherServerFingerprint: String = "2A4842CF153F003F565C22C01AEB35EEC222D2BC"

private let pgpPrivateKey: ArmoredPGPPrivateKey =
  """
  -----BEGIN PGP PUBLIC KEY BLOCK-----

  mQENBGCGqHcBCADMbVyAkL2msB1HZyXDdca2vSpLB2YWgzwvPQF5whOxHTmeBY44
  tBttqB/jKXVlKFMuQJvkh2eIRAMzJHFK1Xd2MQHGGlbn9CYcBIdEUGhUh6/8ZGc7
  PkmxWnI0gaxsYENry8cKHbLHGA0hN+g8eHFbDzrbCEez8J1QSvykDr7TWG8sBdGa
  HWjRFHo8rQerLOlHoGWff/9KgkZN4mO7OBavITJVKA8g+bC9G0rt4vPzx60Uw1IF
  /9jeHSYdySM6rMMR73gW+EohkTmxX7gpSwdagP6orOVvZ7kOh8K8Jv48OSIV7LEY
  CTM5wFslypIWrCjMtebPaYm4DEI4MhugY/wtABEBAAG0H2pvaG5Ac21pdGguY29t
  IDxqb2huQHNtaXRoLmNvbT6JAVQEEwEIAD4WIQQqSELPFT8AP1ZcIsAa6zXuwiLS
  vAUCYIaodwIbAwUJA8JnAAULCQgHAgYVCgkICwIEFgIDAQIeAQIXgAAKCRAa6zXu
  wiLSvGyAB/41zXhopDvaBUu1aG0YlLXpEnaIrZjQuM+bPD0FL2ihrBZfCafh09B7
  YoqDwvOMywK5OsiQja95pWQTfwjsLibbGwlqCjmBGKn8l9DMMCW+oxFgacFaCarc
  cVGXi6LPvuzurKo3kR4r8FUyNC5BUE/RyukxIzgU5Pc2F61OPERkNOYLarreKCbf
  l6m+0qpQMhVMs3ycu6itRpf9FSrddIVNFQ2CgHP4chv9m2xCpiGZKBcnQJPiV2ZX
  DwynQF+e79BXyvXp9KwiHAa+SUJMLfdRJCzkZlhqTbJKiTEa0krBqxkhfVpu84Ui
  mLLF+UC9sWHGCkOfRgYi36jgTVeZ/qG7uQENBGCGqHcBCAC0JDyMuhcyJ+K7aqMp
  wDyxMnChtOGVaDNKjrlWD3ymRGmKCf+fbq4HQg+Mplp0K20PCswnqLzhv5qGT35l
  9G5Ll2rhtiGQQAn6o31TXwdtgmw1rqpWjFgnyWnKsYaE/gYbR0AKoqBIWm7JCBQ4
  qLdg160A4e1nf1J9P15sQSblEDlO6ccyT8vLcEHfpP1ocoUhP+YNm89NLvaxJhJP
  +J8fdvxheTAPexrvzGkH36xPzQcJSEsscULYY3ROIwoFDnDgNYykWdWGTq6Mw3w2
  Y7l1RtfaRL8DF5QwFRkpt5Y7AsC2loPTnF6KFYv3MMOkhMEYnWB0NyPSMUwDdj48
  LsfvABEBAAGJATwEGAEIACYWIQQqSELPFT8AP1ZcIsAa6zXuwiLSvAUCYIaodwIb
  DAUJA8JnAAAKCRAa6zXuwiLSvKsBB/0X2xa7Tkuw4lwPzK1fPWD/CUyaYGWHxLBF
  2kUvpD7fA2mcBDPq3RGYsqCiAXroZ0zBVEWXIGOn/dBxWPWTu6Sp3SKM54h/7Y0E
  fMuEJRRgmQt2KJ4G98hkenb80jbKCdvUgAkKdAKenuCatV1CrS3Yc7UXCEskDPYZ
  65De0U904McF4xfjetCqdtMaLOc3Zzw6fOE6XWggdTkfbQtq05AGTHaQozGoLFfo
  c9Oedmq/Xf3RPkEmx1kQGL7bxnmozu2aZ8aqUAbvUE2+h2J1khBtEM94Dkx6Umi2
  yRtBvQVl4QPn1cfUaW8vjiS+leLvnUmefIxCUjNEMwWD3kHNPhXy
  =0jTj
  -----END PGP PUBLIC KEY BLOCK-----
  """

private let serverRSAPrivateKey: ArmoredPGPPrivateKey = """
  -----BEGIN RSA PRIVATE KEY-----
  MIIEpAIBAAKCAQEAvqRXegLUB/h1s9Zx73lUq9BtVc9vEw9mheoGPmg7wJ+oKdRC
  Z9zykAqKear+1m8zeGoYhSdQ0uYdrHbyXeX2GzwA7FDIAGGYqxwvi4HEfkrmCFwu
  fJKHBV/iFeUrDhB1F1uSiS36i0KBef0eZi0rZk8n3t5XcRPlxd7eYNIP2iS+DWSL
  8EzCaigF4YePiL92Qp6ljutDFJLZ2t4La7enyCIgPl/9pxnZaGoOa658UtPfZs2l
  qGWQFdmbLMy9txdB/BzLdzejgtw7dKe5FWBV2FpXwESiCbPZGK9Zmqr/su1yUx//
  zI8Tnr+kInjIsWILfTKGLBczKSLobVJEdpHX1QIDAQABAoIBAQCUPRYIOcrFp91e
  SZGutJmyQA/EedfU6lS+LItOW56a2YrZe8NnH9c9SfUDRoOCGlXbfCQ05a1jUKwi
  PxuXCAmmg7H0D5x1L26XHwOZZv5zdaoJNiSvmQCEnVofzGL+PK3Py9TV9nqrbrtf
  MANDUDw/Aa3vDtTPiLlSc0pX3v+Uj0VButZI+QF6Qx4RMT6bsHYtfSAMaG9G+qIi
  Zd+Mr4aWIRu572LdDuO9f48jJiUklWG9ACHDoM61XVDrMFkSLc1E0seqSjqYRmW2
  Qte0tcoZ53DyGICc1RgshrjLUlOD5lNqVsODhUTQ1nNSNsFDq8qKJwEwro0v5h7J
  4y71AQYBAoGBAOrxee4dLiG1k9fph5ItkZKEW0ow8obu8/0bmlmiizZ1neWlXGJL
  y2UVxGr3cn243qtMpkDPljoigATk3GP/atKLvQeRmfhlHNDGDbM4bIfm6t9/BrTW
  a+Gn8+O+mma0nJzD3N5MqXTZ69pUlblvMv8mstQoohfnflYlVXfzuPTJAoGBAM+6
  a0Jqy04PyIsakL/Nj2CUIQxjosDkYp1Dr2O6JdXYYrPUrZ6rg3/BJgRf8+9vyZuI
  ++qTMNIum4t3wbXlnVPGss/jRoP1y6TkQBdte3yF4jF5swWbqXA9DjjDVVNbGfsD
  CLUuMKZ0UEVhU+QfzB0Gwd5sWbVtRVTfkXOSwwytAoGAUpIlsTsOMIi5eiO4Ivbi
  96SO1QdY5XVryOP/nksTNEOoB8LTMjTDOjapPpLS6T6k+31H3PVYLfxcE9w/XOGy
  sGauO8+/Vl5q/zDsNbW55xWQLJZfTAUkCz3U6JDfgQMvG6V2paY51DiWvLgHmxFq
  0ePO6+OP/Gi+rRYX8L12nokCgYBxlXJux6xRC8pRXX5GkmTSn0yO1LA6nubZLRhr
  BG8Jxh76S9F/kDMAGSHrhHgCtXJcrINq2X75fmio0xvFlT74fw5pI9H799uZVwFA
  jinWhfKPsQbViy8T4x6ypQQz5v2GxjrtrssFSVZXCYfwlf5q5LX/I+nNjWk6pmCG
  /HnQpQKBgQDfYO/WyMJEV1Bvm0pEDzTI3070e/gdtvxhDZrTzkelJ69f2ID6+1yP
  ZUH6IUJcADHfkjujuWuwLYAbNGGP3M+XHBNg7tu5Cb8hJdLD9h0/lo6K7ZYUWra0
  ypM5MJPjQg71iKUBzEaKld+8kqVPRzjJXN6nlaTOFxfiqtH/vifyNw==
  -----END RSA PRIVATE KEY-----
  """

private let serverRSAPublicKey: ArmoredPGPPublicKey = """
  -----BEGIN PUBLIC KEY-----
  MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEAvqRXegLUB/h1s9Zx73lU
  q9BtVc9vEw9mheoGPmg7wJ+oKdRCZ9zykAqKear+1m8zeGoYhSdQ0uYdrHbyXeX2
  GzwA7FDIAGGYqxwvi4HEfkrmCFwufJKHBV/iFeUrDhB1F1uSiS36i0KBef0eZi0r
  Zk8n3t5XcRPlxd7eYNIP2iS+DWSL8EzCaigF4YePiL92Qp6ljutDFJLZ2t4La7en
  yCIgPl/9pxnZaGoOa658UtPfZs2lqGWQFdmbLMy9txdB/BzLdzejgtw7dKe5FWBV
  2FpXwESiCbPZGK9Zmqr/su1yUx//zI8Tnr+kInjIsWILfTKGLBczKSLobVJEdpHX
  1QIDAQAB
  -----END PUBLIC KEY-----
  """

private let validToken: String = """
  eyJ0eXAiOiJKV1QiLCJhbGciOiJSUzI1NiJ9.eyJpc3MiOiJodHRwczpcL1wvcGFzc2JvbHQuZGV2XC8iLCJzdWIiOiI4ZDA0Y2Y5OC03MTZiLTVmNmQtOWZlOC1jMTMwZjg5OTI2NDYiLCJleHAiOjE2MjM4Mzg3NDF9.pIA0mht0ylvb9A5YCDmXMGgP6F2gUhcUrvAoxfKVEP7PePUbmkzPw2TEH2xpXTWPWlv-rMLD3he2wypHDHEwcv-t1_M3hCKsyYmbk2OKtSJoz649krnk53NdoD3qf9L72F1PZ7kGfgOq34eWaRWrmzdBrBceyiHAIAPjZGob474PBkaZl5ONivtU0X1abA7RoBxlH8zb3X_bIzq5pNl91-__J6KIY5horA5F-f8s1m7kArmN8JNocukdPoM5nugImBmJ3_vGbGuCmw5Zt4RI4J46adcYV-cqS4KX0KjYt-t9f2rV_k6JtjiKzMxVeaRDUJkeOUfL0jkwe90eQMW2gPCsjMND274R1LiGHYQRVZGCaJwSOKyoY8QUJzkDf1-z6nLDcexAJQ29jfKRNHQL8VURYk7EMD3BeTCew8LkHa3L_StFGZPaD2lZ35CltETP_Aa9m_P79C84uuYy5XntYxOlz2vz5MJ__8lgM4ujDZMFyNuUDG7rakMpkRcQNNJG-akzmNhVn6MK-2e2OVKrskzKBaW1O0_nni2EVAXOTSLHq7M83s7-zJtH1Lm0ngywtOrORUa_dF4ef_ogmN1iGNylNd0t1vBXDTLlXiuaYNbawubGATgDXKDkxZ-xgyLNDu2UkW17J0vRjsiV-MB3-GgeffO-HQVf6S6qMPHb5ok
  """
