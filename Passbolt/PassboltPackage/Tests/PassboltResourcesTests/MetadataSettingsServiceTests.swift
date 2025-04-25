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

@testable import PassboltResources

final class MetadataSettingsServiceTests: LoadableFeatureTestCase<MetadataSettingsService> {
  override class var testedImplementationScope: any FeaturesScope.Type { SessionScope.self }

  override class func testedImplementationRegister(
    _ registry: inout FeaturesRegistry
  ) {
    registry.usePassboltMetadataSettingsService()
  }

  override func prepare() throws {
    self.set(
      SessionScope.self,
      context: .init(
        account: .mock_ada,
        configuration: .mock_1
      )
    )
  }

  func test_whenSettingsNotFetched_shouldUseDefaults() async throws {
    let testedInstance = try self.testedInstance()
    let keysSettings = testedInstance.keysSettings()
    XCTAssertEqual(keysSettings, MetadataKeysSettings.default)
    let typesSettings = testedInstance.typesSettings()
    XCTAssertEqual(typesSettings, MetadataTypesSettings.default)
  }

  func test_whenKeysSettingsFetched_shouldUseFetchedSettings() async throws {
    patch(
      \MetadataKeysSettingsFetchNetworkOperation.execute,
      with: always(.init(allowUsageOfPersonalKeys: false, zeroKnowledgeKeyShare: true))
    )

    let testedInstance = try self.testedInstance()
    try await testedInstance.fetchKeysSettings()
    let keysSettings = testedInstance.keysSettings()
    XCTAssertNotEqual(keysSettings, MetadataKeysSettings.default)
    XCTAssertEqual(keysSettings.allowUsageOfPersonalKeys, false)
    XCTAssertEqual(keysSettings.zeroKnowledgeKeyShare, true)
  }

  func test_whenTypesSettingsFetched_shouldUseFetchedSettings() async throws {
    patch(
      \MetadataTypesSettingsFetchNetworkOperation.execute,
      with: always(.init(defaultResourceTypes: .v5))
    )

    let testedInstance = try self.testedInstance()
    try await testedInstance.fetchTypesSettings()
    let typesSettings = testedInstance.typesSettings()
    XCTAssertNotEqual(typesSettings, MetadataTypesSettings.default)
    XCTAssertEqual(typesSettings.defaultResourceTypes, .v5)
  }
}

private struct MockError: Error {

}
