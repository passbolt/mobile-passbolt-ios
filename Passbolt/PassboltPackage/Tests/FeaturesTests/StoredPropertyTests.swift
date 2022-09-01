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
final class StoredPropertyTests: TestCase {

  override func featuresActorSetUp() async throws {
    try await super.featuresActorSetUp()
    self.features.usePassboltStoredProperty(Int.self)
  }

  func test_get_fetchesPropertyWithExpectedValue() async throws {
    let expectedResult: Int = 42
    self.features.patch(
      \StoredProperties.fetch,
      with: { _ in
        expectedResult
      }
    )

    let instance: StoredProperty<Int> = try await self.testedInstance(context: "test")

    XCTAssertEqual(
      instance.value,
      expectedResult
    )
  }

  func test_get_fetchesPropertyWithExpectedKey() async throws {
    let expectedResult: StoredPropertyKey = "test"
    let result: CriticalState<StoredPropertyKey?> = .init(.none)
    self.features.patch(
      \StoredProperties.fetch,
      with: { key in
        result.set(\.self, key)
        return 0
      }
    )

    let instance: StoredProperty<Int> = try await self.testedInstance(context: expectedResult)

    _ = instance.value

    XCTAssertEqual(
      result.get(\.self),
      expectedResult
    )
  }

  func test_set_storesPropertyWithExpectedValue() async throws {
    let expectedResult: Int = 42
    let result: CriticalState<Int?> = .init(.none)
    self.features.patch(
      \StoredProperties.fetch,
      with: always(result.get(\.self))
    )
    self.features.patch(
      \StoredProperties.store,
      with: { _, value in
        result.set(\.self, value as? Int)
      }
    )

    var instance: StoredProperty<Int> = try await self.testedInstance(context: "test")

    instance.value = expectedResult

    XCTAssertEqual(
      result.get(\.self),
      expectedResult
    )
  }

  func test_set_storesPropertyWithExpectedKey() async throws {
    let expectedResult: StoredPropertyKey = "test"
    let result: CriticalState<StoredPropertyKey?> = .init(.none)
    self.features.patch(
      \StoredProperties.fetch,
      with: always(result.get(\.self))
    )
    self.features.patch(
      \StoredProperties.store,
      with: { key, _ in
        result.set(\.self, key)
      }
    )

    var instance: StoredProperty<Int> = try await self.testedInstance(context: "test")

    instance.value = 0

    XCTAssertEqual(
      result.get(\.self),
      expectedResult
    )
  }
}
