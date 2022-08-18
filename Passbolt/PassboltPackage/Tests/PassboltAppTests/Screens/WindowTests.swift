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

  func test_screenStateDispositionPublisher_publishesInitialScreen_initially() async throws {

    let controller: WindowController = try await testController()
    var result: WindowController.ScreenStateDisposition!

    controller
      .screenStateDispositionPublisher()
      .sink { result = $0 }
      .store(in: cancellables)

    // temporary wait for detached tasks
    try await Task.sleep(nanoseconds: 300 * NSEC_PER_MSEC)

    guard case .some(.useInitialScreenState) = result
    else { return XCTFail() }
  }

  func
    test_screenStateDispositionPublisher_publishesRequestPassphrase_whenAuthorizationPromptPresentationPublisherPublishesPassphraseRequest()
    async throws
  {
    var pendingAuthorization: SessionAuthorizationRequest?
    features.patch(
      \Session.pendingAuthorization,
      with: always(pendingAuthorization)
    )

    let controller: WindowController = try await testController()
    var result: WindowController.ScreenStateDisposition!

    controller
      .screenStateDispositionPublisher()
      .sink { result = $0 }
      .store(in: cancellables)

    // temporary wait for detached tasks
    try await Task.sleep(nanoseconds: 300 * NSEC_PER_MSEC)

    pendingAuthorization = .passphrase(Account.valid)
    updates.sendUpdate()

    // temporary wait for detached tasks
    try await Task.sleep(nanoseconds: 300 * NSEC_PER_MSEC)

    guard case let .some(.requestPassphrase(account, message)) = result
    else { return XCTFail() }
    XCTAssertEqual(account, Account.valid)
    XCTAssertEqual(message, .none)
  }

  func
    test_screenStateDispositionPublisher_publishesRequestMFA_whenAuthorizationPromptPresentationPublisherPublishesMFARequest()
    async throws
  {
    var pendingAuthorization: SessionAuthorizationRequest?
    features.patch(
      \Session.pendingAuthorization,
      with: always(pendingAuthorization)
    )

    let controller: WindowController = try await testController()
    var result: WindowController.ScreenStateDisposition!

    controller
      .screenStateDispositionPublisher()
      .sink { result = $0 }
      .store(in: cancellables)

    // temporary wait for detached tasks
    try await Task.sleep(nanoseconds: 300 * NSEC_PER_MSEC)

    pendingAuthorization = .mfa(Account.valid, providers: [])
    updates.sendUpdate()

    // temporary wait for detached tasks
    try await Task.sleep(nanoseconds: 300 * NSEC_PER_MSEC)

    guard case let .some(.requestMFA(account, providers)) = result
    else { return XCTFail() }
    XCTAssertEqual(account, Account.valid)
    XCTAssertEqual(providers, [])
  }

  func
    test_screenStateDispositionPublisher_publishesRequestPassphrase_whenAuthorizationPromptPresentationPublisherPublishesPassphraseRequestAndAccountTransferIsNotLoaded()
    async throws
  {
    var pendingAuthorization: SessionAuthorizationRequest?
    features.patch(
      \Session.pendingAuthorization,
      with: always(pendingAuthorization)
    )

    let controller: WindowController = try await testController()
    var result: WindowController.ScreenStateDisposition!

    controller
      .screenStateDispositionPublisher()
      .sink { result = $0 }
      .store(in: cancellables)

    // temporary wait for detached tasks
    try await Task.sleep(nanoseconds: 300 * NSEC_PER_MSEC)

    pendingAuthorization = .passphrase(Account.valid)
    updates.sendUpdate()

    // temporary wait for detached tasks
    try await Task.sleep(nanoseconds: 300 * NSEC_PER_MSEC)

    guard case let .some(.requestPassphrase(account, message)) = result
    else { return XCTFail() }
    XCTAssertEqual(account, Account.valid)
    XCTAssertNil(message)
  }

  func
    test_screenStateDispositionPublisher_publishesRequestMFA_whenAuthorizationPromptPresentationPublisherPublishesMFARequestAndAccountTransferIsNotLoaded()
    async throws
  {
    var pendingAuthorization: SessionAuthorizationRequest?
    features.patch(
      \Session.pendingAuthorization,
      with: always(pendingAuthorization)
    )

    let controller: WindowController = try await testController()
    var result: WindowController.ScreenStateDisposition!

    controller
      .screenStateDispositionPublisher()
      .sink { result = $0 }
      .store(in: cancellables)

    // temporary wait for detached tasks
    try await Task.sleep(nanoseconds: 300 * NSEC_PER_MSEC)

    pendingAuthorization = .mfa(
      Account.valid,
      providers: []
    )
    updates.sendUpdate()

    // temporary wait for detached tasks
    try await Task.sleep(nanoseconds: 300 * NSEC_PER_MSEC)

    guard case let .some(.requestMFA(account, providers)) = result
    else { return XCTFail() }
    XCTAssertEqual(account, Account.valid)
    XCTAssertEqual(providers, [])
  }

  func
    test_screenStateDispositionPublisher_doesNotPublish_whenAuthorizationPromptPresentationPublisherPublishesMFARequestAndAccountTransferIsLoaded()
    async throws
  {
    await features.use(AccountTransfer.placeholder)
    var pendingAuthorization: SessionAuthorizationRequest?
    features.patch(
      \Session.pendingAuthorization,
      with: always(pendingAuthorization)
    )

    let controller: WindowController = try await testController()
    var result: WindowController.ScreenStateDisposition?

    controller
      .screenStateDispositionPublisher()
      // ignore initial disposition
      .dropFirst()
      .sink { result = $0 }
      .store(in: cancellables)

    pendingAuthorization = .mfa(
      Account.valid,
      providers: []
    )
    updates.sendUpdate()

    XCTAssertNil(result)
  }

  func test_screenStateDispositionPublisher_publishesUseInitialScreenState_whenAccountSessionStateChangesToAuthorized()
    async throws
  {
    var currentAccount: Account?
    let uncheckedSendableCurrentAccount: UncheckedSendable<Account?> = .init(
      get: { currentAccount },
      set: { currentAccount = $0 }
    )
    features.patch(
      \Session.currentAccount,
      with: {
        if let currentAccount = uncheckedSendableCurrentAccount.variable {
          return currentAccount
        }
        else {
          throw SessionMissing.error()
        }
      }
    )

    let controller: WindowController = try await testController()
    var result: WindowController.ScreenStateDisposition!

    controller
      .screenStateDispositionPublisher()
      .sink { result = $0 }
      .store(in: cancellables)

    currentAccount = Account.valid
    updates.sendUpdate()

    // temporary wait for detached tasks
    try await Task.sleep(nanoseconds: 300 * NSEC_PER_MSEC)

    guard case .some(.useInitialScreenState) = result
    else { return XCTFail() }
  }

  func
    test_screenStateDispositionPublisher_doesNotPublish_whenAccountSessionStateChangesToAuthorizedAndAccountTransferIsLoaded()
    async throws
  {
    await features.use(AccountTransfer.placeholder)
    var currentAccount: Account?
    let uncheckedSendableCurrentAccount: UncheckedSendable<Account?> = .init(
      get: { currentAccount },
      set: { currentAccount = $0 }
    )
    features.patch(
      \Session.currentAccount,
      with: {
        if let currentAccount = uncheckedSendableCurrentAccount.variable {
          return currentAccount
        }
        else {
          throw SessionMissing.error()
        }
      }
    )

    let controller: WindowController = try await testController()
    var result: WindowController.ScreenStateDisposition!

    controller
      .screenStateDispositionPublisher()
      .dropFirst()
      .sink { result = $0 }
      .store(in: cancellables)

    currentAccount = Account.valid
    updates.sendUpdate()

    XCTAssertNil(result)
  }

  func
    test_screenStateDispositionPublisher_publishesUseCachedScreenState_whenAccountSessionStateChangesToAuthorized_andAuthorizationPromptPresentationSubjectPublishedSameAccountPassphraseRequest()
    async throws
  {
    var currentAccount: Account? = Account.valid
    let uncheckedSendableCurrentAccount: UncheckedSendable<Account?> = .init(
      get: { currentAccount },
      set: { currentAccount = $0 }
    )
    features.patch(
      \Session.currentAccount,
      with: {
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
    var result: WindowController.ScreenStateDisposition!

    controller
      .screenStateDispositionPublisher()
      .sink {
        result = $0
      }
      .store(in: cancellables)

    // temporary wait for detached tasks
    try await Task.sleep(nanoseconds: 300 * NSEC_PER_MSEC)

    pendingAuthorization = .passphrase(Account.valid)
    updates.sendUpdate()

    // temporary wait for detached tasks
    try await Task.sleep(nanoseconds: 300 * NSEC_PER_MSEC)

    currentAccount = Account.valid
    pendingAuthorization = .none
    updates.sendUpdate()

    // temporary wait for detached tasks
    try await Task.sleep(nanoseconds: 300 * NSEC_PER_MSEC)

    guard case .some(.useCachedScreenState) = result
    else { return XCTFail() }
  }

  func
    test_screenStateDispositionPublisher_publishesUseCachedScreenState_whenAccountSessionStateChangesToAuthorized_andAuthorizationPromptPresentationSubjectPublishedSameAccountMFARequest()
    async throws
  {
    var currentAccount: Account? = Account.valid
    let uncheckedSendableCurrentAccount: UncheckedSendable<Account?> = .init(
      get: { currentAccount },
      set: { currentAccount = $0 }
    )
    features.patch(
      \Session.currentAccount,
      with: {
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
    var result: WindowController.ScreenStateDisposition!

    controller
      .screenStateDispositionPublisher()
      .sink { result = $0 }
      .store(in: cancellables)

    // temporary wait for detached tasks
    try await Task.sleep(nanoseconds: 300 * NSEC_PER_MSEC)

    pendingAuthorization = .mfa(
      Account.valid,
      providers: []
    )
    updates.sendUpdate()

    // temporary wait for detached tasks
    try await Task.sleep(nanoseconds: 300 * NSEC_PER_MSEC)

    currentAccount = Account.valid
    pendingAuthorization = .none
    updates.sendUpdate()

    // temporary wait for detached tasks
    try await Task.sleep(nanoseconds: 300 * NSEC_PER_MSEC)

    guard case .some(.useCachedScreenState) = result
    else { return XCTFail() }
  }
}
