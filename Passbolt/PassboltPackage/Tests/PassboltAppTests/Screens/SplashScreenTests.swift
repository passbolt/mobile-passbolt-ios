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
import Features
import NetworkClient
import TestExtensions
import UIComponents
import XCTest

@testable import Accounts
@testable import PassboltApp

// swift-format-ignore: AlwaysUseLowerCamelCase, NeverUseImplicitlyUnwrappedOptionals
final class SplashScreenTests: TestCase {

  var accountDataStore: AccountsDataStore!
  var networkClient: NetworkClient!
  var accounts: Accounts!
  var accountSession: AccountSession!
  var featureConfig: FeatureConfig!

  override func setUp() {
    super.setUp()
    accountDataStore = .placeholder
    networkClient = .placeholder
    accounts = .placeholder
    accountSession = .placeholder
    featureConfig = .placeholder
  }

  override func tearDown() {
    accountDataStore = nil
    networkClient = nil
    accounts = nil
    accountSession = nil
    featureConfig = nil
    super.tearDown()
  }

  func test_navigateToDiagnostics_whenDataIntegrityCheckFails() {
    features.usePlaceholder(for: UpdateCheck.self)
    accountDataStore.loadLastUsedAccount = always(nil)
    features.use(accountDataStore)
    features.use(networkClient)
    accountSession.statePublisher = always(Just(.none(lastUsed: nil)).eraseToAnyPublisher())
    features.use(accountSession)
    accounts.verifyStorageDataIntegrity = always(.failure(.testError()))
    features.use(accounts)
    featureConfig.fetchIfNeeded = always(
      Just(Void()).setFailureType(to: TheErrorLegacy.self).eraseToAnyPublisher()
    )
    features.use(featureConfig)

    let controller: SplashScreenController = testInstance()
    var result: SplashScreenController.Destination!

    controller.navigationDestinationPublisher()
      .sink { destination in
        result = destination
      }
      .store(in: cancellables)

    XCTAssertEqual(result, .diagnostics)
  }

  func test_navigateToAccountSetup_whenNoStoredAccounts() {
    features.usePlaceholder(for: UpdateCheck.self)
    accountDataStore.loadLastUsedAccount = always(nil)
    features.use(accountDataStore)
    features.use(networkClient)
    accountSession.statePublisher = always(Just(.none(lastUsed: nil)).eraseToAnyPublisher())
    features.use(accountSession)
    accounts.verifyStorageDataIntegrity = always(.success(()))
    accounts.storedAccounts = always([])
    features.use(accounts)
    featureConfig.fetchIfNeeded = always(
      Just(Void()).setFailureType(to: TheErrorLegacy.self).eraseToAnyPublisher()
    )
    features.use(featureConfig)

    let controller: SplashScreenController = testInstance()
    var result: SplashScreenController.Destination!

    controller.navigationDestinationPublisher()
      .sink { destination in
        result = destination
      }
      .store(in: cancellables)

    XCTAssertEqual(result, .accountSetup)
  }

  func test_navigateToAccountSelection_whenStoredAccountsPresent_withLastUsedAccount_andNotAuthorized() {
    features.usePlaceholder(for: UpdateCheck.self)
    accountDataStore.loadLastUsedAccount = always(account)
    features.use(accountDataStore)
    features.use(networkClient)
    accountSession.statePublisher = always(Just(.none(lastUsed: account)).eraseToAnyPublisher())
    features.use(accountSession)
    accounts.verifyStorageDataIntegrity = always(.success(()))
    accounts.storedAccounts = always([account])
    features.use(accounts)
    featureConfig.fetchIfNeeded = always(
      Just(Void()).setFailureType(to: TheErrorLegacy.self).eraseToAnyPublisher()
    )
    features.use(featureConfig)

    let controller: SplashScreenController = testInstance()
    var result: SplashScreenController.Destination!

    controller.navigationDestinationPublisher()
      .sink { destination in
        result = destination
      }
      .store(in: cancellables)

    XCTAssertEqual(result, .accountSelection(account, message: nil))
  }

  func test_navigateToAccountSelection_whenStoredAccountsPresent_withoutLastUsedAccount_andNotAuthorized() {
    features.usePlaceholder(for: UpdateCheck.self)
    accountDataStore.loadLastUsedAccount = always(account)
    features.use(accountDataStore)
    features.use(networkClient)
    accountSession.statePublisher = always(Just(.none(lastUsed: nil)).eraseToAnyPublisher())
    features.use(accountSession)
    accounts.verifyStorageDataIntegrity = always(.success(()))
    accounts.storedAccounts = always([account])
    features.use(accounts)
    featureConfig.fetchIfNeeded = always(
      Just(Void()).setFailureType(to: TheErrorLegacy.self).eraseToAnyPublisher()
    )
    features.use(featureConfig)

    let controller: SplashScreenController = testInstance()
    var result: SplashScreenController.Destination!

    controller.navigationDestinationPublisher()
      .sink { destination in
        result = destination
      }
      .store(in: cancellables)

    XCTAssertEqual(result, .accountSelection(nil, message: nil))
  }

