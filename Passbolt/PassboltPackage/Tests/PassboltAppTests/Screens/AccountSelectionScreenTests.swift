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

import AccountSetup
import Combine
import Features
import SharedUIComponents
import TestExtensions
import UIComponents
import XCTest

@testable import Accounts
@testable import PassboltApp

// swift-format-ignore: AlwaysUseLowerCamelCase, NeverUseImplicitlyUnwrappedOptionals
@MainActor
final class AccountSelectionScreenTests: MainActorTestCase {

  var accountsUpdates: UpdatesSequenceSource!

  override func mainActorSetUp() {
    accountsUpdates = .init()
    features.patch(
      \Accounts.updates,
      with: accountsUpdates.updatesSequence
    )
    features.patch(
      \Session.currentAccount,
      with: always(Account.mock_ada)
    )
    features.patch(
      \Accounts.storedAccounts,
      with: always([
        Account.mock_ada, Account.mock_frances,
      ])
    )
    features.patch(
      \AccountDetails.profile,
      context: Account.mock_ada,
      with: always(AccountWithProfile.mock_ada)
    )
    features.patch(
      \AccountDetails.avatarImage,
      context: Account.mock_ada,
      with: always(.init())
    )
    features.patch(
      \AccountDetails.profile,
      context: Account.mock_frances,
      with: always(AccountWithProfile.mock_frances)
    )
    features.patch(
      \AccountDetails.avatarImage,
      context: Account.mock_frances,
      with: always(.init())
    )
  }

  override func mainActorTearDown() {
    accountsUpdates = .none
  }

  func test_accountsPublisher_publishesItemsWithImage_inSelectionMode() async throws {
    features.patch(
      \AccountDetails.avatarImage,
      context: Account.mock_ada,
      with: always(.init())
    )
    features.patch(
      \AccountDetails.avatarImage,
      context: Account.mock_frances,
      with: always(.init())
    )

    let controller: AccountSelectionController = try await testController(context: .init(value: false))
    var result: Array<AccountSelectionListItem> = []

    controller.accountsPublisher()
      .sink { items in
        result = items
      }
      .store(in: cancellables)

    // temporary wait for detached tasks
    try await Task.sleep(nanoseconds: 300 * NSEC_PER_MSEC)

    let accountItems: Array<AccountSelectionCellItem> = result.compactMap {
      guard case let .account(cellItem) = $0 else {
        return nil
      }
      return cellItem
    }

    let imageData: Data? =
      try await accountItems.first?
      .imagePublisher?
      .asAsyncValue()

    let accounts: Array<Account> = accountItems.map(\.account)

    XCTAssertTrue(accounts.contains(Account.mock_ada))
    XCTAssertTrue(accounts.contains(Account.mock_frances))
    XCTAssertTrue(result.contains(.addAccount(.default)))
    XCTAssertNotNil(imageData)
  }

  func test_accountsPublisher_publishesItemsWithoutImage_inSelectionMode() async throws {
    features.patch(
      \AccountDetails.avatarImage,
      context: Account.mock_ada,
      with: alwaysThrow(MockIssue.error())
    )
    features.patch(
      \AccountDetails.avatarImage,
      context: Account.mock_frances,
      with: alwaysThrow(MockIssue.error())
    )

    let controller: AccountSelectionController = try await testController(context: .init(value: false))
    var result: Array<AccountSelectionListItem> = []
    var imageData: Data?

    controller.accountsPublisher()
      .sink { items in
        result = items
      }
      .store(in: cancellables)

    // temporary wait for detached tasks
    try await Task.sleep(nanoseconds: 300 * NSEC_PER_MSEC)

    let accountItems: Array<AccountSelectionCellItem> = result.compactMap {
      guard case let .account(cellItem) = $0 else {
        return nil
      }
      return cellItem
    }

    accountItems.first?
      .imagePublisher?
      .sink { data in
        imageData = data
      }
      .store(in: cancellables)

    // temporary wait for detached tasks
    try await Task.sleep(nanoseconds: 300 * NSEC_PER_MSEC)

    let accounts: Array<Account> = accountItems.map(\.account)

    XCTAssertTrue(accounts.contains(Account.mock_ada))
    XCTAssertTrue(accounts.contains(Account.mock_frances))
    XCTAssertTrue(result.contains(.addAccount(.default)))
    XCTAssertNil(imageData)
  }

  func test_accountsPublisher_publishes_withoutAddAccountItem_inRemovalMode() async throws {

    let controller: AccountSelectionController = try await testController(context: .init(value: false))
    controller.toggleMode()

    var result: Array<AccountSelectionListItem> = []

    controller.accountsPublisher()
      .sink { items in
        result = items
      }
      .store(in: cancellables)

    // temporary wait for detached tasks
    try await Task.sleep(nanoseconds: 300 * NSEC_PER_MSEC)

    let accounts: Array<Account> = result.compactMap {
      guard case let .account(cellItem) = $0 else {
        return nil
      }
      return cellItem.account
    }

    XCTAssertTrue(accounts.contains(Account.mock_ada))
    XCTAssertTrue(accounts.contains(Account.mock_frances))
    XCTAssertFalse(result.contains(.addAccount(.default)))
  }

