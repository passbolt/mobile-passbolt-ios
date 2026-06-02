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

import NetworkOperations
import TestExtensions

@testable import Crypto
@testable import Features
@testable import Shared

// swift-format-ignore: AlwaysUseLowerCamelCase, NeverUseImplicitlyUnwrappedOptionals
final class PasswordPoliciesLoaderTests: LoadableFeatureTestCase<PasswordPoliciesLoader>, @unchecked Sendable {

  override class var testedImplementationScope: any FeaturesScope.Type {
    SessionScope.self
  }

  override class func testedImplementationRegister(
    _ registry: inout FeaturesRegistry
  ) {
    registry.usePasswordPoliciesLoader()
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
      \PasswordPoliciesFetchNetworkOperation.execute,
      with: { _ in await Self.dto(length: 24) }
    )
  }

  func test_policies_returnsServerPolicy() async throws {
    let loader: PasswordPoliciesLoader = try testedInstance()
    let configuration: SecretGenerator.Configuration = await loader.policies()
    XCTAssertEqual(configuration.passwordGeneratorSettings.length, 24)
  }

  func test_policies_cachesAfterFirstFetch() async throws {
    let fetchCount: CriticalState<Int> = .init(0)
    self.patch(
      \PasswordPoliciesFetchNetworkOperation.execute,
      with: { _ in
        fetchCount.access { $0 += 1 }
        return await Self.dto(length: 24)
      }
    )

    let loader: PasswordPoliciesLoader = try testedInstance()
    _ = await loader.policies()
    _ = await loader.policies()
    _ = await loader.policies()

    XCTAssertEqual(fetchCount.get(), 1)
  }

  func test_policies_returnsDefault_andRetries_whenFetchFails() async throws {
    let fetchCount: CriticalState<Int> = .init(0)
    self.patch(
      \PasswordPoliciesFetchNetworkOperation.execute,
      with: { _ in
        fetchCount.access { $0 += 1 }
        throw MockError()
      }
    )

    let loader: PasswordPoliciesLoader = try testedInstance()
    let first: SecretGenerator.Configuration = await loader.policies()
    let second: SecretGenerator.Configuration = await loader.policies()

    XCTAssertEqual(
      first.passwordGeneratorSettings.length,
      SecretGenerator.Configuration.default.passwordGeneratorSettings.length
    )
    XCTAssertEqual(
      second.passwordGeneratorSettings.length,
      SecretGenerator.Configuration.default.passwordGeneratorSettings.length
    )
    XCTAssertEqual(fetchCount.get(), 2)
  }

  func test_policies_concurrentFirstCalls_shareOneFetch() async throws {
    let fetchCount: CriticalState<Int> = .init(0)
    let proceed: CriticalState<CheckedContinuation<Void, Never>?> = .init(.none)

    self.patch(
      \PasswordPoliciesFetchNetworkOperation.execute,
      with: { _ in
        fetchCount.access { $0 += 1 }
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
          proceed.set(continuation)
        }
        return await Self.dto(length: 24)
      }
    )

    let loader: PasswordPoliciesLoader = try testedInstance()

    async let first: SecretGenerator.Configuration = loader.policies()
    async let second: SecretGenerator.Configuration = loader.policies()
    async let third: SecretGenerator.Configuration = loader.policies()

    while proceed.get() == nil {
      await Task.yield()
    }
    proceed.get()?.resume()

    _ = await (first, second, third)
    XCTAssertEqual(fetchCount.get(), 1)
  }

  func test_policies_shortCircuitsToDefault_whenPluginDisabled() async throws {
    set(
      SessionScope.self,
      context: .init(
        account: .mock_ada,
        configuration: SessionConfiguration.mock_1.with { (configuration: inout SessionConfiguration) in
          configuration.passwordPolicies = .init(
            passwordPoliciesEnabled: false,
            passwordPoliciesUpdateEnabled: false
          )
        }
      )
    )

    let fetchCount: CriticalState<Int> = .init(0)
    self.patch(
      \PasswordPoliciesFetchNetworkOperation.execute,
      with: { _ in
        fetchCount.access { $0 += 1 }
        return await Self.dto(length: 24)
      }
    )

    let loader: PasswordPoliciesLoader = try testedInstance()
    let configuration: SecretGenerator.Configuration = await loader.policies()

    XCTAssertEqual(
      configuration.passwordGeneratorSettings.length,
      SecretGenerator.Configuration.default.passwordGeneratorSettings.length
    )
    XCTAssertEqual(fetchCount.get(), 0)
  }

  // MARK: - Helpers

  private static func dto(length: Int) -> PasswordPoliciesDTO {
    PasswordPoliciesDTO(
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

private struct MockError: Error {}
