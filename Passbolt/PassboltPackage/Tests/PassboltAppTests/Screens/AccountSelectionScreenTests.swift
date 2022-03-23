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
import NetworkClient
import SharedUIComponents
import TestExtensions
import UIComponents
import XCTest

@testable import Accounts
@testable import PassboltApp

// swift-format-ignore: AlwaysUseLowerCamelCase, NeverUseImplicitlyUnwrappedOptionals
@MainActor
final class AccountSelectionScreenTests: MainActorTestCase {

  var accounts: Accounts!
  var accountSession: AccountSession!
  var accountSettings: AccountSettings!
  var networkClient: NetworkClient!

  override func mainActorSetUp() {
    accounts = .placeholder
    networkClient = .placeholder
    accountSettings = .placeholder
    accountSession = .placeholder
  }

  override func mainActorTearDown() {
    accounts = nil
    accountSession = nil
    accountSettings = nil
    networkClient = nil
  }

  func test_accountsPublisher_publishesItemsWithImage_inSelectionMode() async throws {
    accounts.storedAccounts = always([firstAccount.account, secondAccount.account])
    await features.use(accounts)
    accountSession.statePublisher = always(Just(.authorized(account)).eraseToAnyPublisher())
    await features.use(accountSession)
    accountSettings.accountWithProfile = { account in
      if account.localID == firstAccount.localID {
        return firstAccount
      }
      else if account.localID == secondAccount.localID {
        return secondAccount
      }
      else {
        fatalError()
      }
    }
    await features.use(accountSettings)

    networkClient.mediaDownload = .respondingWith(Data())
    await features.use(networkClient)

    let controller: AccountSelectionController = try await testController(context: .init(value: false))
    var result: Array<AccountSelectionListItem> = []

    controller.accountsPublisher()
      .sink { items in
        result = items
      }
      .store(in: cancellables)

    let accountItems: Array<AccountSelectionCellItem> = result.compactMap {
      guard case let .account(cellItem) = $0 else {
        return nil
      }
      return cellItem
    }

    let imageData: Data? =
      try await accountItems.first!
      .imagePublisher?
      .asAsyncValue()

    let accounts: Array<Account> = accountItems.map(\.account)

    XCTAssertTrue(accounts.contains(firstAccount.account))
    XCTAssertTrue(accounts.contains(secondAccount.account))
    XCTAssertTrue(result.contains(.addAccount(.default)))
    XCTAssertNotNil(imageData)
  }

  func test_accountsPublisher_publishesItemsWithoutImage_inSelectionMode() async throws {
    accounts.storedAccounts = always([firstAccount.account, secondAccount.account])
    await features.use(accounts)
    accountSession.statePublisher = always(Just(.authorized(account)).eraseToAnyPublisher())
    await features.use(accountSession)
    accountSettings.accountWithProfile = { account in
      if account.localID == firstAccount.localID {
        return firstAccount
      }
      else if account.localID == secondAccount.localID {
        return secondAccount
      }
      else {
        fatalError()
      }
    }
    await features.use(accountSettings)

    networkClient.mediaDownload = .failingWith(MockIssue.error())
    await features.use(networkClient)

    let controller: AccountSelectionController = try await testController(context: .init(value: false))
    var result: Array<AccountSelectionListItem> = []
    var imageData: Data?

    controller.accountsPublisher()
      .sink { items in
        result = items
      }
      .store(in: cancellables)

    let accountItems: Array<AccountSelectionCellItem> = result.compactMap {
      guard case let .account(cellItem) = $0 else {
        return nil
      }
      return cellItem
    }

    accountItems.first!
      .imagePublisher!
      .sink { data in
        imageData = data
      }
      .store(in: cancellables)

    let accounts: Array<Account> = accountItems.map(\.account)

    XCTAssertTrue(accounts.contains(firstAccount.account))
    XCTAssertTrue(accounts.contains(secondAccount.account))
    XCTAssertTrue(result.contains(.addAccount(.default)))
    XCTAssertNil(imageData)
  }

  func test_accountsPublisher_publishes_withoutAddAccountItem_inRemovalMode() async throws {
    accounts.storedAccounts = always([firstAccount.account, secondAccount.account])
    await features.use(accounts)
    accountSession.statePublisher = always(Just(.authorized(account)).eraseToAnyPublisher())
    await features.use(accountSession)
    await features.use(networkClient)
    accountSettings.accountWithProfile = { account in
      if account.localID == firstAccount.localID {
        return firstAccount
      }
      else if account.localID == secondAccount.localID {
        return secondAccount
      }
      else {
        fatalError()
      }
    }
    await features.use(accountSettings)

    let controller: AccountSelectionController = try await testController(context: .init(value: false))
    controller.toggleMode()

    var result: Array<AccountSelectionListItem> = []

    controller.accountsPublisher()
      .sink { items in
        result = items
      }
      .store(in: cancellables)

    let accounts: Array<Account> = result.compactMap {
      guard case let .account(cellItem) = $0 else {
        return nil
      }
      return cellItem.account
    }

    XCTAssertTrue(accounts.contains(firstAccount.account))
    XCTAssertTrue(accounts.contains(secondAccount.account))
    XCTAssertFalse(result.contains(.addAccount(.default)))
  }

