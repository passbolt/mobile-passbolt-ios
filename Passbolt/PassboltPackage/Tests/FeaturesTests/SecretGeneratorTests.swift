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
final class SecretGeneratorTests: LoadableFeatureTestCase<SecretGenerator>, @unchecked Sendable {

  override class func testedImplementationRegister(
    _ registry: inout FeaturesRegistry
  ) {
    registry.useSecretGenerator()
  }

  override func prepare() throws {
    self.patch(
      \PasswordGenerator.generate,
      with: { _ in "generated-password" }
    )
    self.patch(
      \PasswordGenerator.entropy,
      with: { _, _ in .init(rawValue: 100) }
    )
    self.patch(
      \PassphraseGenerator.generate,
      with: { _ in "generated passphrase words" }
    )
    self.patch(
      \PassphraseGenerator.entropy,
      with: { _, _ in .init(rawValue: 50) }
    )
  }

  // MARK: - Generation tests

  func test_generate_withPasswordType_callsPasswordGenerator() async throws {
    let passwordGeneratorCalled: CriticalState<Bool> = .init(false)
    self.patch(
      \PasswordGenerator.generate,
      with: { _ in
        passwordGeneratorCalled.set(true)
        return "password-result"
      }
    )

    let generator: SecretGenerator = try testedInstance()
    let configuration: SecretGenerator.Configuration = .passwordConfiguration()
    let result: String = try generator.generate(configuration)

    XCTAssertTrue(passwordGeneratorCalled.get())
    XCTAssertEqual(result, "password-result")
  }

  func test_generate_withPassphraseType_callsPassphraseGenerator() async throws {
    let passphraseGeneratorCalled: CriticalState<Bool> = .init(false)
    self.patch(
      \PassphraseGenerator.generate,
      with: { _ in
        passphraseGeneratorCalled.set(true)
        return "passphrase-result"
      }
    )

    let generator: SecretGenerator = try testedInstance()
    let configuration: SecretGenerator.Configuration = .passphraseConfiguration()
    let result: String = try generator.generate(configuration)

    XCTAssertTrue(passphraseGeneratorCalled.get())
    XCTAssertEqual(result, "passphrase-result")
  }

  func test_entropy_withPasswordType_usesPasswordGeneratorEntropy() async throws {
    let expectedEntropy: Entropy = .init(rawValue: 120)
    self.patch(
      \PasswordGenerator.entropy,
      with: { _, _ in expectedEntropy }
    )

    let generator: SecretGenerator = try testedInstance()
    let configuration: SecretGenerator.Configuration = .passwordConfiguration()
    let result: Entropy = generator.entropy("test", configuration)

    XCTAssertEqual(result, expectedEntropy)
  }

  func test_entropy_withPassphraseType_usesPassphraseGeneratorEntropy() async throws {
    let expectedEntropy: Entropy = .init(rawValue: 60)
    self.patch(
      \PassphraseGenerator.entropy,
      with: { _, _ in expectedEntropy }
    )

    let generator: SecretGenerator = try testedInstance()
    let configuration: SecretGenerator.Configuration = .passphraseConfiguration()
    let result: Entropy = generator.entropy("test", configuration)

    XCTAssertEqual(result, expectedEntropy)
  }

  func test_defaultConfiguration_hasExpectedValues() async throws {
    let defaultConfig: SecretGenerator.Configuration = .default

    XCTAssertEqual(defaultConfig.defaultGenerator, .password)
    XCTAssertEqual(defaultConfig.passwordGeneratorSettings.length, 18)
    XCTAssertTrue(defaultConfig.passwordGeneratorSettings.maskUpper)
    XCTAssertTrue(defaultConfig.passwordGeneratorSettings.maskLower)
    XCTAssertTrue(defaultConfig.passwordGeneratorSettings.maskDigit)
    XCTAssertFalse(defaultConfig.passwordGeneratorSettings.maskParenthesis)
    XCTAssertFalse(defaultConfig.passwordGeneratorSettings.maskEmoji)
    XCTAssertEqual(defaultConfig.passphraseGeneratorSettings.words, 3)
    XCTAssertEqual(defaultConfig.passphraseGeneratorSettings.wordSeparator, " ")
    XCTAssertEqual(defaultConfig.passphraseGeneratorSettings.wordCase, .lowercase)
    XCTAssertFalse(defaultConfig.externalDictionaryCheck)
  }
}

// MARK: - Test Helpers

extension SecretGenerator.Configuration {

  fileprivate static func passwordConfiguration() -> Self {
    .init(
      id: .init(),
      defaultGenerator: .password,
      passwordGeneratorSettings: .init(
        length: 18,
        maskUpper: true,
        maskLower: true,
        maskDigit: true,
        maskParenthesis: false,
        maskEmoji: false,
        maskChar1: true,
        maskChar2: false,
        maskChar3: false,
        maskChar4: false,
        maskChar5: false,
        excludeLookAlikeChars: false
      ),
      passphraseGeneratorSettings: .init(
        words: 3,
        wordSeparator: " ",
        wordCase: .lowercase
      ),
      externalDictionaryCheck: false
    )
  }

  fileprivate static func passphraseConfiguration() -> Self {
    .init(
      id: .init(),
      defaultGenerator: .passphrase,
      passwordGeneratorSettings: .init(
        length: 18,
        maskUpper: true,
        maskLower: true,
        maskDigit: true,
        maskParenthesis: false,
        maskEmoji: false,
        maskChar1: false,
        maskChar2: false,
        maskChar3: false,
        maskChar4: false,
        maskChar5: false,
        excludeLookAlikeChars: false
      ),
      passphraseGeneratorSettings: .init(
        words: 5,
        wordSeparator: " ",
        wordCase: .lowercase
      ),
      externalDictionaryCheck: false
    )
  }
}
