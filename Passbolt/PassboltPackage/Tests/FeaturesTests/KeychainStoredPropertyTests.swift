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
import XCTest

@testable import Features

// swift-format-ignore: AlwaysUseLowerCamelCase, NeverUseImplicitlyUnwrappedOptionals
final class KeychainStoredPropertyTests: LoadableFeatureTestCase<TestKeychainStoredProperty>, @unchecked Sendable {

  override class func testedImplementationRegister(
    _ registry: inout FeaturesRegistry
  ) {
    registry.usePassboltKeychainStoredProperty(
      TestKeychainStoredPropertyDescription.self,
      in: RootFeaturesScope.self
    )
  }

  func test_fetch_usesAccountScopedKeychainQuery() async throws {
    let result: CriticalState<OSKeychainQuery?> = .init(.none)
    set(
      SessionScope.self,
      context: .init(
        account: .mock_ada,
        configuration: .mock_1
      )
    )
    self.patch(
      \OSKeychain.load,
      with: { (query: OSKeychainQuery) in
        result.set(\.self, query)
        return .success(.init())
      }
    )

    let instance: TestKeychainStoredProperty = try self.testedInstance()

    _ = instance.variable.value

    XCTAssertEqual(
      result.get(\.self)?.key,
      TestKeychainStoredPropertyDescription.key
    )
    XCTAssertEqual(
      result.get(\.self)?.tag?.rawValue,
      Account.mock_ada.localID.rawValue
    )
    XCTAssertEqual(
      result.get(\.self)?.requiresBiometrics,
      false
    )
  }

  func test_assign_savesValueInKeychain() async throws {
    let result: CriticalState<Bool> = .init(false)
    set(
      SessionScope.self,
      context: .init(
        account: .mock_ada,
        configuration: .mock_1
      )
    )
    self.patch(
      \OSKeychain.load,
      with: always(.success(.init()))
    )
    self.patch(
      \OSKeychain.save,
      with: { (_: Data, _: OSKeychainQuery) in
        result.set(\.self, true)
        return .success(Void())
      }
    )

    let instance: TestKeychainStoredProperty = try self.testedInstance()

    instance.variable.assign(42)

    XCTAssertTrue(result.get(\.self))
  }

  func test_assignNone_deletesValueFromKeychain() async throws {
    let result: CriticalState<Bool> = .init(false)
    set(
      SessionScope.self,
      context: .init(
        account: .mock_ada,
        configuration: .mock_1
      )
    )
    self.patch(
      \OSKeychain.load,
      with: always(.success(.init()))
    )
    self.patch(
      \OSKeychain.delete,
      with: { (_: OSKeychainQuery) in
        result.set(\.self, true)
        return .success(Void())
      }
    )

    let instance: TestKeychainStoredProperty = try self.testedInstance()

    instance.variable.assign(.none)

    XCTAssertTrue(result.get(\.self))
  }
  func test_read_throws_whenKeychainLoadFails() async throws {
    set(
      SessionScope.self,
      context: .init(
        account: .mock_ada,
        configuration: .mock_1
      )
    )
    self.patch(
      \OSKeychain.load,
      with: always(.failure(MockIssue.error()))
    )

    let instance: TestKeychainStoredProperty = try self.testedInstance()

    XCTAssertThrowsError(try instance.read())
  }

  func test_variable_returnsNone_whenKeychainLoadFails() async throws {
    // documents the lossy behavior of the cached access - an unreachable keychain
    // is indistinguishable from a missing value there, which is why `read` exists
    set(
      SessionScope.self,
      context: .init(
        account: .mock_ada,
        configuration: .mock_1
      )
    )
    self.patch(
      \OSKeychain.load,
      with: always(.failure(MockIssue.error()))
    )

    let instance: TestKeychainStoredProperty = try self.testedInstance()

    XCTAssertNil(instance.variable.value)
  }

  func test_write_throws_whenKeychainSaveFails() async throws {
    set(
      SessionScope.self,
      context: .init(
        account: .mock_ada,
        configuration: .mock_1
      )
    )
    self.patch(
      \OSKeychain.load,
      with: always(.success(.init()))
    )
    self.patch(
      \OSKeychain.save,
      with: always(.failure(MockIssue.error()))
    )

    let instance: TestKeychainStoredProperty = try self.testedInstance()

    XCTAssertThrowsError(try instance.write(42))
  }

  func test_write_throws_whenKeychainDeleteFails() async throws {
    set(
      SessionScope.self,
      context: .init(
        account: .mock_ada,
        configuration: .mock_1
      )
    )
    self.patch(
      \OSKeychain.load,
      with: always(.success(.init()))
    )
    self.patch(
      \OSKeychain.delete,
      with: always(.failure(MockIssue.error()))
    )

    let instance: TestKeychainStoredProperty = try self.testedInstance()

    XCTAssertThrowsError(try instance.write(.none))
  }

  func test_assign_doesNotThrow_whenKeychainSaveFails() async throws {
    // the cached access swallows write failures on purpose, `write` is the throwing one
    set(
      SessionScope.self,
      context: .init(
        account: .mock_ada,
        configuration: .mock_1
      )
    )
    self.patch(
      \OSKeychain.load,
      with: always(.success(.init()))
    )
    self.patch(
      \OSKeychain.save,
      with: always(.failure(MockIssue.error()))
    )

    let instance: TestKeychainStoredProperty = try self.testedInstance()

    instance.variable.assign(42)

    XCTAssertEqual(instance.variable.value, 42)
  }
}

typealias TestKeychainStoredProperty = KeychainStoredProperty<TestKeychainStoredPropertyDescription>

enum TestKeychainStoredPropertyDescription: KeychainStoredPropertyDescription {

  typealias Value = Int

  static var key: OSKeychainQuery.Key { "test" }
}
