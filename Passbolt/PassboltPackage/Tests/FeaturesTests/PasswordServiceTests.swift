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
@testable import Shared
@testable import SharedUIComponents

// swift-format-ignore: AlwaysUseLowerCamelCase, NeverUseImplicitlyUnwrappedOptionals
final class PasswordServiceTests: LoadableFeatureTestCase<PasswordService>, @unchecked Sendable {

  override class var testedImplementationScope: any FeaturesScope.Type {
    ResourceEditScope.self
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
    set(
      ResourceEditScope.self,
      context: .init(
        editedResource: .mock_1,
        availableTypes: [Resource.mock_1.type]
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
      \PasswordPoliciesLoader.policies,
      with: { await Self.policy(length: 20) }
    )
    self.patch(
      \PwnedPasswordChecker.check,
      with: { _ in true }
    )
  }

  // MARK: - Configuration tests

  func test_configuration_returnsLoaderPolicy() async throws {
    let service: PasswordService = try testedInstance()
    let configuration: PasswordService.Configuration = try await service.configuration().value
    XCTAssertEqual(configuration.passwordGeneratorSettings.length, 20)
  }

  func test_updateConfiguration_isReflectedInNextConfiguration() async throws {
    let service: PasswordService = try testedInstance()
    _ = try await service.configuration().value

    await service.updateConfiguration(Self.policy(length: 64))

    let configuration: PasswordService.Configuration = try await service.configuration().value
    XCTAssertEqual(configuration.passwordGeneratorSettings.length, 64)
  }

  func test_updateConfiguration_bypassesLoader() async throws {
    let loaderCalls: CriticalState<Int> = .init(0)
    self.patch(
      \PasswordPoliciesLoader.policies,
      with: {
        loaderCalls.access { $0 += 1 }
        return await Self.policy(length: 20)
      }
    )

    let service: PasswordService = try testedInstance()
    await service.updateConfiguration(Self.policy(length: 64))

    _ = try await service.configuration().value
    _ = try await service.configuration().value

    XCTAssertEqual(loaderCalls.get(), 0)
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

  func test_generate_usesOverriddenConfiguration() async throws {
    let receivedConfiguration: CriticalState<SecretGenerator.Configuration?> = .init(nil)
    self.patch(
      \SecretGenerator.generate,
      with: { (configuration: SecretGenerator.Configuration) in
        receivedConfiguration.set(configuration)
        return "generated"
      }
    )

    let service: PasswordService = try testedInstance()
    await service.updateConfiguration(Self.policy(length: 64))
    _ = try await service.generate()

    XCTAssertEqual(receivedConfiguration.get()?.passwordGeneratorSettings.length, 64)
  }

  // MARK: - Entropy tests

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

  /// Entropy has to be scored against the same configuration the secret was generated with,
  /// otherwise the strength indicator contradicts the advanced generation settings.
  func test_entropy_usesOverriddenConfiguration() async throws {
    let receivedConfiguration: CriticalState<SecretGenerator.Configuration?> = .init(nil)
    self.patch(
      \SecretGenerator.entropy,
      with: { (_: String, configuration: SecretGenerator.Configuration) in
        receivedConfiguration.set(configuration)
        return .init(rawValue: 100)
      }
    )

    let service: PasswordService = try testedInstance()
    await service.updateConfiguration(Self.policy(length: 64, defaultGenerator: .passphrase))
    _ = await service.entropy("test-secret")

    XCTAssertEqual(receivedConfiguration.get()?.passwordGeneratorSettings.length, 64)
    XCTAssertEqual(receivedConfiguration.get()?.defaultGenerator, .passphrase)
  }

  // MARK: - Validation tests

  func test_validate_returnsValid_whenEntropyHighAndNotPwned() async throws {
    self.patch(
      \PasswordPoliciesLoader.policies,
      with: { await Self.policy(length: 20, externalDictionaryCheck: true) }
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
      \PasswordPoliciesLoader.policies,
      with: { await Self.policy(length: 20, externalDictionaryCheck: true) }
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
      \PasswordPoliciesLoader.policies,
      with: { await Self.policy(length: 20, externalDictionaryCheck: true) }
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

  /// Validation has to score the secret using the overridden configuration, otherwise submitting a
  /// resource can raise a bogus weak password warning for a secret generated with edited settings.
  func test_validate_usesOverriddenConfiguration() async throws {
    let receivedConfiguration: CriticalState<SecretGenerator.Configuration?> = .init(nil)
    self.patch(
      \SecretGenerator.entropy,
      with: { (_: String, configuration: SecretGenerator.Configuration) in
        receivedConfiguration.set(configuration)
        return .init(rawValue: 100)
      }
    )

    let service: PasswordService = try testedInstance()
    await service.updateConfiguration(Self.policy(length: 64, defaultGenerator: .passphrase))
    _ = try await service.validate("some-password")

    XCTAssertEqual(receivedConfiguration.get()?.passwordGeneratorSettings.length, 64)
    XCTAssertEqual(receivedConfiguration.get()?.defaultGenerator, .passphrase)
  }

  /// The external dictionary check flag is part of the resolved configuration as well.
  func test_validate_usesExternalCheckFlagFromOverriddenConfiguration() async throws {
    self.patch(
      \PasswordPoliciesLoader.policies,
      with: { await Self.policy(length: 20, externalDictionaryCheck: false) }
    )
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
    await service.updateConfiguration(Self.policy(length: 20, externalDictionaryCheck: true))
    _ = try await service.validate("some-password")

    XCTAssertTrue(checkerCalled.get())
  }

  // MARK: - Helpers

  private static func policy(
    length: Int,
    externalDictionaryCheck: Bool = false,
    defaultGenerator: PasswordGeneratorType = .password
  ) -> SecretGenerator.Configuration {
    SecretGenerator.Configuration(
      id: .init(),
      defaultGenerator: defaultGenerator,
      passwordGeneratorSettings: .init(
        length: length,
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
      externalDictionaryCheck: externalDictionaryCheck
    )
  }
}

private struct MockError: Error {}
