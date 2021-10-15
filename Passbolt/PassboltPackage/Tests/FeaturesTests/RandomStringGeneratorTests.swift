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

@testable import Environment
@testable import Features

// swift-format-ignore: AlwaysUseLowerCamelCase, NeverUseImplicitlyUnwrappedOptionals
final class RandomStringGeneratorTests: TestCase {

  func test_generate_shortString_succeeds() {
    environment.randomness = .system()

    let alphabet: Set<Character> = .init("ABC")
    let generator: RandomStringGenerator = testInstance()
    let result: String = generator.generate(
      alphabet,
      .init(rawValue: 4.75)
    )

    XCTAssertEqual(result.count, 3)
    XCTAssertTrue(result.filter { !alphabet.contains($0) }.isEmpty)
  }

  func test_generate_alphanumericString_succeeds() {
    environment.randomness = .system()

    let alphabet: Set<Character> = CharacterSets.alphanumeric
    let generator: RandomStringGenerator = testInstance()
    let result: String = generator.generate(
      alphabet,
      .init(rawValue: 107)
    )

    XCTAssertEqual(result.count, 18)
    XCTAssertTrue(result.filter { !alphabet.contains($0) }.isEmpty)
  }

  func test_generate_stringWithAllAvailableCharacters_succeeds() {
    environment.randomness = .system()

    let alphabet: Set<Character> = CharacterSets.all
    let generator: RandomStringGenerator = testInstance()
    let result: String = generator.generate(
      alphabet,
      .init(rawValue: 490)
    )

    XCTAssertEqual(result.count, 75)
    XCTAssertTrue(result.filter { !alphabet.contains($0) }.isEmpty)
  }

  func test_entropy_forEmptyString() {
    environment.randomness = .system()

    let alphabet: Set<Character> = .init("ABC")
    let generator: RandomStringGenerator = testInstance()
    let result: Entropy = generator.entropy(
      "",
      alphabet.count
    )

    XCTAssertEqual(result, .zero)
  }

  func test_entropy_forEmptyAlphabet() {
    environment.randomness = .system()

    let alphabet: Set<Character> = .init("")
    let generator: RandomStringGenerator = testInstance()
    let result: Entropy = generator.entropy(
      "ABC",
      alphabet.count
    )

    XCTAssertEqual(result, .zero)
  }

  func test_entropy_forShortString() {
    environment.randomness = .system()

    let alphabet: Set<Character> = .init("ABC")
    let generator: RandomStringGenerator = testInstance()
    let result: Entropy = generator.entropy(
      "ABC",
      alphabet.count
    )

    // E = 3 * log(3) / log(2)
    XCTAssertEqual(result.rawValue, 4.75, accuracy: 0.1)
  }

  func test_entropy_forLongerAlphanumericString() {
    environment.randomness = .system()

    let alphabet: Set<Character> = CharacterSets.alphanumeric
    let generator: RandomStringGenerator = testInstance()
    let result: Entropy = generator.entropy(
      "oIabpwLaCaTYE3yOZheQ",
      alphabet.count
    )

    // E = 20 * log(62) / log(2)
    XCTAssertEqual(result.rawValue, 119, accuracy: 0.1)
  }

  func test_entropy_forLongString_withAllAvailableCharacters() {
    environment.randomness = .system()

    let alphabet: Set<Character> = CharacterSets.all
    let generator: RandomStringGenerator = testInstance()
    let result: Entropy = generator.entropy(
      ###"@L./Jfc^J&7{1cIs_W172Bir5qm"b:Lkd%3oY.\!]X#j(gi;B<Y"'SWOPX')_KGMZO.[/3:P!ibyJa?x\$gN#$dT~QOXF?.y9^AH?[teQDbkGsBTs[-ZQ8au/~@+ag$uFJ9D72uew?i!q!*J01[w:``_g"###,
      alphabet.count
    )

    // E = 20 * log(93) / log(2)
    XCTAssertEqual(result.rawValue, 1000, accuracy: 1)
  }

  func test_generate_shortString_requestsRandomNumber_forEachCharacter() {
    var randomness: Randomness = .system()
    var calls: Int = 0

    let next: () -> UInt64 = randomness.nextRandom

    randomness.nextRandom = {
      calls += 1
      return next()
    }

    environment.randomness = randomness

    let alphabet: Set<Character> = .init("ABC")
    let generator: RandomStringGenerator = testInstance()
    let result: String = generator.generate(
      alphabet,
      .init(rawValue: 4.75)
    )

    XCTAssertEqual(result.count, 3)
    XCTAssertEqual(calls, 3)
  }
}
