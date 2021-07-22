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
final class WindowTests: TestCase {

  var accountSession: AccountSession!

  override func setUp() {
    super.setUp()
    accountSession = .placeholder
  }

  override func tearDown() {
    accountSession = nil
    super.tearDown()
  }

  func test_screenStateDispositionPublisher_publishesInitialScreen_initially() {
    let accountSessionStateSubject: CurrentValueSubject<AccountSession.State, Never> = .init(.none(lastUsed: .none))
    accountSession.statePublisher = always(
      accountSessionStateSubject
        .eraseToAnyPublisher()
    )
    accountSession.authorizationPromptPresentationPublisher = always(
      Empty<Account.LocalID, Never>()
        .eraseToAnyPublisher()
    )
    features.use(accountSession)

    let controller: WindowController = testInstance()
    var result: WindowController.ScreenStateDisposition!

    controller
      .screenStateDispositionPublisher()
      .sink { result = $0 }
      .store(in: cancellables)

    guard case .some(.useInitialScreenState) = result
    else { return XCTFail() }
  }

  func test_screenStateDispositionPublisher_publishesAuthorize_whenAuthorizationPromptPresentationPublisherPublishes() {
    let accountSessionStateSubject: CurrentValueSubject<AccountSession.State, Never> = .init(.none(lastUsed: .none))
    accountSession.statePublisher = always(
      accountSessionStateSubject
        .eraseToAnyPublisher()
    )
    let authorizationPromptPresentationSubject: PassthroughSubject<Account.LocalID, Never> = .init()
    accountSession.authorizationPromptPresentationPublisher = always(
      authorizationPromptPresentationSubject
        .eraseToAnyPublisher()
    )
    features.use(accountSession)

    let controller: WindowController = testInstance()
    var result: WindowController.ScreenStateDisposition!

    controller
      .screenStateDispositionPublisher()
      .sink { result = $0 }
      .store(in: cancellables)

    authorizationPromptPresentationSubject.send(validAccount.localID)

    guard case let .some(.authorize(accountID)) = result
    else { return XCTFail() }
    XCTAssertEqual(accountID, validAccount.localID)
  }

  func
    test_screenStateDispositionPublisher_publishesAuthorize_whenAuthorizationPromptPresentationPublisherPublishesAndAccountTransferIsLoaded()
  {
    features.use(AccountTransfer.placeholder)
    let accountSessionStateSubject: CurrentValueSubject<AccountSession.State, Never> = .init(.none(lastUsed: .none))
    accountSession.statePublisher = always(
      accountSessionStateSubject
        .eraseToAnyPublisher()
    )
    let authorizationPromptPresentationSubject: PassthroughSubject<Account.LocalID, Never> = .init()
    accountSession.authorizationPromptPresentationPublisher = always(
      authorizationPromptPresentationSubject
        .eraseToAnyPublisher()
    )
    features.use(accountSession)

    let controller: WindowController = testInstance()
    var result: WindowController.ScreenStateDisposition!

    controller
      .screenStateDispositionPublisher()
      .sink { result = $0 }
      .store(in: cancellables)

    authorizationPromptPresentationSubject.send(validAccount.localID)

    guard case let .some(.authorize(accountID)) = result
    else { return XCTFail() }
    XCTAssertEqual(accountID, validAccount.localID)
  }

  func test_screenStateDispositionPublisher_publishesUseInitialScreenState_whenAccountSessionStateChangesToAuthorized()
  {
    let accountSessionStateSubject: CurrentValueSubject<AccountSession.State, Never> = .init(.none(lastUsed: .none))
    accountSession.statePublisher = always(
      accountSessionStateSubject
        .eraseToAnyPublisher()
    )
    let authorizationPromptPresentationSubject: PassthroughSubject<Account.LocalID, Never> = .init()
    accountSession.authorizationPromptPresentationPublisher = always(
      authorizationPromptPresentationSubject
        .eraseToAnyPublisher()
    )
    features.use(accountSession)

    let controller: WindowController = testInstance()
    var result: WindowController.ScreenStateDisposition!

    controller
      .screenStateDispositionPublisher()
      .sink { result = $0 }
      .store(in: cancellables)

    accountSessionStateSubject.send(.authorized(validAccount))

    guard case .some(.useInitialScreenState) = result
    else { return XCTFail() }
  }

  func
    test_screenStateDispositionPublisher_doesNotPublish_whenAccountSessionStateChangesToAuthorizedAndAccountTransferIsLoaded()
  {
    features.use(AccountTransfer.placeholder)
    let accountSessionStateSubject: CurrentValueSubject<AccountSession.State, Never> = .init(.none(lastUsed: .none))
    accountSession.statePublisher = always(
      accountSessionStateSubject
        .eraseToAnyPublisher()
    )
    accountSession.authorizationPromptPresentationPublisher = always(
      Empty().eraseToAnyPublisher()
    )
    features.use(accountSession)

    let controller: WindowController = testInstance()
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
    test_screenStateDispositionPublisher_publishesUseCachedScreenState_whenAccountSessionStateChangesToAuthorized_andAuthorizationPromptPresentationSubjectPublishedSameAccountID()
  {
    let accountSessionStateSubject: CurrentValueSubject<AccountSession.State, Never> = .init(.none(lastUsed: .none))
    accountSession.statePublisher = always(
      accountSessionStateSubject
        .eraseToAnyPublisher()
    )
    let authorizationPromptPresentationSubject: PassthroughSubject<Account.LocalID, Never> = .init()
    accountSession.authorizationPromptPresentationPublisher = always(
      authorizationPromptPresentationSubject
        .eraseToAnyPublisher()
    )
    features.use(accountSession)

    let controller: WindowController = testInstance()
    var result: WindowController.ScreenStateDisposition!

    controller
      .screenStateDispositionPublisher()
      .sink { result = $0 }
      .store(in: cancellables)

    authorizationPromptPresentationSubject.send(validAccount.localID)
    accountSessionStateSubject.send(.authorized(validAccount))

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
