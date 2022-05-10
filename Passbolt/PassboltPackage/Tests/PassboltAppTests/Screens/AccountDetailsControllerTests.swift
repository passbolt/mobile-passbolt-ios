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
final class AccountDetailsControllerTests: MainActorTestCase {

  override func featuresActorSetUp() async throws {
    try await super.featuresActorSetUp()
    features.usePlaceholder(for: AccountSettings.self)
    features.usePlaceholder(for: NetworkClient.self)
  }

  func test_currentAccountWithProfile_isEqualToProvidedInContext() async throws {
    let controller: AccountDetailsController = try await testController(
      context: validAccountWithProfile
    )

    XCTAssertEqual(controller.currentAccountWithProfile, validAccountWithProfile)
  }

  func test_currentAcountAvatarImagePublisher_usesMediaDownloadToRequestImage() async throws {

    var result: MediaDownloadRequestVariable?
    await features
      .patch(
        \NetworkClient.mediaDownload,
        with: .respondingWith(
          MediaDownloadResponse(),
          storeVariableIn: &result
        )
      )
    let controller: AccountDetailsController = try await testController(
      context: validAccountWithProfile
    )

    try await controller
      .currentAcountAvatarImagePublisher()
      .asAsyncValue()

    XCTAssertEqual(result, validAccountWithProfile.avatarImageURL)
  }

  func test_validatedAccountLabelPublisher_publishesInitialAccountLabel() async throws {
    let controller: AccountDetailsController = try await testController(
      context: validAccountWithProfile
    )

    var result: Validated<String>?
    controller
      .validatedAccountLabelPublisher()
      .sink { validatedLabel in
        result = validatedLabel
      }
      .store(in: cancellables)

    XCTAssertEqual(result?.value, validAccountWithProfile.label)
  }

  func test_validatedAccountLabelPublisher_publishesValidValueWhenLabelIsValid() async throws {
    let controller: AccountDetailsController = try await testController(
      context: validAccountWithProfile
    )

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
    let controller: AccountDetailsController = try await testController(
      context: validAccountWithProfile
    )

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
    let controller: AccountDetailsController = try await testController(
      context: validAccountWithProfile
    )

    var result: Validated<String>?
    controller
      .validatedAccountLabelPublisher()
      .sink { validatedLabel in
        result = validatedLabel
      }
      .store(in: cancellables)

    controller.updateCurrentAccountLabel("updated")

    XCTAssertNotEqual(result?.value, validAccountWithProfile.label)
  }

  func test_saveChanges_fails_whenLabelValidationFails() async throws {
    let controller: AccountDetailsController = try await testController(
      context: validAccountWithProfile
    )

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
    var result: String?
    await features.patch(
      \AccountSettings.setAccountLabel,
      with: { label, _ in
        result = label
        return .success
      }
    )
    let controller: AccountDetailsController = try await testController(
      context: validAccountWithProfile
    )

    controller.updateCurrentAccountLabel("")

    try await controller
      .saveChanges()
      .asAsyncValue()

    XCTAssertEqual(result, "\(validAccountWithProfile.firstName) \(validAccountWithProfile.lastName)")
  }

  func test_saveChanges_fails_whenLabelSaveFails() async throws {
    await features.patch(
      \AccountSettings.setAccountLabel,
      with: always(.failure(MockIssue.error()))
    )

    let controller: AccountDetailsController = try await testController(
      context: validAccountWithProfile
    )

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
    var result: String?
    await features.patch(
      \AccountSettings.setAccountLabel,
      with: { label, _ in
        result = label
        return .success
      }
    )
    let controller: AccountDetailsController = try await testController(
      context: validAccountWithProfile
    )

    try await controller
      .saveChanges()
      .asAsyncValue()

    XCTAssertEqual(result, validAccountWithProfile.label)
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
