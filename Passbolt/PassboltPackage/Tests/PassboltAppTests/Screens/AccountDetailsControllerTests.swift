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

import FeatureScopes
import TestExtensions
import UIComponents
import XCTest

@testable import Accounts
@testable import PassboltApp

// swift-format-ignore: AlwaysUseLowerCamelCase, NeverUseImplicitlyUnwrappedOptionals
@available(iOS 16.0.0, *)
@MainActor
final class AccountDetailsControllerTests: MainActorTestCase {

  var detailsUpdates: Updates!
  var preferencesUpdates: Updates!

  override func mainActorSetUp() {
    features
      .set(
        SessionScope.self,
        context: .init(
          account: .mock_ada,
          configuration: .mock_1
        )
      )
    detailsUpdates = .init()
    features.patch(
      \AccountDetails.updates,
      context: Account.mock_ada,
      with: detailsUpdates.asAnyUpdatable()
    )
    features.patch(
      \AccountDetails.avatarImage,
      context: Account.mock_ada,
      with: always(.init())
    )
    features.patch(
      \AccountDetails.profile,
      context: Account.mock_ada,
      with: always(.mock_ada)
    )
    preferencesUpdates = .init()
    features.patch(
      \AccountPreferences.updates,
      context: Account.mock_ada,
      with: preferencesUpdates.asAnyUpdatable()
    )
  }

  func test_currentAccountWithProfile_isEqualToProvidedInContext() async throws {
    let controller: AccountDetailsController = try await testController()

    XCTAssertEqual(controller.currentAccountWithProfile, AccountWithProfile.mock_ada)
  }

  func test_currentAcountAvatarImagePublisher_usesAccountDetailsToRequestImage() async throws {

    let result: UnsafeSendable<Void?> = .init()
    features.patch(
      \AccountDetails.avatarImage,
      context: Account.mock_ada,
      with: { () async throws in
        result.value = Void()
        return .init()
      }
    )

    let controller: AccountDetailsController = try await testController()

    try await controller
      .currentAcountAvatarImagePublisher()
      .asAsyncValue()

    XCTAssertNotNil(result.value)
  }

  func test_validatedAccountLabelPublisher_publishesInitialAccountLabel() async throws {
    let controller: AccountDetailsController = try await testController()

    var result: Validated<String>?
    controller
      .validatedAccountLabelPublisher()
      .sink { validatedLabel in
        result = validatedLabel
      }
      .store(in: cancellables)

    XCTAssertEqual(result?.value, AccountWithProfile.mock_ada.label)
  }

  func test_validatedAccountLabelPublisher_publishesValidValueWhenLabelIsValid() async throws {
    let controller: AccountDetailsController = try await testController()

    var result: Validated<String>?
    controller
      .updateCurrentAccountLabel(Array<String>(repeating: "a", count: 10).joined())
    controller
      .validatedAccountLabelPublisher()
      .sink { validatedLabel in
        result = validatedLabel
      }
      .store(in: cancellables)

    XCTAssertTrue(result?.isValid ?? false)
  }

  func test_validatedAccountLabelPublisher_publishesInvalidValueWhenLabelIsTooLong() async throws {
    let controller: AccountDetailsController = try await testController()

    var result: Validated<String>?
    controller
      .updateCurrentAccountLabel(Array<String>(repeating: "a", count: 81).joined())
    controller
      .validatedAccountLabelPublisher()
      .sink { validatedLabel in
        result = validatedLabel
      }
      .store(in: cancellables)

    XCTAssertFalse(result?.isValid ?? true)
  }

  func test_updateCurrentAccountLabel_updatesLabel() async throws {
    let controller: AccountDetailsController = try await testController()

    var result: Validated<String>?
    controller
      .validatedAccountLabelPublisher()
      .sink { validatedLabel in
        result = validatedLabel
      }
      .store(in: cancellables)

    controller.updateCurrentAccountLabel("updated")

    XCTAssertNotEqual(result?.value, AccountWithProfile.mock_ada.label)
  }

  func test_saveChanges_fails_whenLabelValidationFails() async throws {
    let controller: AccountDetailsController = try await testController()

    controller
      .updateCurrentAccountLabel(Array<String>(repeating: "a", count: 81).joined())

    var result: Error?
    do {
      try await controller
        .saveChanges()
        .asAsyncValue()
      XCTFail()
    }
    catch {
      result = error
    }

    XCTAssertError(result, matches: InvalidForm.self)
  }

  func test_saveChanges_usesDefaultLabel_whenLabelIsEmpty() async throws {
    let result: UnsafeSendable<String> = .init()
    features.patch(
      \AccountPreferences.setLocalAccountLabel,
      context: Account.mock_ada,
      with: { label in
        result.value = label
      }
    )

    let controller: AccountDetailsController = try await testController()

    controller.updateCurrentAccountLabel("")

    try await controller
      .saveChanges()
      .asAsyncValue()

    XCTAssertEqual(result.value, "\(AccountWithProfile.mock_ada.firstName) \(AccountWithProfile.mock_ada.lastName)")
  }

  func test_saveChanges_fails_whenLabelSaveFails() async throws {
    features.patch(
      \AccountPreferences.setLocalAccountLabel,
      context: Account.mock_ada,
      with: alwaysThrow(MockIssue.error())
    )

    let controller: AccountDetailsController = try await testController()

    var result: Error?
    do {
      try await controller
        .saveChanges()
        .asAsyncValue()
      XCTFail()
    }
    catch {
      result = error
    }

    XCTAssertError(result, matches: MockIssue.self)
  }

  func test_saveChanges_succeeds_whenLabelSaveSucceeds() async throws {
    let result: UnsafeSendable<String> = .init()
    features.patch(
      \AccountPreferences.setLocalAccountLabel,
      context: Account.mock_ada,
      with: { label in
        result.value = label
      }
    )

    let controller: AccountDetailsController = try await testController()

    try await controller
      .saveChanges()
      .asAsyncValue()

    XCTAssertEqual(result.value, AccountWithProfile.mock_ada.label)
  }
}
