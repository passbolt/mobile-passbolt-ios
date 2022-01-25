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

import Combine
import Features
import NetworkClient
import TestExtensions
import UIComponents
import XCTest

@testable import Accounts
@testable import SharedUIComponents

// swift-format-ignore: AlwaysUseLowerCamelCase, NeverUseImplicitlyUnwrappedOptionals
final class AuthorizationScreenTests: TestCase {

  var accounts: Accounts!
  var accountSession: AccountSession!
  var accountSettings: AccountSettings!
  var networkClient: NetworkClient!
  var biometry: Biometry!

  override func setUp() {
    super.setUp()

    accounts = .placeholder
    accountSession = .placeholder
    networkClient = .placeholder
    accountSettings = .placeholder
    biometry = .placeholder
  }

  override func tearDown() {
    accounts = nil
    accountSession = nil
    networkClient = nil
    accountSettings = nil
    biometry = nil
    super.tearDown()
  }

  func test_presentForgotPassphraseAlertPublisher_publishesTrue_whenPresentForgotPassphraseAlertCalled() {
    features.use(networkClient)
    accounts.storedAccounts = always([accountWithBiometry.account])
    features.use(accounts)
    features.use(accountSession)
    features.use(biometry)
    accountSettings.accountWithProfile = always(accountWithBiometry)
    accountSettings.updatedAccountIDsPublisher = always(Empty<Account.LocalID, Never>().eraseToAnyPublisher())
    features.use(accountSettings)

    let controller: AuthorizationController = testInstance(
      context: accountWithBiometry.account
    )
    var result: Bool!

    controller
      .presentForgotPassphraseAlertPublisher()
      .sink { presented in
        result = presented
      }
      .store(in: cancellables)

    controller.presentForgotPassphraseAlert()

    XCTAssertTrue(result)
  }

  func test_validatedPassphrasePublisher_publishesValidatedPassphrase_whenUpdatePassphraseCalled() {
    features.use(networkClient)
    accounts.storedAccounts = always([accountWithBiometry.account])
    features.use(accounts)
    features.use(accountSession)
    features.use(biometry)
    accountSettings.accountWithProfile = always(accountWithBiometry)
    accountSettings.updatedAccountIDsPublisher = always(Empty<Account.LocalID, Never>().eraseToAnyPublisher())
    features.use(accountSettings)

    let controller: AuthorizationController = testInstance(
      context: accountWithBiometry.account
    )
    var result: Validated<String>!

    controller
      .validatedPassphrasePublisher()
      .sink { validated in
        result = validated
      }
      .store(in: cancellables)

    controller.updatePassphrase("SomeSecretPassphrase")

    XCTAssertEqual(result.value, "SomeSecretPassphrase")
  }

  func test_signIn_succeeds_whenAuthorizationSucceeds() {
    features.use(networkClient)
    accounts.storedAccounts = always([accountWithBiometry.account])
    features.use(accounts)
    accountSession.authorize = always(
      Just(false)
        .setFailureType(to: TheErrorLegacy.self)
        .eraseToAnyPublisher()
    )
    features.use(accountSession)
    features.use(biometry)
    accountSettings.accountWithProfile = always(accountWithBiometry)
    accountSettings.updatedAccountIDsPublisher = always(Empty<Account.LocalID, Never>().eraseToAnyPublisher())
    features.use(accountSettings)

    let controller: AuthorizationController = testInstance(
      context: accountWithBiometry.account
    )
    var result: Void!

    controller
      .signIn()
      .sink(
        receiveCompletion: { _ in },
        receiveValue: { _ in
          result = Void()
        }
      )
      .store(in: cancellables)

    XCTAssertNotNil(result)
  }

  func test_signIn_fails_whenAuthorizationFails() {
    features.use(networkClient)
    accounts.storedAccounts = always([accountWithBiometry.account])
    features.use(accounts)
    accountSession.authorize = always(
      Fail(error: .testError())
        .eraseToAnyPublisher()
    )
    features.use(accountSession)
    features.use(biometry)
    accountSettings.accountWithProfile = always(accountWithBiometry)
    accountSettings.updatedAccountIDsPublisher = always(Empty<Account.LocalID, Never>().eraseToAnyPublisher())
    features.use(accountSettings)

    let controller: AuthorizationController = testInstance(
      context: accountWithBiometry.account
    )
    var result: TheErrorLegacy!

    controller
      .signIn()
      .sink(
        receiveCompletion: { completion in
          guard case let .failure(error) = completion
          else { return }
          result = error
        },
        receiveValue: { _ in }
      )
      .store(in: cancellables)

    XCTAssertEqual(result.identifier, .testError)
  }

