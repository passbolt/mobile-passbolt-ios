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

import DatabaseOperations
import TestExtensions

@testable import Crypto
@testable import Features
@testable import Shared
@testable import SharedUIComponents

// swift-format-ignore: AlwaysUseLowerCamelCase, NeverUseImplicitlyUnwrappedOptionals
final class PasswordServiceTests: LoadableFeatureTestCase<PasswordService> {

  override class var testedImplementationScope: any FeaturesScope.Type {
    SessionScope.self
  }

  override class func testedImplementationRegister(
    _ registry: inout FeaturesRegistry
  ) {
    registry.usePasswordService()
  }

  override func prepare() throws {
    set(
      SessionScope.self,
      context: .init(
        account: .mock_ada,
        configuration: .mock_1
      )
    )

    self.patch(
      \SecretGenerator.generate,
      with: { _ in "generated-secret" }
    )
    self.patch(
      \SecretGenerator.entropy,
      with: { _, _ in .init(rawValue: 100) }
    )
    self.patch(
      \PasswordPoliciesFetchDatabaseOperation.execute,
      with: { _ in
        .init(
          id: .init(),
          defaultGenerator: .password,
          passwordGeneratorSettings: .init(
            length: 20,
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
            words: 5,
            wordSeparator: " ",
            wordCase: .lowercase
          ),
          externalDictionaryCheck: false
        )
      }
    )
    self.patch(
      \PwnedPasswordChecker.check,
      with: { _ in true }
    )
  }

  // MARK: - Generation tests

  func test_generate_fetchesPoliciesAndGenerates() async throws {
    let receivedConfiguration: CriticalState<SecretGenerator.Configuration?> = .init(nil)
    self.patch(
      \SecretGenerator.generate,
      with: { configuration in
        receivedConfiguration.set(configuration)
        return "generated-from-policies"
      }
    )

    let generator: PasswordService = try testedInstance()
    let result: String = try await generator.generate()

    XCTAssertEqual(result, "generated-from-policies")
    XCTAssertNotNil(receivedConfiguration.get())
    XCTAssertEqual(receivedConfiguration.get()?.passwordGeneratorSettings.length, 20)
  }

  func test_generate_whenFetchFails_usesDefaultConfiguration() async throws {
    self.patch(
      \PasswordPoliciesFetchDatabaseOperation.execute,
      with: { _ in
        throw MockError()
      }
    )

    let receivedConfiguration: CriticalState<SecretGenerator.Configuration?> = .init(nil)
    self.patch(
      \SecretGenerator.generate,
      with: { configuration in
        receivedConfiguration.set(configuration)
        return "generated-from-default"
      }
    )

    let generator: PasswordService = try testedInstance()
    let result: String = try await generator.generate()

    XCTAssertEqual(result, "generated-from-default")
    XCTAssertNotNil(receivedConfiguration.get())
    XCTAssertEqual(
      receivedConfiguration.get()?.defaultGenerator,
      SecretGenerator.Configuration.default.defaultGenerator
    )
    XCTAssertEqual(
      receivedConfiguration.get()?.passwordGeneratorSettings.length,
      SecretGenerator.Configuration.default.passwordGeneratorSettings.length
    )
  }

  func test_entropy_fetchesPoliciesAndCalculates() async throws {
    let expectedEntropy: Entropy = .init(rawValue: 150)
    self.patch(
      \SecretGenerator.entropy,
      with: { _, _ in expectedEntropy }
    )

    let generator: PasswordService = try testedInstance()
    let result: Entropy = await generator.entropy("test-secret")

    XCTAssertEqual(result, expectedEntropy)
  }

  func test_entropy_whenFetchFails_usesDefaultConfiguration() async throws {
    self.patch(
      \PasswordPoliciesFetchDatabaseOperation.execute,
      with: { _ in
        throw MockError()
      }
    )

    let receivedConfiguration: CriticalState<SecretGenerator.Configuration?> = .init(nil)
    self.patch(
      \SecretGenerator.entropy,
      with: { _, configuration in
        receivedConfiguration.set(configuration)
        return .init(rawValue: 80)
      }
    )

    let generator: PasswordService = try testedInstance()
    let result: Entropy = await generator.entropy("test-secret")

    XCTAssertEqual(result.rawValue, 80)
    XCTAssertNotNil(receivedConfiguration.get())
    XCTAssertEqual(
      receivedConfiguration.get()?.passwordGeneratorSettings.length,
      SecretGenerator.Configuration.default.passwordGeneratorSettings.length
    )
  }

