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

import NetworkClient
import TestExtensions
import UIComponents
import XCTest

@testable import Accounts
@testable import PassboltApp

// swift-format-ignore: AlwaysUseLowerCamelCase, NeverUseImplicitlyUnwrappedOptionals
@MainActor
final class AccountMenuControllerTests: MainActorTestCase {

  @FeaturesActor var updatedAccountIDsSubject: PassthroughSubject<Account.LocalID, Never>!

  override func featuresActorSetUp() async throws {
    try await super.featuresActorSetUp()
    features.patch(
      \Accounts.storedAccounts,
      with: always(
        []
      )
    )
    await features.usePlaceholder(for: AccountSession.self)
    features.patch(
      \NetworkClient.mediaDownload,
      with: .respondingWith(MediaDownloadResponse())
    )
    updatedAccountIDsSubject = .init()
    features.patch(
      \AccountSettings.updatedAccountIDsPublisher,
      with: always(
        self.updatedAccountIDsSubject
          .eraseToAnyPublisher()
      )
    )
  }

  override func featuresActorTearDown() async throws {
    updatedAccountIDsSubject = nil
    try await super.featuresActorTearDown()
  }

  func test_currentAccountWithProfile_isEqualToProvidedInContext() async throws {
    let controller: AccountMenuController = try await testController(
      context: (
        accountWithProfile: validAccountWithProfile,
        navigation: ComponentNavigation.ignored(with: Void())
      )
    )

    XCTAssertEqual(controller.currentAccountWithProfile, validAccountWithProfile)
  }

  func test_accountsListPublisher_publishesAccountListWithoutCurrentAccount() async throws {
    await features.patch(
      \Accounts.storedAccounts,
      with: always(
        [validAccount, validAccountAlt]
      )
    )
    await features.patch(
      \AccountSettings.accountWithProfile,
      with: always(
        validAccountWithProfileAlt
      )
    )

    let controller: AccountMenuController = try await testController(
      context: (
        accountWithProfile: validAccountWithProfile,
        navigation: ComponentNavigation.ignored(with: Void())
      )
    )

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

    XCTAssertEqual(result?.map { $0.accountWithProfile }, [validAccountWithProfileAlt])
  }

  func test_accountsListPublisher_publishesUpdatedAccountListAterUpdatingAccounts() async throws {
    var storedAccounts: Array<Account> = [validAccount]
    await features.patch(
      \Accounts.storedAccounts,
      with: always(
        storedAccounts
      )
    )
    await features.patch(
      \AccountSettings.accountWithProfile,
      with: always(
        validAccountWithProfileAlt
      )
    )

    let controller: AccountMenuController = try await testController(
      context: (
        accountWithProfile: validAccountWithProfile,
        navigation: ComponentNavigation.ignored(with: Void())
      )
    )

    storedAccounts = [validAccount, validAccountAlt]
    await updatedAccountIDsSubject.send(.init(rawValue: "some ID"))

    // temporary wait for detached tasks
    try await Task.sleep(nanoseconds: 100 * NSEC_PER_MSEC)

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

    XCTAssertEqual(result?.map { $0.accountWithProfile }, [validAccountWithProfileAlt])
  }

  func test_accountDetailsPresentationPublisher_doesNotPublishInitially() async throws {
    let controller: AccountMenuController = try await testController(
      context: (
        accountWithProfile: validAccountWithProfile,
        navigation: ComponentNavigation.ignored(with: Void())
      )
    )

    var result: Void?
    controller
      .accountDetailsPresentationPublisher()
      .sink { account in
        result = Void()
      }
      .store(in: cancellables)

    XCTAssertNil(result)
  }

  func test_accountDetailsPresentationPublisher_publishesCurrentAccountAfterCallingPresent() async throws {
    let controller: AccountMenuController = try await testController(
      context: (
        accountWithProfile: validAccountWithProfile,
        navigation: ComponentNavigation.ignored(with: Void())
      )
    )

    var result: AccountWithProfile?
    controller
      .accountDetailsPresentationPublisher()
      .sink { account in
        result = account
      }
      .store(in: cancellables)

    controller.presentAccountDetails()

    XCTAssertEqual(result, validAccountWithProfile)
  }

  func test_accountSwitchPresentationPublisher_doesNotPublishInitially() async throws {
    let controller: AccountMenuController = try await testController(
      context: (
        accountWithProfile: validAccountWithProfile,
        navigation: ComponentNavigation.ignored(with: Void())
      )
    )

    var result: Void?
    controller
      .accountSwitchPresentationPublisher()
      .sink { account in
        result = Void()
      }
      .store(in: cancellables)

    XCTAssertNil(result)
  }

