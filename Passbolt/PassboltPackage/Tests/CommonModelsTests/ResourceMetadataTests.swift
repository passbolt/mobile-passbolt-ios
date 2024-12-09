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
import Commons
@testable import CommonModels

final class ResourceMetadataTests: TestCase {
  
  func test_modifyingName_shouldModifyNameInJSON() throws {
    let json: JSON = .object([
      "name": .string("test name"),
    ])
    var metadata = try ResourceMetadata(resourceId: .init(), json: json)
    XCTAssertEqual(metadata.json[keyPath: \.name], "test name")
    metadata.name = "new name"
    XCTAssertEqual(metadata.json[keyPath: \.name], "new name")
  }
  
  func test_modifyingUsername_shouldModifyUsernameInJSON() throws {
    let json: JSON = .object([
      "name": .string("test name"),
      "username": .string("test username"),
    ])
    
    var metadata = try ResourceMetadata(resourceId: .init(), json: json)
    XCTAssertEqual(metadata.json[keyPath: \.username], "test username")
    metadata.username = "new username"
    XCTAssertEqual(metadata.json[keyPath: \.username], "new username")
  }
  
  func test_modifyingDescription_shouldModifyDescriptionInJSON() throws {
    let json: JSON = .object([
      "name": .string("test name"),
      "description": .string("test description"),
    ])
    
    var metadata = try ResourceMetadata(resourceId: .init(), json: json)
    XCTAssertEqual(metadata.json[keyPath: \.description], "test description")
    metadata.description = "new description"
    XCTAssertEqual(metadata.json[keyPath: \.description], "new description")
  }
  
  func test_creatingResourceMetadata_withoutNameInJSON_shouldFail() {
    let json: JSON = .object([
      "username": .string("test username"),
    ])
    
    verifyIf(try ResourceMetadata(resourceId: .init(), json: json), throws: InternalInconsistency.self)
  }
  
  func test_modifyingKnownKey_shouldNotAffectUnknownKeys() throws {
    let json: JSON = .object([
      "name": .string("test name"),
      "unknownKey": .string("unknown key value")
    ])
    
    var metadata = try ResourceMetadata(resourceId: .init(), json: json)
    XCTAssertEqual(metadata.json[keyPath: \.name], "test name")
    metadata.name = "new name"
    XCTAssertEqual(metadata.json[keyPath: \.unknownKey], "unknown key value")
    XCTAssertEqual(metadata.json[keyPath: \.name], "new name")
  }
}
