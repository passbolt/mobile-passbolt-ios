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

  var sessionUpdates: UpdatesSequenceSource!

  override func mainActorSetUp() {
    features.patch(
      \Accounts.storedAccounts,
      with: always([])
    )
    features.patch(
      \Accounts.lastUsedAccount,
      with: always(.none)
    )
    features.patch(
      \Session.currentAccount,
      with: alwaysThrow(SessionMissing.error())
    )
    sessionUpdates = .init()
    features.patch(
      \Session.updatesSequence,
      with: sessionUpdates.updatesSequence
    )
    features.patch(
      \Session.pendingAuthorization,
      with: always(.none)
    )
  }

  override func mainActorTearDown() {
    sessionUpdates = .none
  }

  func test_destinationPublisher_publishesAccountSelection_whenNoAccounts_arePresent_andNotAuthorized() async throws {

    let controller: ExtensionController = try await testController()
    var result: ExtensionController.Destination?

    controller.destinationPublisher()
      .sink { destination in
        result = destination
      }
      .store(in: cancellables)

    // temporary wait for detached tasks
    try await Task.sleep(nanoseconds: 300 * NSEC_PER_MSEC)

    XCTAssertEqual(result, .accountSelection(lastUsedAccount: nil))
  }

  func test_destinationPublisher_publishesHome_whenAccount_isPresent_andAuthorized() async throws {
    features.patch(
      \Accounts.storedAccounts,
      with: always([firstAccount])
    )
    features.patch(
      \Session.currentAccount,
      with: always(firstAccount)
    )

    let controller: ExtensionController = try await testController()
    var result: ExtensionController.Destination?

    controller.destinationPublisher()
      .sink { destination in
        result = destination
      }
      .store(in: cancellables)

    sessionUpdates.sendUpdate()

    // temporary wait for detached tasks
    try await Task.sleep(nanoseconds: 300 * NSEC_PER_MSEC)

    XCTAssertEqual(result, .home(firstAccount))
  }

  func test_destinationPublisher_publishesAccountSelectionInitially_whenNoActiveSession() async throws {
    features.patch(
      \Accounts.storedAccounts,
      with: always([firstAccount, secondAccount])
    )

    let controller: ExtensionController = try await testController()
    var result: ExtensionController.Destination?

    controller.destinationPublisher()
      .sink { destination in
        result = destination
      }
      .store(in: cancellables)

    sessionUpdates.sendUpdate()

    // temporary wait for detached tasks
    try await Task.sleep(nanoseconds: 300 * NSEC_PER_MSEC)

    XCTAssertEqual(result, .accountSelection(lastUsedAccount: .none))
  }

  func test_destinationPublisher_publishesAccountSelection_whenLastUsedAccount_isPresent_andNotAuthorized() async throws
  {
    features.patch(
      \Accounts.storedAccounts,
      with: always([firstAccount, secondAccount])
    )
    features.patch(
      \Accounts.lastUsedAccount,
      with: always(secondAccount)
    )
    features.patch(
      \Session.pendingAuthorization,
      with: always(.passphrase(secondAccount))
    )

    let controller: ExtensionController = try await testController()
    var result: ExtensionController.Destination?

    controller.destinationPublisher()
      .sink { destination in
        result = destination
      }
      .store(in: cancellables)

    sessionUpdates.sendUpdate()

    // temporary wait for detached tasks
    try await Task.sleep(nanoseconds: 300 * NSEC_PER_MSEC)

    XCTAssertEqual(result, .accountSelection(lastUsedAccount: .none))
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
