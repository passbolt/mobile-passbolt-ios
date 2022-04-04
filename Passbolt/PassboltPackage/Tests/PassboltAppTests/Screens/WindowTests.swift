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

  var accountSession: AccountSession!

  override func mainActorSetUp() {
    accountSession = .placeholder
  }

  override func mainActorTearDown() {
    accountSession = nil
  }

  func test_screenStateDispositionPublisher_publishesInitialScreen_initially() async throws {
    accountSession.statePublisher = always(
      CurrentValueSubject<AccountSessionState, Never>(.none(lastUsed: .none))
        .eraseToAnyPublisher()
    )
    accountSession.authorizationPromptPresentationPublisher = always(
      Empty<AuthorizationPromptRequest, Never>()
        .eraseToAnyPublisher()
    )
    await features.use(accountSession)

    let controller: WindowController = try await testController()
    var result: WindowController.ScreenStateDisposition!

    controller
      .screenStateDispositionPublisher()
      .sink { result = $0 }
      .store(in: cancellables)

    // temporary wait for detached tasks
    try await Task.sleep(nanoseconds: 100 * NSEC_PER_MSEC)

    guard case .some(.useInitialScreenState) = result
    else { return XCTFail() }
  }

  func
    test_screenStateDispositionPublisher_publishesRequestPassphrase_whenAuthorizationPromptPresentationPublisherPublishesPassphraseRequest()
    async throws
  {
    accountSession.statePublisher = always(
      Just(.none(lastUsed: .none))
        .eraseToAnyPublisher()
    )
    let authorizationPromptPresentationSubject: PassthroughSubject<AuthorizationPromptRequest, Never> = .init()
    accountSession.authorizationPromptPresentationPublisher = always(
      authorizationPromptPresentationSubject
        .eraseToAnyPublisher()
    )
    await features.use(accountSession)

    let controller: WindowController = try await testController()
    var result: WindowController.ScreenStateDisposition!

    controller
      .screenStateDispositionPublisher()
      .sink { result = $0 }
      .store(in: cancellables)

    authorizationPromptPresentationSubject.send(
      .passphraseRequest(
        account: validAccount,
        message: .testMessage()
      )
    )

    // temporary wait for detached tasks
    try await Task.sleep(nanoseconds: 100 * NSEC_PER_MSEC)

    guard case let .some(.requestPassphrase(account, message)) = result
    else { return XCTFail() }
    XCTAssertEqual(account, validAccount)
    XCTAssertEqual(message, .testMessage())
  }

  func
    test_screenStateDispositionPublisher_publishesRequestMFA_whenAuthorizationPromptPresentationPublisherPublishesMFARequest()
    async throws
  {
    accountSession.statePublisher = always(
      Just(.none(lastUsed: .none))
        .eraseToAnyPublisher()
    )
    let authorizationPromptPresentationSubject: PassthroughSubject<AuthorizationPromptRequest, Never> = .init()
    accountSession.authorizationPromptPresentationPublisher = always(
      authorizationPromptPresentationSubject
        .eraseToAnyPublisher()
    )
    await features.use(accountSession)

    let controller: WindowController = try await testController()
    var result: WindowController.ScreenStateDisposition!

    controller
      .screenStateDispositionPublisher()
      .sink { result = $0 }
      .store(in: cancellables)

    authorizationPromptPresentationSubject.send(
      .mfaRequest(
        account: validAccount,
        providers: []
      )
    )

    // temporary wait for detached tasks
    try await Task.sleep(nanoseconds: 100 * NSEC_PER_MSEC)

    guard case let .some(.requestMFA(account, providers)) = result
    else { return XCTFail() }
    XCTAssertEqual(account, validAccount)
    XCTAssertEqual(providers, [])
  }

  func
    test_screenStateDispositionPublisher_publishesRequestPassphrase_whenAuthorizationPromptPresentationPublisherPublishesPassphraseRequestAndAccountTransferIsNotLoaded()
    async throws
  {
    accountSession.statePublisher = always(
      Just(.none(lastUsed: .none))
        .eraseToAnyPublisher()
    )
    let authorizationPromptPresentationSubject: PassthroughSubject<AuthorizationPromptRequest, Never> = .init()
    accountSession.authorizationPromptPresentationPublisher = always(
      authorizationPromptPresentationSubject
        .eraseToAnyPublisher()
    )
    await features.use(accountSession)

    let controller: WindowController = try await testController()
    var result: WindowController.ScreenStateDisposition!

    controller
      .screenStateDispositionPublisher()
      .sink { result = $0 }
      .store(in: cancellables)

    authorizationPromptPresentationSubject.send(
      .passphraseRequest(
        account: validAccount,
        message: .none
      )
    )

    // temporary wait for detached tasks
    try await Task.sleep(nanoseconds: 100 * NSEC_PER_MSEC)

    guard case let .some(.requestPassphrase(account, message)) = result
    else { return XCTFail() }
    XCTAssertEqual(account, validAccount)
    XCTAssertNil(message)
  }

  func
    test_screenStateDispositionPublisher_publishesRequestMFA_whenAuthorizationPromptPresentationPublisherPublishesMFARequestAndAccountTransferIsNotLoaded()
    async throws
  {
    accountSession.statePublisher = always(
      Just(.none(lastUsed: .none))
        .eraseToAnyPublisher()
    )
    let authorizationPromptPresentationSubject: PassthroughSubject<AuthorizationPromptRequest, Never> = .init()
    accountSession.authorizationPromptPresentationPublisher = always(
      authorizationPromptPresentationSubject
        .eraseToAnyPublisher()
    )
    await features.use(accountSession)

    let controller: WindowController = try await testController()
    var result: WindowController.ScreenStateDisposition!

    controller
      .screenStateDispositionPublisher()
      .sink { result = $0 }
      .store(in: cancellables)

    authorizationPromptPresentationSubject.send(
      .mfaRequest(
        account: validAccount,
        providers: []
      )
    )

    // temporary wait for detached tasks
    try await Task.sleep(nanoseconds: 100 * NSEC_PER_MSEC)

    guard case let .some(.requestMFA(account, providers)) = result
    else { return XCTFail() }
    XCTAssertEqual(account, validAccount)
    XCTAssertEqual(providers, [])
  }

  func
    test_screenStateDispositionPublisher_doesNotPublish_whenAuthorizationPromptPresentationPublisherPublishesPassphraseRequestAndAccountTransferIsLoaded()
    async throws
  {
    await features.use(AccountTransfer.placeholder)
    accountSession.statePublisher = always(
      Just(.none(lastUsed: .none))
        .eraseToAnyPublisher()
    )
    let authorizationPromptPresentationSubject: PassthroughSubject<AuthorizationPromptRequest, Never> = .init()
    accountSession.authorizationPromptPresentationPublisher = always(
      authorizationPromptPresentationSubject
        .eraseToAnyPublisher()
    )
    await features.use(accountSession)

    let controller: WindowController = try await testController()
    var result: WindowController.ScreenStateDisposition?

    controller
      .screenStateDispositionPublisher()
      // ignore initial disposition
      .dropFirst()
      .sink { result = $0 }
      .store(in: cancellables)

    authorizationPromptPresentationSubject.send(
      .passphraseRequest(
        account: validAccount,
        message: .none
      )
    )

    XCTAssertNil(result)
  }

  func
    test_screenStateDispositionPublisher_doesNotPublish_whenAuthorizationPromptPresentationPublisherPublishesMFARequestAndAccountTransferIsLoaded()
    async throws
  {
    await features.use(AccountTransfer.placeholder)
    accountSession.statePublisher = always(
      Just(.none(lastUsed: .none))
        .eraseToAnyPublisher()
    )
    let authorizationPromptPresentationSubject: PassthroughSubject<AuthorizationPromptRequest, Never> = .init()
    accountSession.authorizationPromptPresentationPublisher = always(
      authorizationPromptPresentationSubject
        .eraseToAnyPublisher()
    )
    await features.use(accountSession)

    let controller: WindowController = try await testController()
    var result: WindowController.ScreenStateDisposition?

    controller
      .screenStateDispositionPublisher()
      // ignore initial disposition
      .dropFirst()
      .sink { result = $0 }
      .store(in: cancellables)

    authorizationPromptPresentationSubject.send(
      .mfaRequest(
        account: validAccount,
        providers: []
      )
    )

    XCTAssertNil(result)
  }

  func test_screenStateDispositionPublisher_publishesUseInitialScreenState_whenAccountSessionStateChangesToAuthorized()
    async throws
  {
    let accountSessionStateSubject: CurrentValueSubject<AccountSessionState, Never> = .init(.none(lastUsed: .none))
    accountSession.statePublisher = always(
      accountSessionStateSubject
        .eraseToAnyPublisher()
    )
    let authorizationPromptPresentationSubject: PassthroughSubject<AuthorizationPromptRequest, Never> = .init()
    accountSession.authorizationPromptPresentationPublisher = always(
      authorizationPromptPresentationSubject
        .eraseToAnyPublisher()
    )
    await features.use(accountSession)

    let controller: WindowController = try await testController()
    var result: WindowController.ScreenStateDisposition!

    controller
      .screenStateDispositionPublisher()
      .sink { result = $0 }
      .store(in: cancellables)

    accountSessionStateSubject.send(.authorized(validAccount))

    // temporary wait for detached tasks
    try await Task.sleep(nanoseconds: 100 * NSEC_PER_MSEC)

    guard case .some(.useInitialScreenState) = result
    else { return XCTFail() }
  }

  func
    test_screenStateDispositionPublisher_doesNotPublish_whenAccountSessionStateChangesToAuthorizedMFARequired()
    async throws
  {
    let accountSessionStateSubject: CurrentValueSubject<AccountSessionState, Never> = .init(.none(lastUsed: .none))
    accountSession.statePublisher = always(
      accountSessionStateSubject
        .eraseToAnyPublisher()
    )
    accountSession.authorizationPromptPresentationPublisher = always(
      Empty().eraseToAnyPublisher()
    )
    await features.use(accountSession)

    let controller: WindowController = try await testController()
    var result: WindowController.ScreenStateDisposition!

    controller
      .screenStateDispositionPublisher()
      .dropFirst()
      .sink { result = $0 }
      .store(in: cancellables)

    accountSessionStateSubject.send(.authorizedMFARequired(validAccount, providers: [.totp]))

    XCTAssertNil(result)
  }

  func
    test_screenStateDispositionPublisher_doesNotPublish_whenAccountSessionStateChangesToAuthorizedAndAccountTransferIsLoaded()
    async throws
  {
    await features.use(AccountTransfer.placeholder)
    let accountSessionStateSubject: CurrentValueSubject<AccountSessionState, Never> = .init(.none(lastUsed: .none))
    accountSession.statePublisher = always(
      accountSessionStateSubject
        .eraseToAnyPublisher()
    )
    accountSession.authorizationPromptPresentationPublisher = always(
      Empty().eraseToAnyPublisher()
    )
    await features.use(accountSession)

    let controller: WindowController = try await testController()
    var result: WindowController.ScreenStateDisposition!

    controller
      .screenStateDispositionPublisher()
      .dropFirst()
      .sink { result = $0 }
      .store(in: cancellables)

    accountSessionStateSubject.send(.authorized(validAccount))

    XCTAssertNil(result)
  }

  func
    test_screenStateDispositionPublisher_doesNotPublish_whenAccountSessionStateChangesToAuthorizedMFARequiredAndAccountTransferIsLoaded()
    async throws
  {
    await features.use(AccountTransfer.placeholder)
    let accountSessionStateSubject: CurrentValueSubject<AccountSessionState, Never> = .init(.none(lastUsed: .none))
    accountSession.statePublisher = always(
      accountSessionStateSubject
        .eraseToAnyPublisher()
    )
    accountSession.authorizationPromptPresentationPublisher = always(
      Empty().eraseToAnyPublisher()
    )
    await features.use(accountSession)

    let controller: WindowController = try await testController()
    var result: WindowController.ScreenStateDisposition!

    controller
      .screenStateDispositionPublisher()
      .dropFirst()
      .sink { result = $0 }
      .store(in: cancellables)

    accountSessionStateSubject.send(.authorizedMFARequired(validAccount, providers: [.totp]))

    XCTAssertNil(result)
  }

  func
    test_screenStateDispositionPublisher_publishesUseCachedScreenState_whenAccountSessionStateChangesToAuthorized_andAuthorizationPromptPresentationSubjectPublishedSameAccountPassphraseRequest()
    async throws
  {
    let accountSessionStateSubject: CurrentValueSubject<AccountSessionState, Never> = .init(.none(lastUsed: .none))
    accountSession.statePublisher = always(
      accountSessionStateSubject
        .eraseToAnyPublisher()
    )
    let authorizationPromptPresentationSubject: PassthroughSubject<AuthorizationPromptRequest, Never> = .init()
    accountSession.authorizationPromptPresentationPublisher = always(
      authorizationPromptPresentationSubject
        .eraseToAnyPublisher()
    )
    await features.use(accountSession)

    let controller: WindowController = try await testController()
    var result: WindowController.ScreenStateDisposition!

    controller
      .screenStateDispositionPublisher()
      .sink {
        result = $0
      }
      .store(in: cancellables)

    authorizationPromptPresentationSubject.send(
      .passphraseRequest(
        account: validAccount,
        message: .none
      )
    )

    // temporary wait for detached tasks
    try await Task.sleep(nanoseconds: 100 * NSEC_PER_MSEC)

    accountSessionStateSubject.send(.authorized(validAccount))

    // temporary wait for detached tasks
    try await Task.sleep(nanoseconds: 100 * NSEC_PER_MSEC)

    guard case .some(.useCachedScreenState) = result
    else { return XCTFail() }
  }

  func
    test_screenStateDispositionPublisher_publishesUseCachedScreenState_whenAccountSessionStateChangesToAuthorized_andAuthorizationPromptPresentationSubjectPublishedSameAccountMFARequest()
    async throws
  {
    let accountSessionStateSubject: CurrentValueSubject<AccountSessionState, Never> = .init(.none(lastUsed: .none))
    accountSession.statePublisher = always(
      accountSessionStateSubject
        .eraseToAnyPublisher()
    )
    let authorizationPromptPresentationSubject: PassthroughSubject<AuthorizationPromptRequest, Never> = .init()
    accountSession.authorizationPromptPresentationPublisher = always(
      authorizationPromptPresentationSubject
        .eraseToAnyPublisher()
    )
    await features.use(accountSession)

    let controller: WindowController = try await testController()
    var result: WindowController.ScreenStateDisposition!

    controller
      .screenStateDispositionPublisher()
      .dropFirst()
      .sink { result = $0 }
      .store(in: cancellables)

    authorizationPromptPresentationSubject.send(
      .mfaRequest(
        account: validAccount,
        providers: []
      )
    )

    // temporary wait for detached tasks
    try await Task.sleep(nanoseconds: 100 * NSEC_PER_MSEC)

    accountSessionStateSubject.send(.authorized(validAccount))

    // temporary wait for detached tasks
    try await Task.sleep(nanoseconds: 100 * NSEC_PER_MSEC)

    guard case .some(.useCachedScreenState) = result
    else { return XCTFail() }
  }
}

private let validAccount: Account = .init(
  localID: .init(rawValue: UUID.test.uuidString),
  domain: "https://passbolt.dev",
  userID: "USER_ID",
  fingerprint: "FINGERPRINT"
)
