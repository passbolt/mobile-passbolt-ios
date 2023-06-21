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
import TestExtensions
import UIComponents
import XCTest

@testable import Accounts
@testable import PassboltApp

// swift-format-ignore: AlwaysUseLowerCamelCase, NeverUseImplicitlyUnwrappedOptionals
@MainActor
final class WindowTests: MainActorTestCase {

  var updates: UpdatesSource!

  override func mainActorSetUp() {
    updates = .init()
    features.patch(
      \Session.updates,
      with: updates.updates
    )
    features.patch(
      \Session.currentAccount,
      with: always(Account.mock_ada)
    )
    features.patch(
      \Session.pendingAuthorization,
      with: always(.none)
    )
    features.patch(
      \Accounts.storedAccounts,
      with: always([])
    )
    features.patch(
      \Accounts.lastUsedAccount,
      with: always(.none)
    )
  }

  override func mainActorTearDown() {
    updates = .none
  }

  func test_screenStateDispositionSequence_returnsInitialScreen_initially() async throws {
    let controller: WindowController = try await testController()
    var result: WindowController.ScreenStateDisposition?

    result =
		try await controller
      .screenStateDispositionSequence()
      .first()

    guard case .useInitialScreenState = result
    else { return XCTFail() }
  }

  func
    test_screenStateDispositionSequence_returnsRequestPassphrase_whenPendingAuthorizationChangesToPassphraseRequest()
    async throws
  {
    var pendingAuthorization: SessionAuthorizationRequest?
    features.patch(
      \Session.pendingAuthorization,
      with: always(pendingAuthorization)
    )

    let controller: WindowController = try await testController()
    var result: WindowController.ScreenStateDisposition?

    let iterator: AnyAsyncIterator<WindowController.ScreenStateDisposition> =
      controller
      .screenStateDispositionSequence().makeAsyncIterator()

    result = try await iterator.next()

    pendingAuthorization = .passphrase(Account.mock_ada)

    Task {
      // Temporary wait related to implementation
      // of merge from async algorithms 0.1.0
      try await Task.sleep(nanoseconds: NSEC_PER_MSEC * 100)
      self.updates.sendUpdate()
    }

    result = try await iterator.next()

    guard case let .requestPassphrase(account, message) = result
    else { return XCTFail() }
    XCTAssertEqual(account, Account.mock_ada)
    XCTAssertNil(message)
  }

  func
    test_screenStateDispositionSequence_returnsRequestMFA_whenPendingAuthorizationChangesToMFARequest()
    async throws
  {
    var pendingAuthorization: SessionAuthorizationRequest?
    features.patch(
      \Session.pendingAuthorization,
      with: always(pendingAuthorization)
    )

    let controller: WindowController = try await testController()
    var result: WindowController.ScreenStateDisposition?

    let iterator: AnyAsyncIterator<WindowController.ScreenStateDisposition> =
      controller
      .screenStateDispositionSequence().makeAsyncIterator()

    result = try await iterator.next()

    pendingAuthorization = .mfa(
      Account.mock_ada,
      providers: []
    )
    Task {
      // Temporary wait related to implementation
      // of merge from async algorithms 0.1.0
      try await Task.sleep(nanoseconds: NSEC_PER_MSEC * 100)
      self.updates.sendUpdate()
    }

    result = try await iterator.next()

    guard case let .requestMFA(account, providers) = result
    else { return XCTFail() }
    XCTAssertEqual(account, Account.mock_ada)
    XCTAssertEqual(providers, [])
  }

  func test_screenStateDispositionSequence_returnsUseInitialScreenState_whenAccountSessionStateChangesToAuthorized()
    async throws
  {
    var currentAccount: Account?
    let uncheckedSendableCurrentAccount: UncheckedSendable<Account?> = .init(
      get: { currentAccount },
      set: { currentAccount = $0 }
    )
    features.patch(
      \Session.currentAccount,
      with: { () async throws in
        if let currentAccount = uncheckedSendableCurrentAccount.variable {
          return currentAccount
        }
        else {
          throw SessionMissing.error()
        }
      }
    )

    let controller: WindowController = try await testController()
    var result: WindowController.ScreenStateDisposition?

    let iterator: AnyAsyncIterator<WindowController.ScreenStateDisposition> =
      controller
      .screenStateDispositionSequence().makeAsyncIterator()

    result = try await iterator.next()

    currentAccount = Account.mock_ada
    Task {
      // Temporary wait related to implementation
      // of merge from async algorithms 0.1.0
      try await Task.sleep(nanoseconds: NSEC_PER_MSEC * 100)
      self.updates.sendUpdate()
    }

    result = try await iterator.next()

    guard case .useInitialScreenState = result
    else { return XCTFail() }
  }

