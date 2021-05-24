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

import Combine
import Commons
import Features
@testable import NetworkClient
@testable import Networking
import TestExtensions
import XCTest

// swiftlint:disable explicit_acl
// swiftlint:disable explicit_top_level_acl
// swiftlint:disable implicitly_unwrapped_optional
// swiftlint:disable force_unwrapping
final class NetworkingDecoratorsTests: XCTestCase {
  
  var diagnostics: Diagnostics!
  var cancellables: Array<AnyCancellable>!
  
  override class func setUp() {
    super.setUp()
    FeatureFactory.autoLoadFeatures = false
  }
  
  override func setUp() {
    super.setUp()
    diagnostics = .placeholder
    diagnostics.uniqueID = { "uniqueID" }
    cancellables = .init()
  }
  
  override func tearDown() {
    diagnostics = nil
    cancellables = nil
    super.tearDown()
  }

  func test_withLogs_logsMessagesForRequestAndResponse() {
    var result: Array<String> = .init()
    diagnostics.log = { message in
      result.append(message)
    }
    
    var networking: Networking = .placeholder
    networking.execute = { _ in
      Just(
        HTTPResponse(
          url: URL(string: "https://passbolt.com")!,
          statusCode: 200,
          headers: [:],
          body: .empty
        )
      )
      .setFailureType(to: HTTPError.self)
      .eraseToAnyPublisher()
    }
    networking = networking.withLogs(using: diagnostics)
    
    networking.make(
      HTTPRequest(
        url: URL(string: "https://passbolt.com")!,
        method: .get,
        headers: [:],
        body: .empty
      )
    )
    .receive(on: ImmediateScheduler.shared)
    .sink(
      receiveCompletion: { _ in },
      receiveValue: { _ in }
    )
    .store(in: &cancellables)
    
    XCTAssertEqual(
      result,
      [
        "Executing request <uniqueID>:\nGET  HTTP/1.1\n\n\n\n---",
        "Received <uniqueID>:\nHTTP/1.1 200\n\n\n\n---"
      ]
    )
  }
  
  func test_withLogs_logsMessagesForRequestAndError() {
    var result: Array<String> = .init()
    diagnostics.log = { message in
      result.append(message)
    }
    
    var networking: Networking = .placeholder
    networking.execute = { _ in
      Fail<HTTPResponse, HTTPError>(error: .cannotConnect)
      .eraseToAnyPublisher()
    }
    networking = networking.withLogs(using: diagnostics)
    
    networking.make(
      HTTPRequest(
        url: URL(string: "https://passbolt.com")!,
        method: .get,
        headers: [:],
        body: .empty
      )
    )
    .receive(on: ImmediateScheduler.shared)
    .sink(
      receiveCompletion: { _ in },
      receiveValue: { _ in }
    )
    .store(in: &cancellables)
    
    XCTAssertEqual(
      result,
      [
        "Executing request <uniqueID>:\nGET  HTTP/1.1\n\n\n\n---",
        "Received<uniqueID>:\ncannotConnect\n---"
      ]
    )
  }
}