  func test_navigateToHome_whenAuthorized_andFeatureFlagsDownloadSucceeds() {
    features.usePlaceholder(for: UpdateCheck.self)
    accountDataStore.loadLastUsedAccount = always(account)
    features.use(accountDataStore)
    features.use(networkClient)
    accountSession.statePublisher = always(Just(.authorized(account)).eraseToAnyPublisher())
    features.use(accountSession)
    accounts.verifyStorageDataIntegrity = always(.success(()))
    accounts.storedAccounts = always([account])
    features.use(accounts)
    featureConfig.fetchIfNeeded = always(
      Just(Void()).setFailureType(to: TheErrorLegacy.self).eraseToAnyPublisher()
    )
    features.use(featureConfig)

    let controller: SplashScreenController = testInstance()
    var result: SplashScreenController.Destination!

    controller.navigationDestinationPublisher()
      .sink { destination in
        result = destination
      }
      .store(in: cancellables)

    XCTAssertEqual(result, .home)
  }

  func test_navigateToFeatureFlagsFetchError_whenAuthorized_andFeatureFlagsDownloadFails() {
    features.usePlaceholder(for: UpdateCheck.self)
    accountDataStore.loadLastUsedAccount = always(account)
    features.use(accountDataStore)
    features.use(networkClient)
    accountSession.statePublisher = always(Just(.authorized(account)).eraseToAnyPublisher())
    features.use(accountSession)
    accounts.verifyStorageDataIntegrity = always(.success(()))
    accounts.storedAccounts = always([account])
    features.use(accounts)
    featureConfig.fetchIfNeeded = always(
      Fail<Void, TheErrorLegacy>(error: .testError()).eraseToAnyPublisher()
    )
    features.use(featureConfig)

    let controller: SplashScreenController = testInstance()
    var result: SplashScreenController.Destination!

    controller.navigationDestinationPublisher()
      .sink { destination in
        result = destination
      }
      .store(in: cancellables)

    XCTAssertEqual(result, .featureConfigFetchError)
  }

  func test_navigationDestinationPublisher_publishesHome_whenRetryFetchConfigurationSucceeds() {
    features.usePlaceholder(for: UpdateCheck.self)
    accountDataStore.loadLastUsedAccount = always(account)
    features.use(accountDataStore)
    features.use(networkClient)
    accountSession.statePublisher = always(Just(.authorized(account)).eraseToAnyPublisher())
    features.use(accountSession)
    accounts.verifyStorageDataIntegrity = always(.success(()))
    accounts.storedAccounts = always([account])
    features.use(accounts)

    var index: Int = 0
    featureConfig.fetchIfNeeded = {
      guard index > 0 else {
        index += 1
        return Fail(error: .testError()).eraseToAnyPublisher()
      }

      return Just(Void()).setFailureType(to: TheErrorLegacy.self).eraseToAnyPublisher()
    }

    features.use(featureConfig)

    let controller: SplashScreenController = testInstance()
    var destination: SplashScreenController.Destination!

    controller.navigationDestinationPublisher()
      .sink { value in
        destination = value
      }
      .store(in: cancellables)

    controller.retryFetchConfiguration()
      .sink(
        receiveCompletion: { _ in },
        receiveValue: { _ in }
      )
      .store(in: cancellables)

    XCTAssertEqual(destination, .home)
  }

  func test_navigationDestinationPublisher_doesNotPublish_whenRetryFetchConfigurationFails() {
    features.usePlaceholder(for: UpdateCheck.self)
    accountDataStore.loadLastUsedAccount = always(account)
    features.use(accountDataStore)
    features.use(networkClient)
    accountSession.statePublisher = always(Just(.authorized(account)).eraseToAnyPublisher())
    features.use(accountSession)
    accounts.verifyStorageDataIntegrity = always(.success(()))
    accounts.storedAccounts = always([account])
    features.use(accounts)

    featureConfig.fetchIfNeeded = always(
      Fail(error: .testError()).eraseToAnyPublisher()
    )

    features.use(featureConfig)

    let controller: SplashScreenController = testInstance()
    var result: SplashScreenController.Destination!

    controller.navigationDestinationPublisher()
      .sink { value in
        result = value
      }
      .store(in: cancellables)

    controller.retryFetchConfiguration()
      .sink(
        receiveCompletion: { _ in },
        receiveValue: { _ in }
      )
      .store(in: cancellables)

    XCTAssertEqual(result, .featureConfigFetchError)
  }
}

private let accountWithProfile: AccountWithProfile = .init(
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

private let account: Account = .init(
  localID: accountWithProfile.localID,
  domain: accountWithProfile.domain,
  userID: accountWithProfile.userID,
  fingerprint: accountWithProfile.fingerprint
)
