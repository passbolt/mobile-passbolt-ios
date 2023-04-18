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

import Accounts
import Foundation
import XCTest

// swift-format-ignore: AlwaysUseLowerCamelCase, NeverUseImplicitlyUnwrappedOptionals
final class ConfigDecodingTests: XCTestCase {

  func test_pluginsDecoding_withAllPluginsEnabled_succeeds() {
    let rawJSON: Data = """
      {
          "legal": {
          "privacy_policy": {
            "url": "https://www.passbolt.com/privacy"
          },
          "terms": {
            "url": "https://www.passbolt.com/terms"
          }
        },
        "plugins": {
          "previewPassword": {
            "enabled": true
          },
          "tags": {
            "version": "1.0.1",
            "enabled": true
          },
          "totpResourceType": {
            "enabled": true
          },
          "folders": {
            "version": "2.0.0",
            "enabled": true
          }
        }
      }
      """.data(using: .utf8)!

    let config: Config? = try? JSONDecoder().decode(Config.self, from: rawJSON)

    let legal: Config.Legal = .init(
      privacyPolicy: .init(url: "https://www.passbolt.com/privacy"),
      terms: .init(url: "https://www.passbolt.com/terms")
    )
    let folders: Config.Folders = .init(enabled: true, version: "2.0.0")
    let previewPassword: Config.PreviewPassword = .init(enabled: true)
    let tags: Config.Tags = .init(enabled: true, version: "1.0.1")
    let tags: Config.TOTP = .init(enabled: true)

    XCTAssertEqual(config!.legal, legal)
    XCTAssertTrue(config!.plugins.contains { $0 as? Config.Folders == folders })
    XCTAssertTrue(config!.plugins.contains { $0 as? Config.PreviewPassword == previewPassword })
    XCTAssertTrue(config!.plugins.contains { $0 as? Config.Tags == tags })
    XCTAssertTrue(config!.plugins.contains { $0 as? Config.TOTP == totp })
  }

  func test_pluginsDecoding_withNoPlugins_succeeds() {
    let rawJSON: Data = """
      {
        "legal": null,
        "plugins": {
        }
      }
      """.data(using: .utf8)!

    let config: Config? = try? JSONDecoder().decode(Config.self, from: rawJSON)

    XCTAssertNil(config!.legal)
    XCTAssertTrue(config!.plugins.isEmpty)
  }

  func test_pluginsDecoding_withInvalidJSON_fails() {
    let rawJSON: Data = """
      {
          "legal": {
        },
        "plugins": {
          tags": {
            "version": "1.0.1",
            "enabled": true
          },
          "folders": {
            "version": "2.0.0",
            "enabled": true
          }
        }
      }
      """.data(using: .utf8)!

    let config: Config? = try? JSONDecoder().decode(Config.self, from: rawJSON)

    XCTAssertNil(config)
  }
}
