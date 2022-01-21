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

import XCTest

@testable import Commons

// swift-format-ignore: AlwaysUseLowerCamelCase, NeverUseImplicitlyUnwrappedOptionals
final class ValidatorTests: XCTestCase {

  private let messageKeyInvalid: LocalizedString.Key = "key.invalid"

  func test_nonEmptyValidator_withNonEmptyValue_Succeeds() {
    let validator: Validator<String> = .nonEmpty(
      displayable: .localized(
        key: messageKeyInvalid
      )
    )
    let validated: Validated<String> = validator.validate("NonEmptyString")

    XCTAssertTrue(validated.isValid)
    XCTAssertTrue(validated.errors.isEmpty)
  }

  func test_nonEmptyValidator_withEmptyValue_Fails() {
    let validator: Validator<String> = .nonEmpty(
      displayable: .localized(
        key: messageKeyInvalid
      )
    )
    let validated: Validated<String> = validator.validate("")

    XCTAssertFalse(validated.isValid)
    XCTAssertEqual(validated.errors.first?.validationRule, "nonEmpty")
  }
}
