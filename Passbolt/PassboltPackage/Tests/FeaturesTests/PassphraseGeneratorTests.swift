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

import func Darwin.log

@testable import Crypto
@testable import Features

// swift-format-ignore: AlwaysUseLowerCamelCase, NeverUseImplicitlyUnwrappedOptionals
final class PassphraseGeneratorTests: LoadableFeatureTestCase<PassphraseGenerator>, @unchecked Sendable {

  override class func testedImplementationRegister(
    _ registry: inout FeaturesRegistry
  ) {
    registry.usePassphraseGenerator()
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

  func test_generate_withThreeWords_producesThreeWordsSeparatedBySpace() async throws {
    let settings: PassphraseGeneratorSettings = .init(
      words: 3,
      wordSeparator: " ",
      wordCase: .lowercase
    )
    let generator: PassphraseGenerator = try testedInstance()
    let result: String = try generator.generate(settings)

    let components: Array<String> = result.components(separatedBy: " ")
    XCTAssertEqual(components.count, 3)
    XCTAssertTrue(components.allSatisfy { !$0.isEmpty })
  }

  func test_generate_withLowercaseCase_producesLowercaseWords() async throws {
    let settings: PassphraseGeneratorSettings = .init(
      words: 3,
      wordSeparator: " ",
      wordCase: .lowercase
    )
    let generator: PassphraseGenerator = try testedInstance()
    let result: String = try generator.generate(settings)

    let components: Array<String> = result.components(separatedBy: " ")
    XCTAssertTrue(components.allSatisfy { $0 == $0.lowercased() })
  }

  func test_generate_withUppercaseCase_producesUppercaseWords() async throws {
    let settings: PassphraseGeneratorSettings = .init(
      words: 3,
      wordSeparator: " ",
      wordCase: .uppercase
    )
    let generator: PassphraseGenerator = try testedInstance()
    let result: String = try generator.generate(settings)

    let components: Array<String> = result.components(separatedBy: " ")
    XCTAssertTrue(components.allSatisfy { $0 == $0.uppercased() })
  }

  func test_generate_withCamelcaseCase_producesCapitalizedWords() async throws {
    let settings: PassphraseGeneratorSettings = .init(
      words: 3,
      wordSeparator: " ",
      wordCase: .camelcase
    )
    let generator: PassphraseGenerator = try testedInstance()
    let result: String = try generator.generate(settings)

    let components: Array<String> = result.components(separatedBy: " ")
    XCTAssertTrue(components.allSatisfy { $0 == $0.capitalized })
  }

  func test_generate_withCustomSeparator_usesSeparator() async throws {
    let settings: PassphraseGeneratorSettings = .init(
      words: 3,
      wordSeparator: "-",
      wordCase: .lowercase
    )
    let generator: PassphraseGenerator = try testedInstance()
    let result: String = try generator.generate(settings)

    let components: Array<String> = result.components(separatedBy: "-")
    XCTAssertEqual(components.count, 3)
  }

  func test_generate_withZeroWords_throwsError() async throws {
    let settings: PassphraseGeneratorSettings = .init(
      words: 0,
      wordSeparator: " ",
      wordCase: .lowercase
    )
    let generator: PassphraseGenerator = try testedInstance()

    XCTAssertThrowsError(try generator.generate(settings))
  }

  // MARK: - Entropy tests

  func test_entropy_forThreeWords_calculatesCorrectly() async throws {
    let settings: PassphraseGeneratorSettings = .init(
      words: 3,
      wordSeparator: " ",
      wordCase: .lowercase
    )
    let generator: PassphraseGenerator = try testedInstance()
    let passphrase: String = try generator.generate(settings)
    let result: Entropy = generator.entropy(passphrase, settings)

    // E = 3 * log(7776 * 3) / log(2)
    let wordlistCount: Int = 7776
    let caseCount: Int = PasswordGeneratorCase.allCases.count
    let expectedEntropy: Double = 3.0 * (log(Double(wordlistCount * caseCount)) / log(2))
    XCTAssertEqual(result.rawValue, expectedEntropy, accuracy: 0.1)
  }

  func test_entropy_forSingleWord_calculatesCorrectly() async throws {
    let settings: PassphraseGeneratorSettings = .init(
      words: 1,
      wordSeparator: " ",
      wordCase: .lowercase
    )
    let generator: PassphraseGenerator = try testedInstance()
    let passphrase: String = try generator.generate(settings)
    let result: Entropy = generator.entropy(passphrase, settings)

    // E = 1 * log(7776 * 3) / log(2)
    let wordlistCount: Int = 7776
    let caseCount: Int = PasswordGeneratorCase.allCases.count
    let expectedEntropy: Double = 1.0 * (log(Double(wordlistCount * caseCount)) / log(2))
    XCTAssertEqual(result.rawValue, expectedEntropy, accuracy: 0.1)
  }

  func test_entropy_withEmptySeparator_countsAsOneWord() async throws {
    let settings: PassphraseGeneratorSettings = .init(
      words: 3,
      wordSeparator: "",
      wordCase: .lowercase
    )
    let generator: PassphraseGenerator = try testedInstance()
    let passphrase: String = try generator.generate(settings)
    let result: Entropy = generator.entropy(passphrase, settings)

    // With empty separator, components(separatedBy: "") returns the whole string as 1 element
    let wordlistCount: Int = 7776
    let caseCount: Int = PasswordGeneratorCase.allCases.count
    let expectedEntropy: Double = 1.0 * (log(Double(wordlistCount * caseCount)) / log(2))
    XCTAssertEqual(result.rawValue, expectedEntropy, accuracy: 0.1)
  }
}
