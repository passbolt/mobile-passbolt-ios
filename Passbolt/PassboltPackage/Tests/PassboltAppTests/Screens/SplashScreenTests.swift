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
import Features
import SessionData
import TestExtensions
import UIComponents
import XCTest

@testable import Accounts
@testable import PassboltApp

// swift-format-ignore: AlwaysUseLowerCamelCase, NeverUseImplicitlyUnwrappedOptionals
@MainActor
final class SplashScreenTests: MainActorTestCase {

  var updates: UpdatesSequenceSource!

  override func mainActorSetUp() {
    updates = .init()
    features.patch(
      \Session.updatesSequence,
      with: updates.updatesSequence
    )
    features.patch(
      \Session.currentAccount,
      with: always(Account.valid)
    )
    features.patch(
      \Session.pendingAuthorization,
      with: always(.none)
    )
    features.usePlaceholder(for: UpdateCheck.self)
    features.patch(
      \SessionConfiguration.configuration,
      with: always(.none)
    )
    features.patch(
      \SessionConfiguration.fetchIfNeeded,
      with: always(Void())
    )
    features.patch(
      \Accounts.verifyDataIntegrity,
      with: always(Void())
    )
    features.patch(
      \Accounts.storedAccounts,
      with: always([Account.valid])
    )
  }

  override func mainActorTearDown() {
    updates = .none
  }

  func test_navigateToDiagnostics_whenDataIntegrityCheckFails() async throws {
    features.patch(
      \Accounts.verifyDataIntegrity,
      with: alwaysThrow(MockIssue.error())
    )

    let controller: SplashScreenController = try await testController(context: .none)
    var result: SplashScreenController.Destination?

    controller.navigationDestinationPublisher()
      .sink { destination in
        result = destination
      }
      .store(in: cancellables)

    // temporary wait for detached tasks
    try await Task.sleep(nanoseconds: 300 * NSEC_PER_MSEC)

    XCTAssertEqual(result, .diagnostics)
  }

  func test_navigateToAccountSetup_whenNoStoredAccounts() async throws {
    features.patch(
      \Accounts.storedAccounts,
      with: always([])
    )

    let controller: SplashScreenController = try await testController(context: .none)
    var result: SplashScreenController.Destination!

    controller.navigationDestinationPublisher()
      .sink { destination in
        result = destination
      }
      .store(in: cancellables)

    // temporary wait for detached tasks
    try await Task.sleep(nanoseconds: 300 * NSEC_PER_MSEC)

    XCTAssertEqual(result, .accountSetup)
  }

  func test_navigateToAccountSelection_whenStoredAccountsPresent_withAccount_andNotAuthorized() async throws {
    features.patch(
      \Accounts.storedAccounts,
      with: always([Account.valid])
    )
    features.patch(
      \Session.currentAccount,
      with: alwaysThrow(SessionMissing.error())
    )

    let controller: SplashScreenController = try await testController(context: Account.valid)

    var result: SplashScreenController.Destination?

    controller.navigationDestinationPublisher()
      .sink { destination in
        result = destination
      }
      .store(in: cancellables)

    // temporary wait for detached tasks
    try await Task.sleep(nanoseconds: 300 * NSEC_PER_MSEC)

    XCTAssertEqual(result, .accountSelection(Account.valid, message: nil))
  }

  func test_navigateToAccountSelection_whenStoredAccountsPresent_withoutLastUsedAccount_andNotAuthorized() async throws
  {
    features.patch(
      \Accounts.storedAccounts,
      with: always([Account.valid])
    )
    features.patch(
      \Session.currentAccount,
      with: alwaysThrow(SessionMissing.error())
    )

    let controller: SplashScreenController = try await testController(context: .none)
    var result: SplashScreenController.Destination?

    controller.navigationDestinationPublisher()
      .sink { destination in
        result = destination
      }
      .store(in: cancellables)

    // temporary wait for detached tasks
    try await Task.sleep(nanoseconds: 300 * NSEC_PER_MSEC)

    XCTAssertEqual(result, .accountSelection(nil, message: nil))
  }

  func test_navigateToHome_whenAuthorized_andFeatureFlagsDownloadSucceeds() async throws {
    features.patch(
      \Session.currentAccount,
      with: always(Account.valid)
    )
    features.patch(
      \SessionConfiguration.fetchIfNeeded,
      with: always(Void())
    )

    let controller: SplashScreenController = try await testController(context: .none)
    var result: SplashScreenController.Destination!

    controller.navigationDestinationPublisher()
      .sink { destination in
        result = destination
      }
      .store(in: cancellables)

    // temporary wait for detached tasks
    try await Task.sleep(nanoseconds: 300 * NSEC_PER_MSEC)

    XCTAssertEqual(result, .home)
  }

  func test_navigateToFeatureFlagsFetchError_whenAuthorized_andFeatureFlagsDownloadFails() async throws {
    features.patch(
      \Session.currentAccount,
      with: always(Account.valid)
    )
    features.patch(
      \SessionConfiguration.fetchIfNeeded,
      with: alwaysThrow(MockIssue.error())
    )

    let controller: SplashScreenController = try await testController(context: .none)
    var result: SplashScreenController.Destination?

    controller.navigationDestinationPublisher()
      .sink { destination in
        result = destination
      }
      .store(in: cancellables)

    // temporary wait for detached tasks
    try await Task.sleep(nanoseconds: 300 * NSEC_PER_MSEC)

    XCTAssertEqual(result, .featureConfigFetchError)
  }

  func test_navigationDestinationPublisher_publishesHome_whenRetryFetchConfigurationSucceeds() async throws {
    features.patch(
      \Session.currentAccount,
      with: always(Account.valid)
    )
    let uncheckedSendableIndex: UncheckedSendable<Int> = .init(0)
    features.patch(
      \SessionConfiguration.fetchIfNeeded,
      with: {
        guard uncheckedSendableIndex.variable > 0 else {
          uncheckedSendableIndex.variable += 1
          throw MockIssue.error()
        }

        return Void()
      }
    )

    let controller: SplashScreenController = try await testController(context: .none)
    var destination: SplashScreenController.Destination!

    controller.navigationDestinationPublisher()
      .sink { value in
        destination = value
      }
      .store(in: cancellables)

    try? await controller.retryFetchConfiguration()

    // temporary wait for detached tasks
    try await Task.sleep(nanoseconds: 300 * NSEC_PER_MSEC)

    XCTAssertEqual(destination, .home)
  }

  func test_navigationDestinationPublisher_doesNotPublish_whenRetryFetchConfigurationFails() async throws {
    features.patch(
      \Session.currentAccount,
      with: always(Account.valid)
    )
    features.patch(
      \SessionConfiguration.fetchIfNeeded,
      with: alwaysThrow(MockIssue.error())
    )

    let controller: SplashScreenController = try await testController(context: .none)
    var result: SplashScreenController.Destination!

    controller.navigationDestinationPublisher()
      .sink { value in
        result = value
      }
      .store(in: cancellables)

    try? await controller.retryFetchConfiguration()

    // temporary wait for detached tasks
    try await Task.sleep(nanoseconds: 300 * NSEC_PER_MSEC)

    XCTAssertEqual(result, .featureConfigFetchError)
  }
}