  func
    test_screenStateDispositionSequence_returnsUseCachedScreenState_whenAccountSessionStateChangesToAuthorized_andPendingAuthorizationHadSameAccountPassphraseRequest()
    async throws
  {
    var currentAccount: Account? = Account.mock_ada
    let uncheckedSendableCurrentAccount: UncheckedSendable<Account?> = .init(
      get: { currentAccount },
      set: { currentAccount = $0 }
    )
    features.patch(
      \Session.currentAccount,
      with: { () async throws in
        if let currentAccount = uncheckedSendableCurrentAccount.variable {
          return currentAccount
        }
        else {
          throw SessionMissing.error()
        }
      }
    )
    var pendingAuthorization: SessionAuthorizationRequest?
    features.patch(
      \Session.pendingAuthorization,
      with: always(pendingAuthorization)
    )

    let controller: WindowController = try await testController()
    var result: WindowController.ScreenStateDisposition?

    let iterator: AnyAsyncIterator<WindowController.ScreenStateDisposition> =
      controller
      .screenStateDispositionSequence().makeAsyncIterator()

    result = try await iterator.next()

    pendingAuthorization = .passphrase(Account.mock_ada)
    Task {
      // Temporary wait related to implementation
      // of merge from async algorithms 0.1.0
      try await Task.sleep(nanoseconds: NSEC_PER_MSEC * 100)
      self.updates.sendUpdate()
    }

    result = try await iterator.next()

    currentAccount = Account.mock_ada
    pendingAuthorization = .none
    updates.sendUpdate()

    result = try await iterator.next()

    guard case .useCachedScreenState = result
    else { return XCTFail() }
  }

  func
    test_screenStateDispositionSequence_returnsUseCachedScreenState_whenAccountSessionStateChangesToAuthorized_andPendingAuthorizationHadSameAccountMFARequest()
    async throws
  {
    var currentAccount: Account? = Account.mock_ada
    let uncheckedSendableCurrentAccount: UncheckedSendable<Account?> = .init(
      get: { currentAccount },
      set: { currentAccount = $0 }
    )
    features.patch(
      \Session.currentAccount,
      with: { () async throws in
        if let currentAccount = uncheckedSendableCurrentAccount.variable {
          return currentAccount
        }
        else {
          throw SessionMissing.error()
        }
      }
    )
    var pendingAuthorization: SessionAuthorizationRequest?
    features.patch(
      \Session.pendingAuthorization,
      with: always(pendingAuthorization)
    )

    let controller: WindowController = try await testController()
    var result: WindowController.ScreenStateDisposition?

    let iterator: AnyAsyncIterator<WindowController.ScreenStateDisposition> =
      controller
      .screenStateDispositionSequence().makeAsyncIterator()

    result = try await iterator.next()

    pendingAuthorization = .mfa(
      Account.mock_ada,
      providers: []
    )
    Task {
      // Temporary wait related to implementation
      // of merge from async algorithms 0.1.0
      try await Task.sleep(nanoseconds: NSEC_PER_MSEC * 100)
      self.updates.sendUpdate()
    }

    result = try await iterator.next()

    currentAccount = Account.mock_ada
    pendingAuthorization = .none
    Task {
      // Temporary wait related to implementation
      // of merge from async algorithms 0.1.0
      try await Task.sleep(nanoseconds: NSEC_PER_MSEC * 100)
      self.updates.sendUpdate()
    }

    result = try await iterator.next()

    guard case .useCachedScreenState = result
    else { return XCTFail() }
  }
}