  // MARK: - Validation tests

  func test_validate_returnsValid_whenEntropyHighAndNotPwned() async throws {
    self.patch(
      \PasswordPoliciesFetchDatabaseOperation.execute,
      with: { _ in
        .init(
          id: .init(),
          defaultGenerator: .password,
          passwordGeneratorSettings: .init(
            length: 20,
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
            words: 5,
            wordSeparator: " ",
            wordCase: .lowercase
          ),
          externalDictionaryCheck: true
        )
      }
    )
    self.patch(
      \SecretGenerator.entropy,
      with: { _, _ in .init(rawValue: 100) }
    )
    self.patch(
      \PwnedPasswordChecker.check,
      with: { _ in true }
    )

    let service: PasswordService = try testedInstance()
    let result: PasswordService.SecretValidationResult = try await service.validate("strong-password")

    XCTAssertEqual(result, .valid)
  }

  func test_validate_returnsWeak_whenEntropyBelowMinimum() async throws {
    self.patch(
      \SecretGenerator.entropy,
      with: { _, _ in .init(rawValue: 30) }
    )

    let service: PasswordService = try testedInstance()
    let result: PasswordService.SecretValidationResult = try await service.validate("weak")

    XCTAssertEqual(result, .weak)
  }

  func test_validate_returnsPwned_whenCheckerReturnsFalse() async throws {
    self.patch(
      \PasswordPoliciesFetchDatabaseOperation.execute,
      with: { _ in
        .init(
          id: .init(),
          defaultGenerator: .password,
          passwordGeneratorSettings: .init(
            length: 20,
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
            words: 5,
            wordSeparator: " ",
            wordCase: .lowercase
          ),
          externalDictionaryCheck: true
        )
      }
    )
    self.patch(
      \SecretGenerator.entropy,
      with: { _, _ in .init(rawValue: 100) }
    )
    self.patch(
      \PwnedPasswordChecker.check,
      with: { _ in false }
    )

    let service: PasswordService = try testedInstance()
    let result: PasswordService.SecretValidationResult = try await service.validate("pwned-password")

    XCTAssertEqual(result, .pwned)
  }

  func test_validate_returnsValid_whenExternalCheckDisabled() async throws {
    self.patch(
      \SecretGenerator.entropy,
      with: { _, _ in .init(rawValue: 100) }
    )

    let checkerCalled: CriticalState<Bool> = .init(false)
    self.patch(
      \PwnedPasswordChecker.check,
      with: { _ in
        checkerCalled.set(true)
        return true
      }
    )

    let service: PasswordService = try testedInstance()
    let result: PasswordService.SecretValidationResult = try await service.validate("strong-password")

    XCTAssertEqual(result, .valid)
    XCTAssertFalse(checkerCalled.get())
  }

  func test_validate_throwsExternalCheckFailure_whenCheckerThrows() async throws {
    self.patch(
      \PasswordPoliciesFetchDatabaseOperation.execute,
      with: { _ in
        .init(
          id: .init(),
          defaultGenerator: .password,
          passwordGeneratorSettings: .init(
            length: 20,
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
            words: 5,
            wordSeparator: " ",
            wordCase: .lowercase
          ),
          externalDictionaryCheck: true
        )
      }
    )
    self.patch(
      \SecretGenerator.entropy,
      with: { _, _ in .init(rawValue: 100) }
    )
    self.patch(
      \PwnedPasswordChecker.check,
      with: { _ in
        throw MockError()
      }
    )

    let service: PasswordService = try testedInstance()

    do {
      _ = try await service.validate("some-password")
      XCTFail("Expected error to be thrown")
    }
    catch is PasswordService.PasswordExternalCheckFailure {
      // expected
    }
    catch {
      XCTFail("Unexpected error type: \(error)")
    }
  }
}

private struct MockError: Error {}