  func test_accountsPublisher_publishesEmptyList_whenAccountsEmpty() async throws {
    features.patch(
      \Accounts.storedAccounts,
      with: always([])
    )

    let controller: AccountSelectionController = try await testController(context: .init(value: false))
    var result: Array<AccountSelectionListItem> = []

    controller.accountsPublisher()
      .sink { items in
        result = items
      }
      .store(in: cancellables)

    XCTAssertTrue(result.isEmpty)
  }

  func test_removeStoredAccount_Succeeds() async throws {
    var storedAccounts: Array<Account> = [Account.mock_ada, Account.mock_frances]
    let uncheckedSendableStoredAccounts: UncheckedSendable<Array<Account>> = .init(
      get: { storedAccounts },
      set: { storedAccounts = $0 }
    )
    features.patch(
      \Accounts.storedAccounts,
      with: always(storedAccounts)
    )
    features.patch(
      \Accounts.removeAccount,
      with: { account in
        uncheckedSendableStoredAccounts.variable.removeAll { $0 == account }
      }
    )

    let controller: AccountSelectionController = try await testController(context: .init(value: false))

    let removeResult: Void? =
      try? await controller
      .removeAccount(Account.mock_ada)
      .asAsyncValue()

    let result: Array<AccountSelectionListItem> =
      try await controller
      .accountsPublisher()
      .asAsyncValue()

    let accounts: Array<Account> = result.compactMap {
      guard case let .account(cellItem) = $0 else {
        return nil
      }
      return cellItem.account
    }

    XCTAssertNotNil(removeResult)
    XCTAssertFalse(accounts.contains(Account.mock_ada))
    XCTAssertTrue(accounts.contains(Account.mock_frances))
    XCTAssertTrue(result.contains(.addAccount(.default)))
  }

  func test_removeStoredAccount_updatesAccountsList() async throws {
    var storedAccounts: Array<Account> = [Account.mock_ada, Account.mock_frances]
    let uncheckedSendableStoredAccounts: UncheckedSendable<Array<Account>> = .init(
      get: { storedAccounts },
      set: { storedAccounts = $0 }
    )
    features.patch(
      \Accounts.storedAccounts,
      with: always(storedAccounts)
    )
    features.patch(
      \Accounts.removeAccount,
      with: { account in
        uncheckedSendableStoredAccounts.variable.removeAll { $0 == account }
      }
    )

    let controller: AccountSelectionController = try await testController(context: .init(value: false))

    _ =
      try? await controller
      .removeAccount(Account.mock_ada)
      .asAsyncValue()

    let result: Array<AccountSelectionListItem> =
      try await controller
      .accountsPublisher()
      .asAsyncValue()

    XCTAssertEqual(
      result.compactMap {
        guard case let .account(accountItem) = $0
        else { return nil }
        return accountItem.account
      },
      [Account.mock_frances]
    )
  }

  func test_removeAccountAlertPresentationPublisher_publishes_whenPresentRemoveAccountCalled() async throws {
    features.patch(
      \Accounts.storedAccounts,
      with: always([])
    )
    features.patch(
      \Accounts.removeAccount,
      with: always(Void())
    )

    let controller: AccountSelectionController = try await testController(context: .init(value: false))
    var result: Void?

    controller.removeAccountAlertPresentationPublisher()
      .sink { _ in
        result = Void()
      }
      .store(in: cancellables)

    controller.presentRemoveAccountAlert()

    XCTAssertNotNil(result)
  }

  func test_addAccountPresentationPublisher_publishesFalse_whenAddAccountCalledAndAccountTransferIsNotLoaded()
    async throws
  {
    features.patch(
      \Accounts.storedAccounts,
      with: always([])
    )
    features.patch(
      \Accounts.removeAccount,
      with: always(Void())
    )
    features.patch(
      \Session.close,
      with: always(Void())
    )

    let controller: AccountSelectionController = try await testController(context: .init(value: false))
    var result: Bool?

    controller
      .addAccountPresentationPublisher()
      .sink(receiveValue: { accountTransferInProgress in
        result = accountTransferInProgress
      })
      .store(in: cancellables)

    controller.addAccount()
    // temporary wait for detached tasks
    try await Task.sleep(nanoseconds: 300 * NSEC_PER_MSEC)
    XCTAssertEqual(result, false)
  }

  func test_addAccountPresentationPublisher_publishesTrue_whenAddAccountCalledAndAccountTransferIsLoaded() async throws
  {
    features.usePlaceholder(for: AccountTransfer.self)
    features.patch(
      \Accounts.storedAccounts,
      with: always([])
    )
    features.patch(
      \Accounts.removeAccount,
      with: always(Void())
    )
    features.patch(
      \Session.close,
      with: always(Void())
    )

    let controller: AccountSelectionController = try testController(context: .init(value: false))
    var result: Bool?

    controller
      .addAccountPresentationPublisher()
      .sink(receiveValue: { accountTransferInProgress in
        result = accountTransferInProgress
      })
      .store(in: cancellables)

    controller.addAccount()
    // temporary wait for detached tasks
    try await Task.sleep(nanoseconds: 300 * NSEC_PER_MSEC)

    XCTExpectFailure {
      // It is currently impossible to check if any account
      // transfer is in progress. This might require account
      // transfer rewrite.
      XCTAssertEqual(result, true)
    }
  }
}
