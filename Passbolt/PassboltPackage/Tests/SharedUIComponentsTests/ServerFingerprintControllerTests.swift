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
final class ServerFingerprintControllerTests: TestCase {

  var fingerprintStorage: FingerprintStorage!

  override func setUp() {
    super.setUp()
    fingerprintStorage = .placeholder
  }

  override func tearDown() {
    fingerprintStorage = nil
    super.tearDown()
  }

  func test_fingerprint_isCorrectlyFormatted() {
    features.use(fingerprintStorage)

    let controller: ServerFingerprintController = testInstance(
      context: (accountID: accountID, fingerprint: validFingerprint)
    )

    let result: Fingerprint = controller.formattedFingerprint()

    XCTAssertEqual(result, "E8FE 388E 3858 41B3 82B6 74AD B02D ADCD 9565 E1B8")
  }

  func test_fingerprintCheckedPublisher_initially_publishes_false() {
    features.use(fingerprintStorage)

    let controller: ServerFingerprintController = testInstance(
      context: (accountID: accountID, fingerprint: validFingerprint)
    )

    var result: Bool!

    controller.fingerprintMarkedAsCheckedPublisher()
      .sink { value in
        result = value
      }
      .store(in: cancellables)

    XCTAssertFalse(result)
  }

  func test_fingerprintCheckedPublisher_publishes_whenToggled() {
    features.use(fingerprintStorage)

    let controller: ServerFingerprintController = testInstance(
      context: (accountID: accountID, fingerprint: validFingerprint)
    )

    var result: Bool!

    controller.fingerprintMarkedAsCheckedPublisher()
      .sink { value in
        result = value
      }
      .store(in: cancellables)

    controller.toggleFingerprintMarkedAsChecked()

    XCTAssertTrue(result)
  }

  func test_saveFingerprintPublisher_publishes_whenSaveFingerprintEnabled_andTriggered() {
    var storedFingerprint: Fingerprint?
    fingerprintStorage.storeServerFingerprint = { _, fingerprint in
      storedFingerprint = fingerprint
      return .success(())
    }
    features.use(fingerprintStorage)

    let controller: ServerFingerprintController = testInstance(
      context: (accountID: accountID, fingerprint: validFingerprint)
    )

    var result: Void!

    controller.toggleFingerprintMarkedAsChecked()

    controller.saveFingerprintPublisher()
      .sink(
        receiveCompletion: { _ in },
        receiveValue: { result = Void() }
      )
      .store(in: cancellables)

    XCTAssertNotNil(result)
    XCTAssertEqual(storedFingerprint, validFingerprint)
  }

  func test_saveFingerprintPublisher_doesNotPublish_whenSaveFingerprintDisabled_andTriggered() {
    XCTExpectFailure("TODO: Implement assertionFailure mocking via Environment")

    return XCTFail()

    fingerprintStorage.storeServerFingerprint = always(.success(()))
    features.use(fingerprintStorage)

    let controller: ServerFingerprintController = testInstance(
      context: (accountID: accountID, fingerprint: validFingerprint)
    )

    var result: Void!

    controller.saveFingerprintPublisher()
      .sink(
        receiveCompletion: { _ in },
        receiveValue: { result = Void() }
      )
      .store(in: cancellables)

    XCTAssertNil(result)
  }

  func test_saveFingerprintPublisher_publishesError_whenSaveFingerprintFails() {
    fingerprintStorage.storeServerFingerprint = always(.failure(.testError()))
    features.use(fingerprintStorage)

    let controller: ServerFingerprintController = testInstance(
      context: (accountID: accountID, fingerprint: validFingerprint)
    )

    var result: TheErrorLegacy!

    controller.toggleFingerprintMarkedAsChecked()

    controller.saveFingerprintPublisher()
      .sink(
        receiveCompletion: { completion in
          guard case let .failure(error) = completion
          else { return }
          result = error
        },
        receiveValue: { _ in }
      )
      .store(in: cancellables)

    XCTAssertNotNil(result)
  }
}

private let accountID: Account.LocalID = .init(rawValue: "ACCOUNT_ID")
private let validFingerprint: Fingerprint = .init(rawValue: "E8FE388E385841B382B674ADB02DADCD9565E1B8")
private let otherFingerprint: Fingerprint = .init(rawValue: "2A4842CF153F003F565C22C01AEB35EEC222D2BC")