  func test_biometricSignIn_succeeds_whenAuthorizationSucceeds() {
    features.use(networkClient)
    accounts.storedAccounts = always([accountWithBiometry.account])
    features.use(accounts)
    accountSession.authorize = always(
      Just(false)
        .setFailureType(to: TheErrorLegacy.self)
        .eraseToAnyPublisher()
    )
    features.use(accountSession)
    features.use(biometry)
    accountSettings.accountWithProfile = always(accountWithBiometry)
    accountSettings.updatedAccountIDsPublisher = always(Empty<Account.LocalID, Never>().eraseToAnyPublisher())
    features.use(accountSettings)

    let controller: AuthorizationController = testInstance(
      context: accountWithBiometry.account
    )
    var result: Void!

    controller
      .biometricSignIn()
      .sink(
        receiveCompletion: { _ in },
        receiveValue: { _ in
          result = Void()
        }
      )
      .store(in: cancellables)

    XCTAssertNotNil(result)
  }

  func test_biometricSignIn_fails_whenAuthorizationFails() {
    features.use(networkClient)
    accounts.storedAccounts = always([accountWithBiometry.account])
    features.use(accounts)
    accountSession.authorize = always(
      Fail(error: .testError())
        .eraseToAnyPublisher()
    )
    features.use(accountSession)
    features.use(biometry)
    accountSettings.accountWithProfile = always(accountWithBiometry)
    accountSettings.updatedAccountIDsPublisher = always(Empty<Account.LocalID, Never>().eraseToAnyPublisher())
    features.use(accountSettings)

    let controller: AuthorizationController = testInstance(
      context: accountWithBiometry.account
    )
    var result: TheErrorLegacy!

    controller
      .biometricSignIn()
      .sink(
        receiveCompletion: { completion in
          guard case let .failure(error) = completion
          else { return }
          result = error
        },
        receiveValue: { _ in }
      )
      .store(in: cancellables)

    XCTAssertEqual(result.identifier, .testError)
  }

  func test_avatarPublisher_publishesData_whenNetworkRequestSucceeds() {
    let testData: Data = .init([0x01, 0x02])
    networkClient.mediaDownload = .respondingWith(testData)
    features.use(networkClient)
    accounts.storedAccounts = always([accountWithBiometry.account])
    features.use(accounts)
    accountSession.authorize = always(
      Just(false)
        .setFailureType(to: TheErrorLegacy.self)
        .eraseToAnyPublisher()
    )
    features.use(accountSession)
    features.use(biometry)
    accountSettings.accountWithProfile = always(accountWithBiometry)
    accountSettings.updatedAccountIDsPublisher = always(Empty<Account.LocalID, Never>().eraseToAnyPublisher())
    features.use(accountSettings)

    let controller: AuthorizationController = testInstance(
      context: accountWithBiometry.account
    )
    var result: Data!

    controller
      .accountAvatarPublisher()
      .sink { data in
        result = data
      }
      .store(in: cancellables)

    XCTAssertEqual(result, testData)
  }

  func test_avatarPublisher_publishesNil_whenNetworkRequestFails() {
    networkClient.mediaDownload = .failingWith(MockIssue.error())
    features.use(networkClient)
    accounts.storedAccounts = always([accountWithBiometry.account])
    features.use(accounts)
    accountSession.authorize = always(
      Just(false)
        .setFailureType(to: TheErrorLegacy.self)
        .eraseToAnyPublisher()
    )
    features.use(accountSession)
    features.use(biometry)
    accountSettings.accountWithProfile = always(accountWithBiometry)
    accountSettings.updatedAccountIDsPublisher = always(Empty<Account.LocalID, Never>().eraseToAnyPublisher())
    features.use(accountSettings)

    let controller: AuthorizationController = testInstance(
      context: accountWithBiometry.account
    )
    var result: Data!

    controller
      .accountAvatarPublisher()
      .sink { data in
        result = data
      }
      .store(in: cancellables)

    XCTAssertNil(result)
  }

