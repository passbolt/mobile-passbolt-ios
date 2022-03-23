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
@MainActor
final class AuthorizationScreenTests: MainActorTestCase {

  var accounts: Accounts!
  var accountSession: AccountSession!
  var accountSettings: AccountSettings!
  var networkClient: NetworkClient!
  var biometry: Biometry!

  override func mainActorSetUp() {
    accounts = .placeholder
    accountSession = .placeholder
    networkClient = .placeholder
    accountSettings = .placeholder
    biometry = .placeholder
  }

  override func mainActorTearDown() {
    accounts = nil
    accountSession = nil
    networkClient = nil
    accountSettings = nil
    biometry = nil
  }

  func test_presentForgotPassphraseAlertPublisher_publishesTrue_whenPresentForgotPassphraseAlertCalled() async throws {
    await features.use(networkClient)
    accounts.storedAccounts = always([accountWithBiometry.account])
    await features.use(accounts)
    await features.use(accountSession)
    await features.use(biometry)
    accountSettings.accountWithProfile = always(accountWithBiometry)
    accountSettings.updatedAccountIDsPublisher = always(Empty<Account.LocalID, Never>().eraseToAnyPublisher())
    await features.use(accountSettings)

    let controller: AuthorizationController = try await testController(
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

  func test_validatedPassphrasePublisher_publishesValidatedPassphrase_whenUpdatePassphraseCalled() async throws {
    await features.use(networkClient)
    accounts.storedAccounts = always([accountWithBiometry.account])
    await features.use(accounts)
    await features.use(accountSession)
    await features.use(biometry)
    accountSettings.accountWithProfile = always(accountWithBiometry)
    accountSettings.updatedAccountIDsPublisher = always(Empty<Account.LocalID, Never>().eraseToAnyPublisher())
    await features.use(accountSettings)

    let controller: AuthorizationController = try await testController(
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

  func test_signIn_succeeds_whenAuthorizationSucceeds() async throws {
    await features.use(networkClient)
    accounts.storedAccounts = always([accountWithBiometry.account])
    await features.use(accounts)
    accountSession.authorize = always(false)
    await features.use(accountSession)
    await features.use(biometry)
    accountSettings.accountWithProfile = always(accountWithBiometry)
    accountSettings.updatedAccountIDsPublisher = always(Empty<Account.LocalID, Never>().eraseToAnyPublisher())
    await features.use(accountSettings)

    let controller: AuthorizationController = try await testController(
      context: accountWithBiometry.account
    )
    let result: Bool? =
      try? await controller
      .signIn()
      .asAsyncValue()

    XCTAssertNotNil(result)
  }

  func test_signIn_fails_whenAuthorizationFails() async throws {
    await features.use(networkClient)
    accounts.storedAccounts = always([accountWithBiometry.account])
    await features.use(accounts)
    accountSession.authorize = alwaysThrow(
      MockIssue.error()
    )
    await features.use(accountSession)
    await features.use(biometry)
    accountSettings.accountWithProfile = always(accountWithBiometry)
    accountSettings.updatedAccountIDsPublisher = always(Empty<Account.LocalID, Never>().eraseToAnyPublisher())
    await features.use(accountSettings)

    let controller: AuthorizationController = try await testController(
      context: accountWithBiometry.account
    )
    var result: Error?
    do {
      _ =
        try await controller
        .signIn()
        .asAsyncValue()
      XCTFail()
    }
    catch {
      result = error
    }

    XCTAssertError(result, matches: MockIssue.self)
  }

  func test_biometricSignIn_succeeds_whenAuthorizationSucceeds() async throws {
    await features.use(networkClient)
    accounts.storedAccounts = always([accountWithBiometry.account])
    await features.use(accounts)
    accountSession.authorize = always(false)
    await features.use(accountSession)
    await features.use(biometry)
    accountSettings.accountWithProfile = always(accountWithBiometry)
    accountSettings.updatedAccountIDsPublisher = always(Empty<Account.LocalID, Never>().eraseToAnyPublisher())
    await features.use(accountSettings)

    let controller: AuthorizationController = try await testController(
      context: accountWithBiometry.account
    )
    let result: Bool? =
      try? await controller
      .biometricSignIn()
      .asAsyncValue()

    XCTAssertNotNil(result)
  }

  func test_biometricSignIn_fails_whenAuthorizationFails() async throws {
    await features.use(networkClient)
    accounts.storedAccounts = always([accountWithBiometry.account])
    await features.use(accounts)
    accountSession.authorize = alwaysThrow(
      MockIssue.error()
    )
    await features.use(accountSession)
    await features.use(biometry)
    accountSettings.accountWithProfile = always(accountWithBiometry)
    accountSettings.updatedAccountIDsPublisher = always(Empty<Account.LocalID, Never>().eraseToAnyPublisher())
    await features.use(accountSettings)

    let controller: AuthorizationController = try await testController(
      context: accountWithBiometry.account
    )
    var result: Error?
    do {
      _ =
        try await controller
        .biometricSignIn()
        .asAsyncValue()
      XCTFail()
    }
    catch {
      result = error
    }

    XCTAssertError(result, matches: MockIssue.self)
  }

  func test_avatarPublisher_publishesData_whenNetworkRequestSucceeds() async throws {
    let testData: Data = .init([0x01, 0x02])
    networkClient.mediaDownload = .respondingWith(testData)
    await features.use(networkClient)
    accounts.storedAccounts = always([accountWithBiometry.account])
    await features.use(accounts)
    accountSession.authorize = always(false)
    await features.use(accountSession)
    await features.use(biometry)
    accountSettings.accountWithProfile = always(accountWithBiometry)
    accountSettings.updatedAccountIDsPublisher = always(Empty<Account.LocalID, Never>().eraseToAnyPublisher())
    await features.use(accountSettings)

    let controller: AuthorizationController = try await testController(
      context: accountWithBiometry.account
    )
    let result: Data? =
      try? await controller
      .accountAvatarPublisher()
      .asAsyncValue()

    XCTAssertEqual(result, testData)
  }

  func test_avatarPublisher_publishesNil_whenNetworkRequestFails() async throws {
    networkClient.mediaDownload = .failingWith(MockIssue.error())
    await features.use(networkClient)
    accounts.storedAccounts = always([accountWithBiometry.account])
    await features.use(accounts)
    accountSession.authorize = always(false)
    await features.use(accountSession)
    await features.use(biometry)
    accountSettings.accountWithProfile = always(accountWithBiometry)
    accountSettings.updatedAccountIDsPublisher = always(Empty<Account.LocalID, Never>().eraseToAnyPublisher())
    await features.use(accountSettings)

    let controller: AuthorizationController = try await testController(
      context: accountWithBiometry.account
    )
    let result: Data? =
      try? await controller
      .accountAvatarPublisher()
      .asAsyncValue()

    XCTAssertNil(result)
  }

  func test_biometricStatePublisher_publishesUnavailable_whenBiometricsIsUnavailable() async throws {
    await features.use(networkClient)
    accounts.storedAccounts = always([accountWithBiometry.account])
    await features.use(accounts)
    await features.use(accountSession)
    biometry.biometricsStatePublisher = always(Just(.unavailable).eraseToAnyPublisher())
    await features.use(biometry)
    accountSettings.accountWithProfile = always(accountWithBiometry)
    accountSettings.updatedAccountIDsPublisher = always(Empty<Account.LocalID, Never>().eraseToAnyPublisher())
    await features.use(accountSettings)

    let controller: AuthorizationController = try await testController(
      context: accountWithBiometry.account
    )
    let result: AuthorizationController.BiometricsState? =
      try? await controller
      .biometricStatePublisher()
      .asAsyncValue()

    XCTAssertEqual(result, .unavailable)
  }

  func test_biometricStatePublisher_publishesUnavailable_whenBiometricsIsAvailableAndAccountDoesNotUseIt() async throws
  {
    await features.use(networkClient)
    accounts.storedAccounts = always([accountWithoutBiometry.account])
    await features.use(accounts)
    await features.use(accountSession)
    biometry.biometricsStatePublisher = always(Just(.configuredFaceID).eraseToAnyPublisher())
    await features.use(biometry)
    accountSettings.accountWithProfile = always(accountWithoutBiometry)
    accountSettings.updatedAccountIDsPublisher = always(Empty<Account.LocalID, Never>().eraseToAnyPublisher())
    await features.use(accountSettings)

    let controller: AuthorizationController = try await testController(
      context: accountWithoutBiometry.account
    )
    let result: AuthorizationController.BiometricsState? =
      try? await controller
      .biometricStatePublisher()
      .asAsyncValue()

    XCTAssertEqual(result, .unavailable)
  }

  func test_biometricStatePublisher_publishesFaceID_whenAvailableBiometricsIsFaceIDAndAccountUsesIt() async throws {
    await features.use(networkClient)
    accounts.storedAccounts = always([accountWithBiometry.account])
    await features.use(accounts)
    await features.use(accountSession)
    biometry.biometricsStatePublisher = always(Just(.configuredFaceID).eraseToAnyPublisher())
    await features.use(biometry)
    accountSettings.accountWithProfile = always(accountWithBiometry)
    accountSettings.updatedAccountIDsPublisher = always(Empty<Account.LocalID, Never>().eraseToAnyPublisher())
    await features.use(accountSettings)

    let controller: AuthorizationController = try await testController(
      context: accountWithBiometry.account
    )
    let result: AuthorizationController.BiometricsState? =
      try? await controller
      .biometricStatePublisher()
      .asAsyncValue()

    XCTAssertEqual(result, .faceID)
  }

  func test_biometricStatePublisher_publishesTouchID_whenAvailableBiometricsIsTouchIDAndAccountUsesIt() async throws {
    await features.use(networkClient)
    accounts.storedAccounts = always([accountWithBiometry.account])
    await features.use(accounts)
    await features.use(accountSession)
    biometry.biometricsStatePublisher = always(Just(.configuredFaceID).eraseToAnyPublisher())
    await features.use(biometry)
    accountSettings.accountWithProfile = always(accountWithBiometry)
    accountSettings.updatedAccountIDsPublisher = always(Empty<Account.LocalID, Never>().eraseToAnyPublisher())
    await features.use(accountSettings)

    let controller: AuthorizationController = try await testController(
      context: accountWithBiometry.account
    )
    let result: AuthorizationController.BiometricsState? =
      try? await controller
      .biometricStatePublisher()
      .asAsyncValue()

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
