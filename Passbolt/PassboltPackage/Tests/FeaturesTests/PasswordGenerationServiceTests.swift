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
      \PasswordPoliciesFetchDatabaseOperation.execute,
      with: { _ in await Self.policy(length: 24) }
    )
  }

  // MARK: - currentConfiguration

  func test_currentConfiguration_returnsFetchedConfiguration() async throws {
    let service: PasswordGenerationService = try testedInstance()
    let configuration: PasswordPoliciesDSV = await service.currentConfiguration()
    XCTAssertEqual(configuration.passwordGeneratorSettings.length, 24)
  }

  func test_currentConfiguration_cachesAfterFirstFetch() async throws {
    let fetchCount: CriticalState<Int> = .init(0)
    self.patch(
      \PasswordPoliciesFetchDatabaseOperation.execute,
      with: { _ in
        fetchCount.access { $0 += 1 }
        return await Self.policy(length: 24)
      }
    )

    let service: PasswordGenerationService = try testedInstance()
    _ = await service.currentConfiguration()
    _ = await service.currentConfiguration()
    _ = await service.currentConfiguration()

    XCTAssertEqual(fetchCount.get(), 1)
  }

  func test_currentConfiguration_returnsDefault_whenFetchFails() async throws {
    self.patch(
      \PasswordPoliciesFetchDatabaseOperation.execute,
      with: { _ in throw MockError() }
    )

    let service: PasswordGenerationService = try testedInstance()
    let configuration: PasswordPoliciesDSV = await service.currentConfiguration()

    XCTAssertEqual(
      configuration.passwordGeneratorSettings.length,
      SecretGenerator.Configuration.default.passwordGeneratorSettings.length
    )
  }

  func test_currentConfiguration_doesNotCacheFallback_andRetriesOnNextCall() async throws {
    let fetchCount: CriticalState<Int> = .init(0)
    self.patch(
      \PasswordPoliciesFetchDatabaseOperation.execute,
      with: { _ in
        fetchCount.access { $0 += 1 }
        throw MockError()
      }
    )

    let service: PasswordGenerationService = try testedInstance()
    _ = await service.currentConfiguration()
    _ = await service.currentConfiguration()

    XCTAssertEqual(fetchCount.get(), 2)
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

  func test_updateConfiguration_preventsFurtherFetches() async throws {
    let fetchCount: CriticalState<Int> = .init(0)
    self.patch(
      \PasswordPoliciesFetchDatabaseOperation.execute,
      with: { _ in
        fetchCount.access { $0 += 1 }
        return await Self.policy(length: 24)
      }
    )

    let service: PasswordGenerationService = try testedInstance()
    await service.updateConfiguration(Self.policy(length: 64))

    _ = await service.currentConfiguration()
    _ = await service.currentConfiguration()

    XCTAssertEqual(fetchCount.get(), 0)
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

  // MARK: - Single-flight

  func test_currentConfiguration_concurrentFirstCalls_shareOneFetch() async throws {
    let fetchCount: CriticalState<Int> = .init(0)
    let proceed: CriticalState<CheckedContinuation<Void, Never>?> = .init(.none)

    self.patch(
      \PasswordPoliciesFetchDatabaseOperation.execute,
      with: { _ in
        fetchCount.access { $0 += 1 }
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
          proceed.set(continuation)
        }
        return await Self.policy(length: 24)
      }
    )

    let service: PasswordGenerationService = try testedInstance()

    async let first: PasswordPoliciesDSV = service.currentConfiguration()
    async let second: PasswordPoliciesDSV = service.currentConfiguration()
    async let third: PasswordPoliciesDSV = service.currentConfiguration()

    // Yield until the (single) in-flight fetch parks on its continuation; other callers
    // by then must have entered the cache-access path and attached to the same task.
    while proceed.get() == nil {
      await Task.yield()
    }
    proceed.get()?.resume()

    _ = await (first, second, third)
    XCTAssertEqual(fetchCount.get(), 1)
  }

  // MARK: - Helpers

  private static func policy(length: Int) -> PasswordPoliciesDSV {
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

private struct MockError: Error {}
