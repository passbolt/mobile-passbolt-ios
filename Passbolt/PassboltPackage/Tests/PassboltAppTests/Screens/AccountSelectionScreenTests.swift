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
@testable import PassboltApp

// swift-format-ignore: AlwaysUseLowerCamelCase, NeverUseImplicitlyUnwrappedOptionals
final class AccountSelectionScreenTests: TestCase {

  var accounts: Accounts!
  var accountSession: AccountSession!
  var networkClient: NetworkClient!

  override func setUp() {
    super.setUp()
    accounts = .placeholder
    networkClient = .placeholder
    accountSession = .placeholder
  }

  override func tearDown() {
    accounts = nil
    accountSession = nil
    networkClient = nil
    super.tearDown()
  }

  func test_loadStoredAccounts_andPrepareCellItemsWithImage_inSelectionMode() {
    accounts.storedAccounts = always([firstAccount, secondAccount])
    features.use(accounts)
    features.use(accountSession)

    networkClient.mediaDownload = .respondingWith(Data())
    features.use(networkClient)

    let controller: AccountSelectionController = testInstance()
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

    let accountIDs: Array<Account.LocalID> = accountItems.map(\.localID)

    XCTAssertTrue(accountIDs.contains(firstAccount.localID))
    XCTAssertTrue(accountIDs.contains(secondAccount.localID))
    XCTAssertTrue(result.contains(.addAccount(.default)))
    XCTAssertNotNil(imageData)
  }

  func test_loadStoredAccounts_andPrepareCellItemsWithoutImage_inSelectionMode() {
    accounts.storedAccounts = always([firstAccount, secondAccount])
    features.use(accounts)
    features.use(accountSession)

    networkClient.mediaDownload = .failingWith(.testError())
    features.use(networkClient)

    let controller: AccountSelectionController = testInstance()
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

    let accountIDs: Array<Account.LocalID> = accountItems.map(\.localID)

    XCTAssertTrue(accountIDs.contains(firstAccount.localID))
    XCTAssertTrue(accountIDs.contains(secondAccount.localID))
    XCTAssertTrue(result.contains(.addAccount(.default)))
    XCTAssertNil(imageData)
  }

  func test_loadStoredAccounts_andPrepareCellItems_withoutAddAccountItem_inRemovalMode() {
    accounts.storedAccounts = always([firstAccount, secondAccount])
    features.use(accounts)
    features.use(accountSession)
    features.use(networkClient)

    let controller: AccountSelectionController = testInstance()
    controller.toggleMode()

    var result: Array<AccountSelectionListItem> = []

    controller.accountsPublisher()
      .sink { items in
        result = items
      }
      .store(in: cancellables)

    let accountIDs: Array<Account.LocalID> = result.compactMap {
      guard case let .account(cellItem) = $0 else {
        return nil
      }
      return cellItem.localID
    }

    XCTAssertTrue(accountIDs.contains(firstAccount.localID))
    XCTAssertTrue(accountIDs.contains(secondAccount.localID))
    XCTAssertFalse(result.contains(.addAccount(.default)))
  }

  func test_loadStoredAccounts_andPrepareNoCellItems_whenAccountsEmpty() {
    accounts.storedAccounts = always([])
    features.use(accounts)
    features.use(accountSession)
    features.use(networkClient)

    let controller: AccountSelectionController = testInstance()
    var result: Array<AccountSelectionListItem> = []

    controller.accountsPublisher()
      .sink { items in
        result = items
      }
      .store(in: cancellables)

    XCTAssertTrue(result.isEmpty)
  }

  func test_removeStoredAccount_Succeeds() {
    var storedAccounts: Array<AccountWithProfile> = [firstAccount, secondAccount]
    accounts.storedAccounts = always(storedAccounts)
    accounts.removeAccount = { localID in
      storedAccounts.removeAll { $0.localID == localID }
      return .success(())
    }
    features.use(accounts)
    accountSession.close = always(Void())
    features.use(accountSession)
    features.use(networkClient)

    let controller: AccountSelectionController = testInstance()
    var result: Array<AccountSelectionListItem> = []

    let removeResult: Result<Void, TheError> = controller.removeAccount(firstAccount.localID)

    controller.accountsPublisher()
      .sink { items in
        result = items
      }
      .store(in: cancellables)

    let accountIDs: Array<Account.LocalID> = result.compactMap {
      guard case let .account(cellItem) = $0 else {
        return nil
      }
      return cellItem.localID
    }

    XCTAssertSuccess(removeResult)
    XCTAssertFalse(accountIDs.contains(firstAccount.localID))
    XCTAssertTrue(accountIDs.contains(secondAccount.localID))
    XCTAssertTrue(result.contains(.addAccount(.default)))
  }

  func test_removeStoredAccount_updatesAccountsList() {
    var storedAccounts: Array<AccountWithProfile> = [firstAccount, secondAccount]
    accounts.storedAccounts = always(storedAccounts)
    accounts.removeAccount = { localID in
      storedAccounts.removeAll { $0.localID == localID }
      return .success(())
    }
    features.use(accounts)
    features.use(accountSession)
    features.use(networkClient)

    let controller: AccountSelectionController = testInstance()
    var result: Array<AccountSelectionListItem> = []

    _ = controller.removeAccount(firstAccount.localID)

    controller
      .accountsPublisher()
      .sink(
        receiveCompletion: { _ in },
        receiveValue: { items in
          result = items
        }
      )
      .store(in: cancellables)

    XCTAssertEqual(
      result.compactMap {
        guard case let .account(accountItem) = $0
        else { return nil }
        return accountItem.localID
      },
      [secondAccount.localID]
    )
  }

  func test_removeAccountAlertPresentationPublisher_publishes_whenPresentRemoveAccountCalled() {
    accounts.storedAccounts = always([])
    accounts.removeAccount = { _ in return .success(()) }
    features.use(accounts)
    features.use(accountSession)
    features.use(networkClient)

    let controller: AccountSelectionController = testInstance()
    var result: Void?

    controller.removeAccountAlertPresentationPublisher()
      .sink { _ in
        result = Void()
      }
      .store(in: cancellables)

    controller.presentRemoveAccountAlert()

    XCTAssertNotNil(result)
  }

  func test_addAccount_closesSession() {
    accounts.storedAccounts = always([])
    accounts.removeAccount = always(.success(()))
    features.use(accounts)
    var result: Void!
    accountSession.close = {
      result = Void()
    }
    features.use(accountSession)
    features.use(networkClient)

    let controller: AccountSelectionController = testInstance()

    controller.addAccount()

    XCTAssertNotNil(result)
  }

  func test_addAccountPresentationPublisher_publishes_whenAddAccountCalled() {
    accounts.storedAccounts = always([])
    accounts.removeAccount = always(.success(()))
    features.use(accounts)
    accountSession.close = always(Void())
    features.use(accountSession)
    features.use(networkClient)

    let controller: AccountSelectionController = testInstance()
    var result: Void!

    controller
      .addAccountPresentationPublisher()
      .sink(receiveValue: {
        result = Void()
      })
      .store(in: cancellables)

    controller.addAccount()

    XCTAssertNotNil(result)
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
