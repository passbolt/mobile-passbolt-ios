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
final class StoredPropertyTests: LoadableFeatureTestCase<TestStoredProperty> {

  override class func testedImplementationRegister(
    _ registry: inout FeaturesRegistry
  ) {
		registry.usePassboltStoredProperty(TestStoredPropertyDescription.self, in: RootFeaturesScope.self)
  }

  func test_get_fetchesPropertyWithExpectedValue() async throws {
    let expectedResult: Int = 42
    self.patch(
      \OSStoredProperties.fetch,
      with: { _ in
        expectedResult
      }
    )

    let instance: TestStoredProperty = try self.testedInstance()

    XCTAssertEqual(
      instance.value,
      expectedResult
    )
  }

  func test_get_fetchesPropertyWithExpectedKey() async throws {
		let expectedResult: OSStoredPropertyKey = TestStoredPropertyDescription.key
    let result: CriticalState<OSStoredPropertyKey?> = .init(.none)
    self.patch(
      \OSStoredProperties.fetch,
      with: { key in
        result.set(\.self, key)
        return 0
      }
    )

    let instance: TestStoredProperty = try self.testedInstance()

    _ = instance.value

    XCTAssertEqual(
      result.get(\.self),
      expectedResult
    )
  }

  func test_set_storesPropertyWithExpectedValue() async throws {
    let expectedResult: Int = 42
    let result: CriticalState<Int?> = .init(.none)
    self.patch(
      \OSStoredProperties.fetch,
      with: always(result.get(\.self))
    )
    self.patch(
      \OSStoredProperties.store,
      with: { _, value in
        result.set(\.self, value as? Int)
      }
    )

    var instance: TestStoredProperty = try self.testedInstance()

    instance.value = expectedResult

    XCTAssertEqual(
      result.get(\.self),
      expectedResult
    )
  }

  func test_set_storesPropertyWithExpectedKey() async throws {
    let expectedResult: OSStoredPropertyKey = "test"
    let result: CriticalState<OSStoredPropertyKey?> = .init(.none)
    self.patch(
      \OSStoredProperties.fetch,
      with: always(result.get(\.self))
    )
    self.patch(
      \OSStoredProperties.store,
      with: { key, _ in
        result.set(\.self, key)
      }
    )

    var instance: TestStoredProperty = try self.testedInstance()

    instance.value = 0

    XCTAssertEqual(
      result.get(\.self),
      expectedResult
    )
  }

	func test_set_storesPropertyWithExpectedAccountKey() async throws {
		TestStoredPropertyDescription.shared = false
		defer { TestStoredPropertyDescription.shared = true }
		let expectedResult: OSStoredPropertyKey = "test-\(Account.mock_ada.localID.rawValue)"
		let result: CriticalState<OSStoredPropertyKey?> = .init(.none)
		set(
			SessionScope.self,
			context: .init(
				account: .mock_ada,
				configuration: .mock_1
			)
		)
		self.patch(
			\OSStoredProperties.fetch,
			with: always(result.get(\.self))
		)
		self.patch(
			\OSStoredProperties.store,
			with: { key, _ in
				result.set(\.self, key)
			}
		)

		var instance: TestStoredProperty = try self.testedInstance()

		instance.value = 0

		XCTAssertEqual(
			result.get(\.self),
			expectedResult
		)
	}
}

typealias TestStoredProperty = StoredProperty<TestStoredPropertyDescription>

enum TestStoredPropertyDescription: StoredPropertyDescription {

	typealias Value = Int

	static var shared: Bool = true

	static var key: OSStoredPropertyKey { "test" }
}
