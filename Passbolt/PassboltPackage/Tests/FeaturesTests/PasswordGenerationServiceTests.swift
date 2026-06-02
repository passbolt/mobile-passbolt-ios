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
final class PasswordGenerationServiceTests: LoadableFeatureTestCase<PasswordGenerationService>, @unchecked Sendable {

  override class var testedImplementationScope: any FeaturesScope.Type {
    ResourceEditScope.self
  }

  override class func testedImplementationRegister(
    _ registry: inout FeaturesRegistry
  ) {
    registry.usePasswordGenerationService()
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
      \PasswordPoliciesLoader.policies,
      with: { await Self.policy(length: 24) }
    )
  }

  // MARK: - currentConfiguration

  func test_currentConfiguration_returnsLoaderPolicy() async throws {
    let service: PasswordGenerationService = try testedInstance()
    let configuration: PasswordPoliciesDSV = await service.currentConfiguration()
    XCTAssertEqual(configuration.passwordGeneratorSettings.length, 24)
  }

  // MARK: - updateConfiguration

  func test_updateConfiguration_isReflectedInNextCurrentConfiguration() async throws {
    let service: PasswordGenerationService = try testedInstance()
    _ = await service.currentConfiguration()

    let updated: PasswordPoliciesDSV = Self.policy(length: 64)
    await service.updateConfiguration(updated)

    let configuration: PasswordPoliciesDSV = await service.currentConfiguration()
    XCTAssertEqual(configuration.passwordGeneratorSettings.length, 64)
  }

  func test_updateConfiguration_bypassesLoader() async throws {
    let loaderCalls: CriticalState<Int> = .init(0)
    self.patch(
      \PasswordPoliciesLoader.policies,
      with: {
        loaderCalls.access { $0 += 1 }
        return await Self.policy(length: 24)
      }
    )

    let service: PasswordGenerationService = try testedInstance()
    await service.updateConfiguration(Self.policy(length: 64))

    _ = await service.currentConfiguration()
    _ = await service.currentConfiguration()

    XCTAssertEqual(loaderCalls.get(), 0)
  }

  // MARK: - generate

  func test_generate_usesCurrentConfiguration() async throws {
    let receivedConfiguration: CriticalState<PasswordPoliciesDSV?> = .init(.none)
    self.patch(
      \SecretGenerator.generate,
      with: { (configuration: PasswordPoliciesDSV) in
        receivedConfiguration.set(configuration)
        return "generated"
      }
    )

    let service: PasswordGenerationService = try testedInstance()
    let result: String = try await service.generate()

    XCTAssertEqual(result, "generated")
    XCTAssertEqual(receivedConfiguration.get()?.passwordGeneratorSettings.length, 24)
  }

  // MARK: - Helpers

  fileprivate static func policy(length: Int) -> PasswordPoliciesDSV {
    PasswordPoliciesDSV(
      id: .init(),
      defaultGenerator: .password,
      passwordGeneratorSettings: PasswordGeneratorSettings(
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
      passphraseGeneratorSettings: PassphraseGeneratorSettings(
        words: 5,
        wordSeparator: " ",
        wordCase: .lowercase
      ),
      externalDictionaryCheck: false
    )
  }
}
