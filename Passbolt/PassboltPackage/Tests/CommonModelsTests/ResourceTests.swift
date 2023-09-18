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

final class ResourceTests: XCTestCase {

  func test_editing_updatesContent() throws {
    var resource: Resource = .init(
      type: .init(
        id: .init(),
        specification: .init(
          slug: "test",
          metaFields: [
            .init(
              path: \.meta.name,
              name: "name",
              content: .string(maxLength: 10),
              required: true,
              encrypted: false
            ),
            .init(
              path: \.meta.optional,
              name: "optional",
              content: .int(min: 10),
              required: false,
              encrypted: false
            ),
          ],
          secretFields: [
            .init(
              path: \.secret.password,
              name: "password",
              content: .string(),
              required: true,
              encrypted: true
            ),
            .init(
              path: \.secret.nested,
              name: "nested",
              content: .structure([
                .init(
                  path: \.secret.nested.secret,
                  name: "secret",
                  content: .string(minLength: 10),
                  required: true,
                  encrypted: true
                )
              ]),
              required: false,
              encrypted: true
            ),
          ]
        )
      )
    )
    resource.meta.name = "name"
    XCTAssertEqual(resource.name, "name")
    resource.secret.nested.secret = "$3crEt"
    XCTAssertEqual(resource.secret.nested.secret, "$3crEt")
    // updating fields out of specifications is allowed
    // it makes possible to safely update and edit resources
    // with not fully known structure without data loss
    resource.secret.totp.secret = "DASDASDASSD"
    XCTAssertEqual(resource.secret.totp.secret.stringValue, "DASDASDASSD")
    resource.secret.totp.period = 30
    XCTAssertEqual(resource.secret.totp.period.intValue, 30)
  }

  func test_validate_failsWhenNeeded() throws {
    var resource: Resource = .init(
			id: .init(uuidString: UUID().uuidString),
      type: .init(
        id: .init(),
        specification: .init(
          slug: "test",
          metaFields: [
            .init(
              path: \.meta.name,
              name: "name",
              content: .string(maxLength: 10),
              required: true,
              encrypted: false
            ),
            .init(
              path: \.meta.optional,
              name: "optional",
              content: .int(min: 10),
              required: false,
              encrypted: false
            ),
            .init(
              path: \.meta.selection,
              name: "selection",
              content: .stringEnum(
                values: [
                  "ONE",
                  "TWO",
                ]
              ),
              required: false,
              encrypted: false
            ),
          ],
          secretFields: [
            .init(
              path: \.secret.password,
              name: "password",
              content: .string(),
              required: true,
              encrypted: true
            ),
            .init(
              path: \.secret.nested,
              name: "nested",
              content: .structure([
                .init(
                  path: \.secret.nested.secret,
                  name: "secret",
                  content: .string(minLength: 10),
                  required: true,
                  encrypted: true
                )
              ]),
              required: false,
              encrypted: true
            ),
          ]
        )
      )
    )

    XCTAssertThrowsError(try resource.validate()) {
      guard let validationError: InvalidResourceField = $0 as? InvalidResourceField
      else { return XCTFail("Unexpected error reveived") }
      XCTAssertEqual(validationError.path, \.meta.name)
      XCTAssertEqual(resource[keyPath: validationError.path], "")
    }

    resource.meta.name = "tooLongName"
    XCTAssertThrowsError(try resource.validate()) {
      guard let validationError: InvalidResourceField = $0 as? InvalidResourceField
      else { return XCTFail("Unexpected error reveived") }
      XCTAssertEqual(validationError.path, \.meta.name)
      XCTAssertEqual(resource[keyPath: validationError.path], "tooLongName")
    }

    resource.meta.name = "name"
    resource.meta.optional = 0
    XCTAssertThrowsError(try resource.validate()) {
      guard let validationError: InvalidResourceField = $0 as? InvalidResourceField
      else { return XCTFail("Unexpected error reveived") }
      XCTAssertEqual(validationError.path, \.meta.optional)
      XCTAssertEqual(resource[keyPath: validationError.path], 0)
    }

    resource.meta.optional = 42
    XCTAssertNoThrow(try resource.validate())

    resource.secret.password = ""
    XCTAssertThrowsError(try resource.validate()) {
      guard let validationError: InvalidResourceField = $0 as? InvalidResourceField
      else { return XCTFail("Unexpected error reveived") }
      XCTAssertEqual(validationError.path, \.secret.password)
      XCTAssertEqual(resource[keyPath: validationError.path], "")
    }

    resource.secret.password = "P@$sw0rD"
    XCTAssertNoThrow(try resource.validate())

    resource.meta.selection = "THREE"
    XCTAssertThrowsError(try resource.validate()) {
      guard let validationError: InvalidResourceField = $0 as? InvalidResourceField
      else { return XCTFail("Unexpected error reveived") }
      XCTAssertEqual(validationError.path, \.meta.selection)
      XCTAssertEqual(resource[keyPath: validationError.path], "THREE")
    }

    resource.meta.selection = "ONE"
    XCTAssertNoThrow(try resource.validate())

    // unknown fields are ignored by validation
    resource.meta.unknown = [1, "2", []]
    XCTAssertNoThrow(try resource.validate())

    resource.secret.nested = [:]
    XCTAssertThrowsError(try resource.validate()) {
      guard let validationError: InvalidResourceField = $0 as? InvalidResourceField
      else { return XCTFail("Unexpected error reveived") }
      XCTAssertEqual(validationError.path, \.secret.nested.secret)
      XCTAssertEqual(resource[keyPath: validationError.path], nil)
    }

    resource.secret.nested.secret = "$3crEt"
    XCTAssertThrowsError(try resource.validate()) {
      guard let validationError: InvalidResourceField = $0 as? InvalidResourceField
      else { return XCTFail("Unexpected error reveived") }
      XCTAssertEqual(validationError.path, \.secret.nested.secret)
      XCTAssertEqual(resource[keyPath: validationError.path], "$3crEt")
    }

    resource.secret.nested.secret = "$3crEt123456"
    XCTAssertNoThrow(try resource.validate())
  }

  func test_legacyResourceSecretCompatibility() throws {
    var resource: Resource = .init(
      type: .init(
        id: .init(),
        specification: .password
      )
    )
    resource.secret = "initial"
    XCTAssertEqual(resource.secret, "initial")
    XCTAssertEqual(resource.fields.filter(\.encrypted).count, 1)
    resource[keyPath: resource.fields.filter(\.encrypted).first!.path] = "edited with path"
    XCTAssertEqual(resource.secret, "edited with path")
    resource.secret = "final"
    XCTAssertEqual(resource[keyPath: \.secret], "final")
  }
}
