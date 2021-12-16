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
final class AccountDetailsControllerTests: TestCase {

  override func setUp() {
    super.setUp()
    features.usePlaceholder(for: AccountSettings.self)
    features.usePlaceholder(for: NetworkClient.self)
  }

  func test_currentAccountWithProfile_isEqualToProvidedInContext() {
    let controller: AccountDetailsController = testInstance(
      context: validAccountWithProfile
    )

    XCTAssertEqual(controller.currentAccountWithProfile, validAccountWithProfile)
  }

  func test_currentAcountAvatarImagePublisher_usesMediaDownloadToRequestImage() {

    var result: MediaDownloadRequestVariable?
    features
      .patch(
        \NetworkClient.mediaDownload,
         with: .respondingWith(
          MediaDownloadResponse(),
          storeVariableIn: &result
         )
      )
    let controller: AccountDetailsController = testInstance(
      context: validAccountWithProfile
    )

    controller
      .currentAcountAvatarImagePublisher()
      .sinkDrop()
      .store(in: cancellables)

    XCTAssertEqual(result?.urlString, validAccountWithProfile.avatarImageURL)
  }

  func test_validatedAccountLabelPublisher_publishesInitialAccountLabel() {
    let controller: AccountDetailsController = testInstance(
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

  func test_validatedAccountLabelPublisher_publishesValidValueWhenLabelIsValid() {
    let controller: AccountDetailsController = testInstance(
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

  func test_validatedAccountLabelPublisher_publishesInvalidValueWhenLabelIsTooLong() {
    let controller: AccountDetailsController = testInstance(
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

  func test_updateCurrentAccountLabel_updatesLabel() {
    let controller: AccountDetailsController = testInstance(
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

  func test_saveChanges_fails_whenLabelValidationFails() {
    let controller: AccountDetailsController = testInstance(
      context: validAccountWithProfile
    )

    controller
      .updateCurrentAccountLabel(Array<String>(repeating: "a", count: 81).joined())

    var result: TheError?
    controller
      .saveChanges()
      .sink(
        receiveCompletion: { completion in
          guard case let .failure(error) = completion
          else { return }
          result = error
        },
        receiveValue: { /* NOP */ }
      )
      .store(in: cancellables)

    XCTAssertEqual(result?.identifier, .validation)
  }

  func test_saveChanges_usesDefaultLabel_whenLabelIsEmpty() {
    var result: String?
    features.patch(
      \AccountSettings.setAccountLabel,
       with: { label, _ in
         result = label
         return .success
       }
    )
    let controller: AccountDetailsController = testInstance(
      context: validAccountWithProfile
    )

    controller.updateCurrentAccountLabel("")


    controller
      .saveChanges()
      .sinkDrop()
      .store(in: cancellables)

    XCTAssertEqual(result, "\(validAccountWithProfile.firstName) \(validAccountWithProfile.lastName)")
  }

  func test_saveChanges_fails_whenLabelSaveFails() {
    features.patch(
      \AccountSettings.setAccountLabel,
       with: always(.failure(.testError()))
    )

    let controller: AccountDetailsController = testInstance(
      context: validAccountWithProfile
    )

    var result: TheError?
    controller
      .saveChanges()
      .sink(
        receiveCompletion: { completion in
          guard case let .failure(error) = completion
          else { return }
          result = error
        },
        receiveValue: { /* NOP */ }
      )
      .store(in: cancellables)

    XCTAssertEqual(result?.identifier, .testError)
  }

  func test_saveChanges_succeeds_whenLabelSaveSucceeds() {
    var result: String?
    features.patch(
      \AccountSettings.setAccountLabel,
       with: { label, _ in
         result = label
         return .success
       }
    )
    let controller: AccountDetailsController = testInstance(
      context: validAccountWithProfile
    )

    controller
      .saveChanges()
      .sinkDrop()
      .store(in: cancellables)

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

//private let validAccountAlt: Account = .init(
//  localID: .init(rawValue: UUID.testAlt.uuidString),
//  domain: "passbolt.com",
//  userID: .init(rawValue: UUID.testAlt.uuidString),
//  fingerprint: "fingerprint"
//)
//
//private let validAccountProfileAlt: AccountProfile = .init(
//  accountID: .init(rawValue: UUID.testAlt.uuidString),
//  label: "firstName lastName",
//  username: "username",
//  firstName: "firstName",
//  lastName: "lastName",
//  avatarImageURL: "avatarImagePath",
//  biometricsEnabled: false
//)
//
//private let validAccountWithProfileAlt: AccountWithProfile = .init(
//  account: validAccountAlt,
//  profile: validAccountProfileAlt
//)
//
