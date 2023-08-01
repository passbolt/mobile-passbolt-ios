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

import CommonModels
import Crypto
import Features
import TestExtensions
import UIComponents

@testable import Accounts
@testable import SharedUIComponents

// swift-format-ignore: AlwaysUseLowerCamelCase, NeverUseImplicitlyUnwrappedOptionals
@MainActor @available(iOS 16.0.0, *)
final class ServerFingerprintControllerTests: MainActorTestCase {

  override func mainActorSetUp() {
    features.usePlaceholder(for: AccountsDataStore.self)
  }

  override func mainActorTearDown() {
  }

  func test_fingerprint_isCorrectlyFormatted() async throws {
    let controller: ServerFingerprintController = try testController(
      context: (accountID: accountID, fingerprint: validFingerprint)
    )

    let result: Fingerprint = controller.formattedFingerprint()

    XCTAssertEqual(result, "E8FE 388E 3858 41B3 82B6 74AD B02D ADCD 9565 E1B8")
  }

  func test_fingerprintCheckedPublisher_initially_publishes_false() async throws {
    let controller: ServerFingerprintController = try testController(
      context: (accountID: accountID, fingerprint: validFingerprint)
    )

    var result: Bool?

    controller.fingerprintMarkedAsCheckedPublisher()
      .sink { value in
        result = value
      }
      .store(in: cancellables)

    XCTAssertFalse(result)
  }

  func test_fingerprintCheckedPublisher_publishes_whenToggled() async throws {
    let controller: ServerFingerprintController = try testController(
      context: (accountID: accountID, fingerprint: validFingerprint)
    )

    var result: Bool?

    controller.fingerprintMarkedAsCheckedPublisher()
      .sink { value in
        result = value
      }
      .store(in: cancellables)

    controller.toggleFingerprintMarkedAsChecked()

    XCTAssertTrue(result)
  }

  func test_saveFingerprintPublisher_publishes_whenSaveFingerprintEnabled_andTriggered() async throws {
    let uncheckedSendableFingerprint: UnsafeSendable<Fingerprint> = .init()
    features.patch(
      \AccountsDataStore.storeServerFingerprint,
      with: { _, fingerprint in
        uncheckedSendableFingerprint.value = fingerprint
        return Void()
      }
    )

    let controller: ServerFingerprintController = try testController(
      context: (accountID: accountID, fingerprint: validFingerprint)
    )

    controller.toggleFingerprintMarkedAsChecked()
    let result: Void? =
      try? await controller
      .saveFingerprintPublisher()
      .asAsyncValue()

    XCTAssertNotNil(result)
    XCTAssertEqual(uncheckedSendableFingerprint.value, validFingerprint)
  }

  func test_saveFingerprintPublisher_doesNotPublish_whenSaveFingerprintDisabled_andTriggered() async throws {
    XCTExpectFailure("TODO: Implement assertionFailure mocking via Environment")

    return XCTFail()

    features.patch(
      \AccountsDataStore.storeServerFingerprint,
      with: always(Void())
    )

    let controller: ServerFingerprintController = try testController(
      context: (accountID: accountID, fingerprint: validFingerprint)
    )

    var result: Void?

    controller.saveFingerprintPublisher()
      .sink(
        receiveCompletion: { _ in },
        receiveValue: { result = Void() }
      )
      .store(in: cancellables)

    XCTAssertNil(result)
  }

  func test_saveFingerprintPublisher_publishesError_whenSaveFingerprintFails() async throws {
    features.patch(
      \AccountsDataStore.storeServerFingerprint,
      with: alwaysThrow(MockIssue.error())
    )

    let controller: ServerFingerprintController = try testController(
      context: (accountID: accountID, fingerprint: validFingerprint)
    )

    controller.toggleFingerprintMarkedAsChecked()

    var result: Error?
    do {
      try await controller.saveFingerprintPublisher()
        .asAsyncValue()
      XCTFail()
    }
    catch {
      result = error
    }

    XCTAssertNotNil(result)
  }
}

private let accountID: Account.LocalID = .init(rawValue: "ACCOUNT_ID")
private let validFingerprint: Fingerprint = .init(rawValue: "E8FE388E385841B382B674ADB02DADCD9565E1B8")
private let otherFingerprint: Fingerprint = .init(rawValue: "2A4842CF153F003F565C22C01AEB35EEC222D2BC")
