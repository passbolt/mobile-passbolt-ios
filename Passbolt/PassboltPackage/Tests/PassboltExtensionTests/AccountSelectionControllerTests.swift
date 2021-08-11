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

@testable import Accounts
import Features
import NetworkClient
@testable import PassboltExtension
import SharedUIComponents
import TestExtensions
import UIComponents
import XCTest

// swift-format-ignore: AlwaysUseLowerCamelCase, NeverUseImplicitlyUnwrappedOptionals
final class AccountSelectionControllerTests: TestCase {

  var accounts: Accounts!
  var accountSession: AccountSession!
  var accountSettings: AccountSettings!
  var networkClient: NetworkClient!

  override func setUp() {
    super.setUp()
    accounts = .placeholder
    networkClient = .placeholder
    accountSettings = .placeholder
    accountSession = .placeholder
  }

  override func tearDown() {
    accounts = nil
    accountSession = nil
    accountSettings = nil
    networkClient = nil
    super.tearDown()
  }

  func test_accountsPublisher_publishesItemsWithImage() {
    accounts.storedAccounts = always([firstAccount.account, secondAccount.account])
    features.use(accounts)
    accountSession.statePublisher = always(Just(.authorized(account)).eraseToAnyPublisher())
    features.use(accountSession)
    accountSettings.accountWithProfile = { account in
      if account.localID == firstAccount.localID {
        return firstAccount
      } else if account.localID == secondAccount.localID {
        return secondAccount
      } else { fatalError() }
    }
    features.use(accountSettings)

    networkClient.mediaDownload = .respondingWith(Data())
    features.use(networkClient)

    let controller: AccountSelectionController = testInstance(context: .signIn)
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
    XCTAssertNotNil(imageData)
  }

  func test_accountsPublisher_publishesItemsWithoutImage() {
    accounts.storedAccounts = always([firstAccount.account, secondAccount.account])
    features.use(accounts)
    accountSession.statePublisher = always(Just(.authorized(account)).eraseToAnyPublisher())
    features.use(accountSession)
    accountSettings.accountWithProfile = { account in
      if account.localID == firstAccount.localID {
        return firstAccount
      } else if account.localID == secondAccount.localID {
        return secondAccount
      } else { fatalError() }
    }
    features.use(accountSettings)

    networkClient.mediaDownload = .failingWith(.testError())
    features.use(networkClient)

    let controller: AccountSelectionController = testInstance(context: .signIn)
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
    XCTAssertNil(imageData)
  }

  func test_accountsPublisher_publishesEmptyList_whenAccountsAreEmpty() {
    accounts.storedAccounts = always([])
    features.use(accounts)
    accountSession.statePublisher = always(Just(.authorized(account)).eraseToAnyPublisher())
    features.use(accountSession)
    features.use(networkClient)
    features.use(accountSettings)

    let controller: AccountSelectionController = testInstance(context: .signIn)
    var result: Array<AccountSelectionListItem> = []

    controller.accountsPublisher()
      .sink { items in
        result = items
      }
      .store(in: cancellables)

    XCTAssertTrue(result.isEmpty)
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
