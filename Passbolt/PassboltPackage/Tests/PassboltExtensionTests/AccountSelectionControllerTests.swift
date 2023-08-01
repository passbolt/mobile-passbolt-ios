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

import Display
import Features
import SharedUIComponents
import TestExtensions
import UIComponents
import XCTest

@testable import Accounts
@testable import PassboltExtension

// swift-format-ignore: AlwaysUseLowerCamelCase, NeverUseImplicitlyUnwrappedOptionals
@MainActor @available(iOS 16.0.0, *)
final class AccountSelectionControllerTests: MainActorTestCase {

  var accountsUpdates: Updates!

  override func mainActorSetUp() {
    accountsUpdates = .init()
    features.patch(
      \Accounts.updates,
      with: accountsUpdates.asAnyUpdatable()
    )
    features.patch(
      \Accounts.storedAccounts,
      with: always([Account.mock_ada, Account.mock_frances])
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
    features.patch(
      \Session.currentAccount,
      with: always(Account.mock_ada)
    )
    features.usePlaceholder(for: AutofillExtensionContext.self)
  }

  override func mainActorTearDown() {
    accountsUpdates = .none
  }

  func test_accountsPublisher_publishesItemsWithImage() async throws {
    let controller: AccountSelectionController = try await testController(context: .signIn)

    let result: Array<AccountSelectionListItem> =
      try await controller.accountsPublisher().first().asAsyncValue()

    let accountItems: Array<AccountSelectionCellItem> = result.compactMap {
      guard case let .account(cellItem) = $0 else {
        return nil
      }
      return cellItem
    }

    let imageData: Data? =
      try? await accountItems
      .first?
      .imagePublisher?
      .asAsyncValue()

    let accounts: Array<Account> = accountItems.map(\.account)

    XCTAssertTrue(accounts.contains(Account.mock_ada))
    XCTAssertTrue(accounts.contains(Account.mock_frances))
    XCTAssertNotNil(imageData)
  }

  func test_accountsPublisher_publishesItemsWithoutImage() async throws {
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

    let controller: AccountSelectionController = try await testController(context: .signIn)
    let result: Array<AccountSelectionListItem> =
      try await controller.accountsPublisher().first().asAsyncValue()

    let accountItems: Array<AccountSelectionCellItem> = result.compactMap {
      guard case let .account(cellItem) = $0 else {
        return nil
      }
      return cellItem
    }

    let imageData: Data? =
      try? await accountItems
      .first?
      .imagePublisher?
      .asAsyncValue()

    let accounts: Array<Account> = accountItems.map(\.account)

    XCTAssertTrue(accounts.contains(Account.mock_ada))
    XCTAssertTrue(accounts.contains(Account.mock_frances))
    XCTAssertNil(imageData)
  }

  func test_accountsPublisher_publishesEmptyList_whenAccountsAreEmpty() async throws {
    features.patch(
      \Accounts.storedAccounts,
      with: always([])
    )

    let controller: AccountSelectionController = try await testController(context: .signIn)
    let result: Array<AccountSelectionListItem> =
      try await controller.accountsPublisher().first().asAsyncValue()

    XCTAssertTrue(result.isEmpty)
  }
}
