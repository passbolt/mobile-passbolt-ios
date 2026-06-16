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

import XCTest

@testable import CommonModels

final class ResourceTypeUpgradeTests: XCTestCase {

  func test_v5UpgradedSlug_mapsPasswordToV5Password() {
    let type: ResourceType = .init(id: .init(), slug: .password)
    XCTAssertEqual(type.v5UpgradedSlug, .v5Password)
  }

  func test_v5UpgradedSlug_mapsPasswordWithDescriptionToV5Default() {
    let type: ResourceType = .init(id: .init(), slug: .passwordWithDescription)
    XCTAssertEqual(type.v5UpgradedSlug, .v5Default)
  }

  func test_v5UpgradedSlug_mapsPasswordWithTOTPToV5DefaultWithTOTP() {
    let type: ResourceType = .init(id: .init(), slug: .passwordWithTOTP)
    XCTAssertEqual(type.v5UpgradedSlug, .v5DefaultWithTOTP)
  }

  func test_v5UpgradedSlug_mapsTotpToV5StandaloneTOTP() {
    let type: ResourceType = .init(id: .init(), slug: .totp)
    XCTAssertEqual(type.v5UpgradedSlug, .v5StandaloneTOTP)
  }

  func test_v5UpgradedSlug_returnsNil_forV5Types() {
    let v5Slugs: Array<ResourceSpecification.Slug> = [
      .v5Default,
      .v5DefaultWithTOTP,
      .v5StandaloneTOTP,
      .v5Password,
      .v5CustomFields,
      .v5StandaloneNote,
      .v5PinCode,
    ]
    for slug: ResourceSpecification.Slug in v5Slugs {
      let type: ResourceType = .init(id: .init(), slug: slug)
      XCTAssertNil(
        type.v5UpgradedSlug,
        "V5 slug \(slug) should not have a V5 equivalent"
      )
    }
  }

  // Regression: upgrading a v4 resource to its v5 equivalent must write the
  // NEW resource type id into the encrypted metadata, not keep the old v4 id.
  func test_updateType_writesNewTypeID_intoMetadata_whenUpgradingFromV4ToV5() throws {
    let v5Type: ResourceType = .init(id: .init(), slug: .v5Default)
    var resource: Resource = .init(type: .init(id: .init(), slug: .passwordWithDescription))

    try resource.updateType(to: v5Type)

    XCTAssertEqual(
      resource.meta[keyPath: \.resource_type_id].stringValue,
      v5Type.id.rawValue.rawValue.uuidString
    )
  }

  func test_updateType_writesNewTypeID_intoMetadata_whenChangingBetweenV5Types() throws {
    let targetType: ResourceType = .init(id: .init(), slug: .v5DefaultWithTOTP)
    var resource: Resource = .init(type: .init(id: .init(), slug: .v5Default))

    try resource.updateType(to: targetType)

    XCTAssertEqual(
      resource.meta[keyPath: \.resource_type_id].stringValue,
      targetType.id.rawValue.rawValue.uuidString
    )
  }
}