  func test_accountsPublisher_publishesEmptyList_whenAccountsEmpty() async throws {
    accounts.storedAccounts = always([])
    await features.use(accounts)
    accountSession.statePublisher = always(Just(.authorized(account)).eraseToAnyPublisher())
    await features.use(accountSession)
    await features.use(networkClient)
    await features.use(accountSettings)

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
    var storedAccounts: Array<Account> = [firstAccount.account, secondAccount.account]
    accounts.storedAccounts = always(storedAccounts)
    accounts.removeAccount = { account in
      storedAccounts.removeAll { $0 == account }
      return .success(())
    }
    await features.use(accounts)
    accountSession.statePublisher = always(Just(.authorized(account)).eraseToAnyPublisher())
    accountSession.close = always(Void())
    await features.use(accountSession)
    await features.use(networkClient)
    accountSettings.accountWithProfile = { account in
      if account.localID == firstAccount.localID {
        return firstAccount
      }
      else if account.localID == secondAccount.localID {
        return secondAccount
      }
      else {
        fatalError()
      }
    }
    await features.use(accountSettings)

    let controller: AccountSelectionController = try await testController(context: .init(value: false))

    let removeResult: Void? =
      try? await controller
      .removeAccount(firstAccount.account)
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
    XCTAssertFalse(accounts.contains(firstAccount.account))
    XCTAssertTrue(accounts.contains(secondAccount.account))
    XCTAssertTrue(result.contains(.addAccount(.default)))
  }

  func test_removeStoredAccount_updatesAccountsList() async throws {
    var storedAccounts: Array<Account> = [firstAccount.account, secondAccount.account]
    accounts.storedAccounts = always(storedAccounts)
    accounts.removeAccount = { account in
      storedAccounts.removeAll { $0 == account }
      return .success(())
    }
    await features.use(accounts)
    accountSession.statePublisher = always(Just(.authorized(account)).eraseToAnyPublisher())
    await features.use(accountSession)
    await features.use(networkClient)
    accountSettings.accountWithProfile = { account in
      if account.localID == firstAccount.localID {
        return firstAccount
      }
      else if account.localID == secondAccount.localID {
        return secondAccount
      }
      else {
        fatalError()
      }
    }
    await features.use(accountSettings)

    let controller: AccountSelectionController = try await testController(context: .init(value: false))

    _ =
      try? await controller
      .removeAccount(firstAccount.account)
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
      [secondAccount.account]
    )
  }

  func test_removeAccountAlertPresentationPublisher_publishes_whenPresentRemoveAccountCalled() async throws {
    accounts.storedAccounts = always([])
    accounts.removeAccount = { _ in return .success(()) }
    await features.use(accounts)
    await features.use(accountSession)
    await features.use(networkClient)
    await features.use(accountSettings)

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
    accounts.storedAccounts = always([])
    accounts.removeAccount = always(.success(()))
    await features.use(accounts)
    accountSession.close = always(Void())
    await features.use(accountSession)
    await features.use(networkClient)
    await features.use(accountSettings)

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
    try await Task.sleep(nanoseconds: 100 * NSEC_PER_MSEC)
    XCTAssertEqual(result, false)
  }

  func test_addAccountPresentationPublisher_publishesTrue_whenAddAccountCalledAndAccountTransferIsLoaded() async throws
  {
    accounts.storedAccounts = always([])
    accounts.removeAccount = always(.success(()))
    await features.use(accounts)
    accountSession.close = always(Void())
    await features.use(accountSession)
    await features.use(networkClient)
    await features.use(accountSettings)
    await features.use(AccountTransfer.placeholder)

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
    try await Task.sleep(nanoseconds: 100 * NSEC_PER_MSEC)
    XCTAssertEqual(result, true)
  }
}

private let firstAccount: AccountWithProfile = .init(
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

private let secondAccount: AccountWithProfile = .init(
  localID: "localID2",
  userID: "userID2",
  domain: "passbolt.com",
  label: "passbolt2",
  username: "username2",
  firstName: "John",
  lastName: "Smith",
  avatarImageURL: "",
  fingerprint: "FINGERPRINT2",
  biometricsEnabled: false
)

private let account: Account = .init(
  localID: firstAccount.localID,
  domain: firstAccount.domain,
  userID: firstAccount.userID,
  fingerprint: firstAccount.fingerprint
)
