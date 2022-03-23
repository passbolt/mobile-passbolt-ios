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

import TestExtensions
import UIComponents

@testable import Accounts
@testable import PassboltExtension

// swift-format-ignore: AlwaysUseLowerCamelCase, NeverUseImplicitlyUnwrappedOptionals
@MainActor
final class ExtensionControllerTests: MainActorTestCase {

  var accounts: Accounts! = .placeholder
  var accountSession: AccountSession! = .placeholder

  override func mainActorSetUp() {
    accounts = .placeholder
    accountSession = .placeholder
  }

  override func mainActorTearDown() {
    accounts = nil
    accountSession = nil
  }

  func test_destinationPublisher_publishesAccountSelection_whenNoAccounts_arePresent_andNotAuthorized() async throws {
    accounts.storedAccounts = always([])
    await features.use(accounts)

    accountSession.statePublisher = always(Just(.none(lastUsed: nil)).eraseToAnyPublisher())
    accountSession.authorizationPromptPresentationPublisher = always(Empty().eraseToAnyPublisher())
    await features.use(accountSession)

    let controller: ExtensionController = try await testController()
    var result: ExtensionController.Destination?

    controller.destinationPublisher()
      .sink { destination in
        result = destination
      }
      .store(in: cancellables)

    // temporary wait for detached tasks
    try await Task.sleep(nanoseconds: 100 * NSEC_PER_MSEC)

    XCTAssertEqual(result, .accountSelection(lastUsedAccount: nil))
  }

  func test_destinationPublisher_publishesHome_whenAccount_isPresent_andAuthorized() async throws {
    accounts.storedAccounts = always([firstAccount])
    await features.use(accounts)

    accountSession.statePublisher = always(Just(.authorized(firstAccount)).eraseToAnyPublisher())
    accountSession.authorizationPromptPresentationPublisher = always(Empty().eraseToAnyPublisher())
    await features.use(accountSession)

    let controller: ExtensionController = try await testController()
    var result: ExtensionController.Destination?

    controller.destinationPublisher()
      .sink { destination in
        result = destination
      }
      .store(in: cancellables)

    XCTAssertEqual(result, .home(firstAccount))
  }

  func test_destinationPublisher_doesNotPublish_whenSessionAuthorizationRequired() async throws {
    accounts.storedAccounts = always([firstAccount, secondAccount])
    await features.use(accounts)

    accountSession.statePublisher = always(Just(.authorizationRequired(secondAccount)).eraseToAnyPublisher())
    accountSession.authorizationPromptPresentationPublisher = always(Empty().eraseToAnyPublisher())
    await features.use(accountSession)

    let controller: ExtensionController = try await testController()
    var result: ExtensionController.Destination?

    controller.destinationPublisher()
      .sink { destination in
        result = destination
      }
      .store(in: cancellables)

    XCTAssertNil(result)
  }

  func test_destinationPublisher_publishesAccountSelection_whenLastUsedAccount_isPresent_andNotAuthorized() async throws
  {
    accounts.storedAccounts = always([firstAccount, secondAccount])
    await features.use(accounts)

    accountSession.statePublisher = always(Just(.none(lastUsed: secondAccount)).eraseToAnyPublisher())
    accountSession.authorizationPromptPresentationPublisher = always(Empty().eraseToAnyPublisher())
    await features.use(accountSession)

    let controller: ExtensionController = try await testController()
    var result: ExtensionController.Destination?

    controller.destinationPublisher()
      .sink { destination in
        result = destination
      }
      .store(in: cancellables)

    XCTAssertEqual(result, .accountSelection(lastUsedAccount: secondAccount))
  }

  func test_sessionCloses_whenAuthorizationPromptIsRequired() async throws {
    await features.use(accounts)

    var result: Void?
    accountSession.close = {
      result = Void()
    }
    accountSession.statePublisher = always(Just(.authorized(.validAccount)).eraseToAnyPublisher())
    let authorizationPromptPresentationSubject: PassthroughSubject<AuthorizationPromptRequest, Never> = .init()
    accountSession.authorizationPromptPresentationPublisher = always(
      authorizationPromptPresentationSubject.eraseToAnyPublisher()
    )
    await features.use(accountSession)

    let controller: ExtensionController = try await testController()
    _ = controller  // silence warning

    authorizationPromptPresentationSubject
      .send(
        .passphraseRequest(
          account: firstAccount,
          message: .none
        )
      )

    // temporary wait for detached tasks
    try await Task.sleep(nanoseconds: 100 * NSEC_PER_MSEC)

    XCTAssertNotNil(result)
  }
}

private let firstAccount: Account = .init(
  localID: "1",
  domain: "passbolt.com",
  userID: "11",
  fingerprint: ""
)

private let secondAccount: Account = .init(
  localID: "2",
  domain: "passbolt.com",
  userID: "22",
  fingerprint: ""
)
