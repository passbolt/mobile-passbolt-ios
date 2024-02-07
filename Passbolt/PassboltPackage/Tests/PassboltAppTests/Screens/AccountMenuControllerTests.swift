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

import FeatureScopes
import TestExtensions
import UIComponents
import XCTest

@testable import Accounts
@testable import PassboltApp

// swift-format-ignore: AlwaysUseLowerCamelCase, NeverUseImplicitlyUnwrappedOptionals
@MainActor
final class AccountMenuControllerTests: MainActorTestCase {

  var accountUpdates: Updates!

  override func mainActorSetUp() {
    accountUpdates = .init()
    features.usePlaceholder(for: Session.self)
    features.patch(
      \Accounts.updates,
      with: accountUpdates.asAnyUpdatable()
    )
    features.patch(
      \Accounts.storedAccounts,
      with: always(
        []
      )
    )
    features.patch(
      \Session.currentAccount,
      with: always(.mock_ada)
    )
    features.set(
      SessionScope.self,
      context: .init(
        account: .mock_ada,
        configuration: .mock_default
      )
    )
    features.patch(
      \AccountDetails.profile,
      with: always(.mock_ada)
    )
    self.features
      .patch(
        \NavigationToAccountMenu.mockRevert,
        with: always(Void())
      )
  }

  override func mainActorTearDown() {
    accountUpdates = .none
  }

  func test_currentAccountWithProfile_isEqualToProvidedInContext() async throws {
    let controller: AccountMenuController = try testController()

    XCTAssertEqual(controller.currentAccountWithProfile, .mock_ada)
  }

  func test_accountsListPublisher_publishesAccountListWithoutCurrentAccount() async throws {
    features.patch(
      \Accounts.storedAccounts,
      with: always(
        [.mock_ada, .mock_frances]
      )
    )
    let controller: AccountMenuController = try await testController()

    var result:
      Array<
        (
          accountWithProfile: AccountWithProfile,
          avatarImagePublisher: AnyPublisher<Data?, Never>
        )
      >?
    controller
      .accountsListPublisher()
      .sink { accounts in
        result = accounts
      }
      .store(in: cancellables)

    // temporary wait for detached tasks
    try await Task.sleep(nanoseconds: 300 * NSEC_PER_MSEC)

    XCTAssertEqual(result?.map { $0.accountWithProfile }, [.mock_frances])
  }

  func test_accountsListPublisher_publishesUpdatedAccountListAterUpdatingAccounts() async throws {
    var storedAccounts: Array<AccountWithProfile> = [.mock_ada]
    features.patch(
      \Accounts.storedAccounts,
      with: always(storedAccounts)
    )

    let controller: AccountMenuController = try await testController()

    storedAccounts = [.mock_ada, .mock_frances]
    accountUpdates.update()

    // temporary wait for detached tasks
    try await Task.sleep(nanoseconds: 300 * NSEC_PER_MSEC)

    let result:
      Array<
        (
          accountWithProfile: AccountWithProfile,
          avatarImagePublisher: AnyPublisher<Data?, Never>
        )
      >? =
        try? await controller
        .accountsListPublisher()
        .asAsyncValue()

    XCTAssertEqual(result?.map { $0.accountWithProfile }, [.mock_frances])
  }

  func test_presentAccountDetails_navigatesToAccountDetails() async throws {
    let result: UnsafeSendable<Void> = .init(.none)
    self.features
      .patch(
        \NavigationToAccountDetails.mockPerform,
        with: { _, _ async throws -> Void in
          result.value = Void()
        }
      )

    let controller: AccountMenuController = try testController()

    try await controller.presentAccountDetails()

    XCTAssertNotNil(result.value)
  }

  func test_presentAccountSwitch_performsAccountAuthorization() async throws {
    let result: UnsafeSendable<Account> = .init(.none)
    self.features
      .patch(
        \NavigationToAuthorization.mockPerform,
        with: { _, account async throws -> Void in
          result.value = account
        }
      )

    let controller: AccountMenuController = try testController()

    try await controller.presentAccountSwitch(.mock_frances)

    XCTAssertEqual(result.value, .mock_frances)
  }

  func test_presentManageAccounts_performsNavigationToManageAccounts() async throws {
    let result: UnsafeSendable<Void> = .init(.none)
    self.features
      .patch(
        \NavigationToManageAccounts.mockPerform,
        with: { _, account async throws -> Void in
          result.value = account
        }
      )
    features.patch(
      \AccountDetails.profile,
      with: always(.mock_ada)
    )

    let controller: AccountMenuController = try await testController()

    try await controller.presentManageAccounts()

    XCTAssertNotNil(result.value)
  }

  func test_signOut_closesCurrentSession() async throws {
    let result: UnsafeSendable<Void> = .init()
    features.patch(
      \Session.close,
      with: { _ in
        result.value = Void()
      }
    )
    let controller: AccountMenuController = try await testController()

    try await controller.signOut()
    // temporary wait for detached tasks, to be removed
    try await Task.sleep(nanoseconds: 300 * NSEC_PER_MSEC)
    XCTAssertNotNil(result.value)
  }
}
