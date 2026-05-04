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

@testable import Crypto
@testable import Features

// swift-format-ignore: AlwaysUseLowerCamelCase, NeverUseImplicitlyUnwrappedOptionals
final class PasswordGeneratorTests: LoadableFeatureTestCase<PasswordGenerator>, @unchecked Sendable {

  override class func testedImplementationRegister(
    _ registry: inout FeaturesRegistry
  ) {
    registry.usePasswordGenerator()
  }

  override func prepare() throws {
    self.patch(
      \OSRandomness.nextValue,
      with: { () -> UInt64 in
        var rng: SystemRandomNumberGenerator = .init()
        return rng.next()
      }
    )
  }

  // MARK: - Generation tests

  func test_generate_withUpperAndLowerMasks_producesValidString() async throws {
    let settings: PasswordGeneratorSettings = .testSettings(
      maskUpper: true,
      maskLower: true
    )
    let generator: PasswordGenerator = try testedInstance()
    let result: String = try generator.generate(settings)

    XCTAssertTrue(result.count >= settings.length)
    let allowedCharacters: Set<Character> =
      CharacterSets.uppercaseLetters.characters
      .union(CharacterSets.lowercaseLetters.characters)
    XCTAssertTrue(result.allSatisfy { allowedCharacters.contains($0) })
  }

  func test_generate_withAllMasks_producesValidString() async throws {
    let settings: PasswordGeneratorSettings = .testSettings(
      maskUpper: true,
      maskLower: true,
      maskDigit: true,
      maskParenthesis: true,
      maskEmoji: true,
      maskChar1: true,
      maskChar2: true,
      maskChar3: true,
      maskChar4: true,
      maskChar5: true
    )
    let generator: PasswordGenerator = try testedInstance()
    let result: String = try generator.generate(settings)

    XCTAssertTrue(result.count >= settings.length)
  }

  func test_generate_withOnlyDigits_producesDigitOnlyString() async throws {
    let settings: PasswordGeneratorSettings = .testSettings(
      maskDigit: true
    )
    let generator: PasswordGenerator = try testedInstance()
    let result: String = try generator.generate(settings)

    let digitCharacters: Set<Character> = CharacterSets.digits.characters
    XCTAssertTrue(result.allSatisfy { digitCharacters.contains($0) })
  }

  func test_generate_withExcludeLookAlikeChars_excludesAlikeCharacters() async throws {
    let settings: PasswordGeneratorSettings = .testSettings(
      maskUpper: true,
      maskLower: true,
      maskDigit: true,
      excludeLookAlikeChars: true
    )
    let generator: PasswordGenerator = try testedInstance()
    let result: String = try generator.generate(settings)

    let alikeCharacters: Set<Character> = CharacterSets.alikeCharacters.characters
    XCTAssertTrue(result.allSatisfy { !alikeCharacters.contains($0) })
  }

  func test_generate_withMinimumLength_meetsLength() async throws {
    let settings: PasswordGeneratorSettings = .testSettings(
      length: 50,
      maskUpper: true,
      maskLower: true,
      maskDigit: true
    )
    let generator: PasswordGenerator = try testedInstance()
    let result: String = try generator.generate(settings)

    XCTAssertTrue(result.count >= 50)
  }

  // MARK: - Entropy tests

  func test_entropy_forEmptyString_returnsZero() async throws {
    let settings: PasswordGeneratorSettings = .testSettings(
      maskUpper: true,
      maskLower: true
    )
    let generator: PasswordGenerator = try testedInstance()
    let result: Entropy = generator.entropy("", settings)

    XCTAssertEqual(result, .zero)
  }

  func test_entropy_forEmptySettings_returnsZero() async throws {
    let settings: PasswordGeneratorSettings = .testSettings()
    let generator: PasswordGenerator = try testedInstance()
    let result: Entropy = generator.entropy("ABC", settings)

    XCTAssertEqual(result, .zero)
  }

  func test_entropy_forKnownAlphanumericString_calculatesCorrectly() async throws {
    let settings: PasswordGeneratorSettings = .testSettings(
      maskUpper: true,
      maskLower: true,
      maskDigit: true
    )
    let generator: PasswordGenerator = try testedInstance()
    // 20 chars from alphanumeric alphabet (62 chars total)
    // E = 20 * log(62) / log(2)
    let result: Entropy = generator.entropy("oIabpwLaCaTYE3yOZheQ", settings)

    XCTAssertEqual(result.rawValue, 119, accuracy: 0.5)
  }

  func test_entropy_forAllCharacterSets_calculatesCorrectly() async throws {
    let settings: PasswordGeneratorSettings = .testSettings(
      maskUpper: true,
      maskLower: true,
      maskDigit: true,
      maskParenthesis: true,
      maskChar1: true,
      maskChar2: true,
      maskChar3: true,
      maskChar4: true,
      maskChar5: true
    )
    let generator: PasswordGenerator = try testedInstance()
    // Use chars from all 9 enabled sets to trigger full alphabet union:
    // uppercase(26) + lowercase(26) + digits(10) + parenthesis(7) +
    // specialChar1(7) + specialChar2(4) + specialChar3(3) + specialChar4(4) + specialChar5(6) = 93
    // E = 9 * log(93) / log(2)
    let result: Entropy = generator.entropy("Aa1{#.'/?", settings)

    XCTAssertEqual(result.rawValue, 58.8, accuracy: 0.5)
  }
}

// MARK: - Test Helpers

extension PasswordGeneratorSettings {

  fileprivate static func testSettings(
    length: Int = 18,
    maskUpper: Bool = false,
    maskLower: Bool = false,
    maskDigit: Bool = false,
    maskParenthesis: Bool = false,
    maskEmoji: Bool = false,
    maskChar1: Bool = false,
    maskChar2: Bool = false,
    maskChar3: Bool = false,
    maskChar4: Bool = false,
    maskChar5: Bool = false,
    excludeLookAlikeChars: Bool = false
  ) -> PasswordGeneratorSettings {
    .init(
      length: length,
      maskUpper: maskUpper,
      maskLower: maskLower,
      maskDigit: maskDigit,
      maskParenthesis: maskParenthesis,
      maskEmoji: maskEmoji,
      maskChar1: maskChar1,
      maskChar2: maskChar2,
      maskChar3: maskChar3,
      maskChar4: maskChar4,
      maskChar5: maskChar5,
      excludeLookAlikeChars: excludeLookAlikeChars
    )
  }
}