  func test_accountSwitchPresentationPublisher_publishesSelectedAccountAfterCallingPresent() async throws {
    let controller: AccountMenuController = try await testController(
      context: (
        accountWithProfile: validAccountWithProfile,
        navigation: ComponentNavigation.ignored(with: Void())
      )
    )

    var result: Account?
    controller
      .accountSwitchPresentationPublisher()
      .sink { account in
        result = account
      }
      .store(in: cancellables)

    controller.presentAccountSwitch(validAccountAlt)

    XCTAssertEqual(result, validAccountAlt)
  }

  func test_dismissPublisher_doesNotPublishInitially() async throws {
    let controller: AccountMenuController = try await testController(
      context: (
        accountWithProfile: validAccountWithProfile,
        navigation: ComponentNavigation.ignored(with: Void())
      )
    )

    var result: Void?
    controller
      .dismissPublisher()
      .sink { account in
        result = Void()
      }
      .store(in: cancellables)

    XCTAssertNil(result)
  }

  func test_manageAccountsPresentationPublisher_doesNotPublishInitially() async throws {
    let controller: AccountMenuController = try await testController(
      context: (
        accountWithProfile: validAccountWithProfile,
        navigation: ComponentNavigation.ignored(with: Void())
      )
    )

    var result: Void?
    controller
      .manageAccountsPresentationPublisher()
      .sink {
        result = Void()
      }
      .store(in: cancellables)

    XCTAssertNil(result)
  }

  func test_manageAccountsPresentationPublisher_publishesAfterCallingPresent() async throws {
    let controller: AccountMenuController = try await testController(
      context: (
        accountWithProfile: validAccountWithProfile,
        navigation: ComponentNavigation.ignored(with: Void())
      )
    )

    var result: Void?
    controller
      .manageAccountsPresentationPublisher()
      .sink {
        result = Void()
      }
      .store(in: cancellables)

    controller.presentManageAccounts()

    XCTAssertNotNil(result)
  }

  func test_signOut_closesCurrentSession() async throws {
    var result: Void?
    await features.patch(
      \AccountSession.close,
      with: {
        result = Void()
      }
    )
    let controller: AccountMenuController = try await testController(
      context: (
        accountWithProfile: validAccountWithProfile,
        navigation: ComponentNavigation.ignored(with: Void())
      )
    )

    controller.signOut()
    // temporary wait for detached tasks, to be removed
    try await Task.sleep(nanoseconds: 100 * NSEC_PER_MSEC)
    XCTAssertNotNil(result)
  }
}

@MainActor
private final class TestComponent: UIViewController, AnyUIComponent {

  var lazyView: UIView { unimplemented() }

  var components: UIComponentFactory { unimplemented() }

  func setup() {
    unimplemented()
  }

  func setupView() {
    unimplemented()
  }

  func activate() {
    unimplemented()
  }

  func deactivate() {
    unimplemented()
  }
}

private let validAccount: Account = .init(
  localID: .init(rawValue: UUID.test.uuidString),
  domain: "passbolt.com",
  userID: .init(rawValue: UUID.test.uuidString),
  fingerprint: "fingerprint"
)

private let validAccountProfile: AccountProfile = .init(
  accountID: .init(rawValue: UUID.test.uuidString),
  label: "firstName lastName",
  username: "username",
  firstName: "firstName",
  lastName: "lastName",
  avatarImageURL: "avatarImagePath",
  biometricsEnabled: false
)

private let validAccountWithProfile: AccountWithProfile = .init(
  account: validAccount,
  profile: validAccountProfile
)

private let validAccountAlt: Account = .init(
  localID: .init(rawValue: UUID.testAlt.uuidString),
  domain: "passbolt.com",
  userID: .init(rawValue: UUID.testAlt.uuidString),
  fingerprint: "fingerprint"
)

private let validAccountProfileAlt: AccountProfile = .init(
  accountID: .init(rawValue: UUID.testAlt.uuidString),
  label: "firstName lastName",
  username: "username",
  firstName: "firstName",
  lastName: "lastName",
  avatarImageURL: "avatarImagePath",
  biometricsEnabled: false
)

private let validAccountWithProfileAlt: AccountWithProfile = .init(
  account: validAccountAlt,
  profile: validAccountProfileAlt
)
