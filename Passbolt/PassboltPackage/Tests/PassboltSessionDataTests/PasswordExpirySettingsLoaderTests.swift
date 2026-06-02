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

import CoreTest
import NetworkOperations
import TestExtensions

@testable import PassboltSessionData

// swift-format-ignore: AlwaysUseLowerCamelCase
final class PasswordExpirySettingsLoaderTests: FeaturesTestCase {

  override func commonPrepare() async throws {
    try await super.commonPrepare()
    set(
      SessionScope.self,
      context: .init(
        account: .mock_ada,
        configuration: .mock_1
      )
    )
    register(
      { $0.usePassboltPasswordExpirySettingsLoader() },
      for: PasswordExpirySettingsLoader.self
    )
  }

  func test_settings_returnsFetchedValue() async throws {
    let sample: PasswordExpirySettings = Self.sample
    patch(
      \PasswordExpirySettingsFetchNetworkOperation.execute,
      with: always(sample)
    )
    let feature: PasswordExpirySettingsLoader = try self.testedInstance()

    await verifyIf(
      try await feature.settings(),
      isEqual: Self.sample
    )
  }

  func test_settings_cachesAfterFirstFetch() async throws {
    let fetchCount: CriticalState<Int> = .init(0)
    patch(
      \PasswordExpirySettingsFetchNetworkOperation.execute,
      with: { _ in
        fetchCount.access { $0 += 1 }
        return await Self.sample
      }
    )

    let feature: PasswordExpirySettingsLoader = try self.testedInstance()
    _ = try await feature.settings()
    _ = try await feature.settings()
    _ = try await feature.settings()

    await verifyIf(fetchCount.get(), isEqual: 1)
  }

  func test_settings_throws_andRetries_whenFetchFails() async throws {
    let fetchCount: CriticalState<Int> = .init(0)
    patch(
      \PasswordExpirySettingsFetchNetworkOperation.execute,
      with: { _ in
        fetchCount.access { $0 += 1 }
        throw MockIssue.error()
      }
    )

    let feature: PasswordExpirySettingsLoader = try self.testedInstance()

    await verifyIf(try await feature.settings(), throws: MockIssue.self)
    await verifyIf(try await feature.settings(), throws: MockIssue.self)
    await verifyIf(fetchCount.get(), isEqual: 2)
  }

  func test_settings_concurrentFirstCalls_shareOneFetch() async throws {
    let fetchCount: CriticalState<Int> = .init(0)
    let proceed: CriticalState<CheckedContinuation<Void, Never>?> = .init(.none)

    patch(
      \PasswordExpirySettingsFetchNetworkOperation.execute,
      with: { _ in
        fetchCount.access { $0 += 1 }
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
          proceed.set(continuation)
        }
        return await Self.sample
      }
    )

    let feature: PasswordExpirySettingsLoader = try self.testedInstance()

    async let first: PasswordExpirySettings = feature.settings()
    async let second: PasswordExpirySettings = feature.settings()
    async let third: PasswordExpirySettings = feature.settings()

    while proceed.get() == nil {
      await Task.yield()
    }
    proceed.get()?.resume()

    _ = try await (first, second, third)
    await verifyIf(fetchCount.get(), isEqual: 1)
  }

  private static let sample: PasswordExpirySettings = .init(
    automaticUpdate: true,
    automaticExpiry: true,
    defaultExpiryPeriod: 13
  )
}
