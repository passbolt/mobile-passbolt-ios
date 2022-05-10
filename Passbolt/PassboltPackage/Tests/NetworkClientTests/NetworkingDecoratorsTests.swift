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

import CommonModels
import TestExtensions
import XCTest

@testable import Features
@testable import NetworkClient

// swift-format-ignore: AlwaysUseLowerCamelCase, NeverUseImplicitlyUnwrappedOptionals
final class NetworkingDecoratorsTests: XCTestCase {

  var diagnostics: Diagnostics!
  var cancellables: Cancellables!

  override func setUp() {
    super.setUp()
    diagnostics = .placeholder
    diagnostics.measurePerformance = { _ in Diagnostics.TimeMeasurement(event: { _ in }, end: {}) }
    diagnostics.uniqueID = { "uniqueID" }
    cancellables = .init()
  }

  override func tearDown() {
    diagnostics = nil
    cancellables = nil
    super.tearDown()
  }

  func test_withLogs_logsMessagesForRequestAndResponse() async throws {
    var result: Array<String> = .init()
    diagnostics.debugLog = { message in
      result.append(message)
    }

    var networking: Networking = .placeholder
    networking.execute = { _, _ in
      HTTPResponse(
        url: URL(string: "https://passbolt.com")!,
        statusCode: 200,
        headers: [:],
        body: .empty
      )
    }
    networking = networking.withLogs(using: diagnostics)

    _ = try await networking.make(
      HTTPRequest(
        url: URL(string: "https://passbolt.com")!,
        method: .get,
        headers: [:],
        body: .empty
      )
    )

    XCTAssertEqual(
      result,
      [
        "Executing request <uniqueID> (useCache: false):\nGET  HTTP/1.1\n\n\n\n---",
        "Received <uniqueID>:\nHTTP/1.1 200\n\n\n\n---",
      ]
    )
  }

  func test_withLogs_logsMessagesForRequestAndError() async throws {
    var result: Array<String> = .init()
    diagnostics.debugLog = { message in
      result.append(message)
    }

    var networking: Networking = .placeholder
    networking.execute = { _, _ in
      throw MockIssue.error()
    }
    networking = networking.withLogs(using: diagnostics)

    _ =
      try? await networking
      .make(
        HTTPRequest(
          url: URL(string: "https://passbolt.com")!,
          method: .get,
          headers: [:],
          body: .empty
        )
      )

    XCTAssertEqual(
      result,
      [
        "Executing request <uniqueID> (useCache: false):\nGET  HTTP/1.1\n\n\n\n---",
        "Received <uniqueID>:\nMockIssue\ntest\nDiagnosticsContext\nMock:42-MockIssue\n\n\n---",
      ]
    )
  }
}
