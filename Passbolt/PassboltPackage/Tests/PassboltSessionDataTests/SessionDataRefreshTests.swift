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
import Metadata
import TestExtensions

@testable import PassboltSessionData

// swift-format-ignore: AlwaysUseLowerCamelCase
final class SessionDataRefreshTests: FeaturesTestCase {
  override func commonPrepare() {
    super.commonPrepare()
    register(
      { $0.usePassboltSessionData() },
      for: SessionData.self
    )
    set(
      SessionScope.self,
      context: .init(
        account: .mock_ada,
        configuration: .mock_default
      )
    )
    patch(
      \UsersFetchNetworkOperation.execute,
      with: always([])
    )
    patch(
      \UsersStoreDatabaseOperation.execute,
      with: always(Void())
    )
    patch(
      \UserGroupsFetchNetworkOperation.execute,
      with: always([])
    )
    patch(
      \UserGroupsStoreDatabaseOperation.execute,
      with: always(Void())
    )
    patch(
      \OSTime.timestamp,
      with: always(0)
    )
    patch(
      \MetadataSettingsService.fetchKeysSettings,
      with: always(())
    )
    patch(
      \MetadataSettingsService.fetchTypesSettings,
      with: always(())
    )
    patch(
      \MetadataSessionKeysFetchNetworkOperation.execute,
      with: always([])
    )
    patch(
      \MetadataKeysService.cleanupDecryptionCache,
      with: always(Void())
    )
    patch(
      \ResourceUpdater.updateResources,
      with: always(Void())
    )
  }

  func test_sessionDataRefresh_shouldNotFetchMetadataKeys_ifFeatureIsDisabled() async throws {
    set(
      SessionScope.self,
      context: .init(
        account: .mock_ada,
        configuration: .mock_default.with(metadataEnabled: false)
      )
    )

    patch(
      \ResourceTypesFetchNetworkOperation.execute,
      with: always([])
    )

    patch(
      \ResourceTypesStoreDatabaseOperation.execute,
      with: always(Void())
    )

    patch(
      \MetadataKeysService.initialize,
      with: always(
        {
          XCTFail("Should not be initialized")
        }()
      )
    )

    let feature: SessionData = try self.testedInstance()
    try await feature.refreshIfNeeded()
  }

  func test_sessionDataRefresh_shouldFetchMetadataKeys_ifFeatureIsEnabled() async throws {
    set(
      SessionScope.self,
      context: .init(
        account: .mock_ada,
        configuration: .mock_default.with(metadataEnabled: true)
      )
    )
    patch(
      \ResourceTypesFetchNetworkOperation.execute,
      with: always([])
    )

    patch(
      \ResourceTypesStoreDatabaseOperation.execute,
      with: always(Void())
    )

    let fetchKeysExpectation: XCTestExpectation = .init(description: "Should fetch metadata keys.")
    let sendSessionKeysExpectation: XCTestExpectation = .init(description: "Should send session keys.")
    patch(
      \MetadataKeysService.initialize,
      with: always({ fetchKeysExpectation.fulfill() }())
    )
    patch(
      \MetadataKeysService.sendSessionKeys,
      with: always({ sendSessionKeysExpectation.fulfill() }())
    )

    let feature: SessionData = try self.testedInstance()
    try await feature.refreshIfNeeded()
    await fulfillment(of: [fetchKeysExpectation, sendSessionKeysExpectation], timeout: 1)
  }
}