  func test_biometricStatePublisher_publishesUnavailable_whenBiometricsIsUnavailable() {
    features.use(networkClient)
    accounts.storedAccounts = always([accountWithBiometry.account])
    features.use(accounts)
    features.use(accountSession)
    biometry.biometricsStatePublisher = always(Just(.unavailable).eraseToAnyPublisher())
    features.use(biometry)
    accountSettings.accountWithProfile = always(accountWithBiometry)
    accountSettings.updatedAccountIDsPublisher = always(Empty<Account.LocalID, Never>().eraseToAnyPublisher())
    features.use(accountSettings)

    let controller: AuthorizationController = testInstance(
      context: accountWithBiometry.account
    )
    var result: AuthorizationController.BiometricsState!

    controller
      .biometricStatePublisher()
      .sink { state in
        result = state
      }
      .store(in: cancellables)

    XCTAssertEqual(result, .unavailable)
  }

  func test_biometricStatePublisher_publishesUnavailable_whenBiometricsIsAvailableAndAccountDoesNotUseIt() {
    features.use(networkClient)
    accounts.storedAccounts = always([accountWithoutBiometry.account])
    features.use(accounts)
    features.use(accountSession)
    biometry.biometricsStatePublisher = always(Just(.configuredFaceID).eraseToAnyPublisher())
    features.use(biometry)
    accountSettings.accountWithProfile = always(accountWithoutBiometry)
    accountSettings.updatedAccountIDsPublisher = always(Empty<Account.LocalID, Never>().eraseToAnyPublisher())
    features.use(accountSettings)

    let controller: AuthorizationController = testInstance(
      context: accountWithoutBiometry.account
    )
    var result: AuthorizationController.BiometricsState!

    controller
      .biometricStatePublisher()
      .sink { state in
        result = state
      }
      .store(in: cancellables)

    XCTAssertEqual(result, .unavailable)
  }

  func test_biometricStatePublisher_publishesFaceID_whenAvailableBiometricsIsFaceIDAndAccountUsesIt() {
    features.use(networkClient)
    accounts.storedAccounts = always([accountWithBiometry.account])
    features.use(accounts)
    features.use(accountSession)
    biometry.biometricsStatePublisher = always(Just(.configuredFaceID).eraseToAnyPublisher())
    features.use(biometry)
    accountSettings.accountWithProfile = always(accountWithBiometry)
    accountSettings.updatedAccountIDsPublisher = always(Empty<Account.LocalID, Never>().eraseToAnyPublisher())
    features.use(accountSettings)

    let controller: AuthorizationController = testInstance(
      context: accountWithBiometry.account
    )
    var result: AuthorizationController.BiometricsState!

    controller
      .biometricStatePublisher()
      .sink { state in
        result = state
      }
      .store(in: cancellables)

    XCTAssertEqual(result, .faceID)
  }

  func test_biometricStatePublisher_publishesTouchID_whenAvailableBiometricsIsTouchIDAndAccountUsesIt() {
    features.use(networkClient)
    accounts.storedAccounts = always([accountWithBiometry.account])
    features.use(accounts)
    features.use(accountSession)
    biometry.biometricsStatePublisher = always(Just(.configuredFaceID).eraseToAnyPublisher())
    features.use(biometry)
    accountSettings.accountWithProfile = always(accountWithBiometry)
    accountSettings.updatedAccountIDsPublisher = always(Empty<Account.LocalID, Never>().eraseToAnyPublisher())
    features.use(accountSettings)

    let controller: AuthorizationController = testInstance(
      context: accountWithBiometry.account
    )
    var result: AuthorizationController.BiometricsState!

    controller
      .biometricStatePublisher()
      .sink { state in
        result = state
      }
      .store(in: cancellables)

    XCTAssertEqual(result, .faceID)
  }
}

private let accountWithoutBiometry: AccountWithProfile = .init(
  localID: "localID",
  userID: "userID",
  domain: "passbolt.com",
  label: "passbolt",
  username: "username",
  firstName: "Adam",
  lastName: "Smith",
  avatarImageURL: "",
  fingerprint: "FINGERPRINT",
  biometricsEnabled: false
)

private let accountWithBiometry: AccountWithProfile = .init(
  localID: "localID",
  userID: "userID",
  domain: "passbolt.com",
  label: "passbolt",
  username: "username",
  firstName: "Adam",
  lastName: "Smith",
  avatarImageURL: "",
  fingerprint: "FINGERPRINT",
  biometricsEnabled: true
)
