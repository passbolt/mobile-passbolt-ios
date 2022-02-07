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

  func test_destinationPublisher_publishesAccountSelection_whenNoAccounts_arePresent_andNotAuthorized() {
    accounts.storedAccounts = always([])
    features.use(accounts)

    accountSession.statePublisher = always(Just(.none(lastUsed: nil)).eraseToAnyPublisher())
    accountSession.authorizationPromptPresentationPublisher = always(Empty().eraseToAnyPublisher())
    features.use(accountSession)

    let controller: ExtensionController = testController()
    var result: ExtensionController.Destination?

    controller.destinationPublisher()
      .sink { destination in
        result = destination
      }
      .store(in: cancellables)

    XCTAssertEqual(result, .accountSelection(lastUsedAccount: nil))
  }

  func test_destinationPublisher_publishesHome_whenAccount_isPresent_andAuthorized() {
    accounts.storedAccounts = always([firstAccount])
    features.use(accounts)

    accountSession.statePublisher = always(Just(.authorized(firstAccount)).eraseToAnyPublisher())
    accountSession.authorizationPromptPresentationPublisher = always(Empty().eraseToAnyPublisher())
    features.use(accountSession)

    let controller: ExtensionController = testController()
    var result: ExtensionController.Destination?

    controller.destinationPublisher()
      .sink { destination in
        result = destination
      }
      .store(in: cancellables)

    XCTAssertEqual(result, .home(firstAccount))
  }

  func test_destinationPublisher_doesNotPublish_whenSessionAuthorizationRequired() {
    accounts.storedAccounts = always([firstAccount, secondAccount])
    features.use(accounts)

    accountSession.statePublisher = always(Just(.authorizationRequired(secondAccount)).eraseToAnyPublisher())
    accountSession.authorizationPromptPresentationPublisher = always(Empty().eraseToAnyPublisher())
    features.use(accountSession)

    let controller: ExtensionController = testController()
    var result: ExtensionController.Destination?

    controller.destinationPublisher()
      .sink { destination in
        result = destination
      }
      .store(in: cancellables)

    XCTAssertNil(result)
  }

  func test_destinationPublisher_publishesAccountSelection_whenLastUsedAccount_isPresent_andNotAuthorized() {
    accounts.storedAccounts = always([firstAccount, secondAccount])
    features.use(accounts)

    accountSession.statePublisher = always(Just(.none(lastUsed: secondAccount)).eraseToAnyPublisher())
    accountSession.authorizationPromptPresentationPublisher = always(Empty().eraseToAnyPublisher())
    features.use(accountSession)

    let controller: ExtensionController = testController()
    var result: ExtensionController.Destination?

    controller.destinationPublisher()
      .sink { destination in
        result = destination
      }
      .store(in: cancellables)

    XCTAssertEqual(result, .accountSelection(lastUsedAccount: secondAccount))
  }

  func test_sessionCloses_whenAuthorizationPromptIsRequired() {
    features.use(accounts)

    var result: Void?
    accountSession.close = {
      result = Void()
    }
    accountSession.statePublisher = always(Empty().eraseToAnyPublisher())
    let authorizationPromptPresentationSubject: PassthroughSubject<AuthorizationPromptRequest, Never> = .init()
    accountSession.authorizationPromptPresentationPublisher = always(
      authorizationPromptPresentationSubject.eraseToAnyPublisher()
    )
    features.use(accountSession)

    let controller: ExtensionController = testController()
    _ = controller  // silence warning

    authorizationPromptPresentationSubject
      .send(
        .passphraseRequest(
          account: firstAccount,
          message: .none
        )
      )

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
