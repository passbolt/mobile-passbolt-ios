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

import Features
import TestExtensions
import UIComponents
import XCTest

@testable import SharedUIComponents

// swift-format-ignore: AlwaysUseLowerCamelCase, NeverUseImplicitlyUnwrappedOptionals
@MainActor
final class LogsViewerControllerTests: FeaturesTestCase {

  func test_refreshLogs_triggersDiagnosticLogsRead() async throws {
    var result: Void?
    Diagnostics.shared.info = { () -> Array<String> in
      result = Void()
      return []
    }

    let controller: LogsViewerController = try testedInstance()

    controller
      .refreshLogs()
    await asyncExecutionControl.executeAll()

    XCTAssertNotNil(result)
  }

  func test_logsPublisher_publishesNil_initially() async throws {
    let controller: LogsViewerController = try testedInstance()

    var result: Array<String>?
    controller
      .logsPublisher()
      .sink { logs in
        result = logs
      }
      .store(in: cancellables)

    XCTAssertNil(result)
  }

  func test_logsPublisher_publishesCachedValue_afterRefreshingLogs() async throws {
    Diagnostics.shared.info = { () -> Array<String> in
      []
    }

    let controller: LogsViewerController = try testedInstance()

    controller.refreshLogs()
    await asyncExecutionControl.executeAll()

    var result: Array<String>?
    controller
      .logsPublisher()
      .sink { logs in
        result = logs
      }
      .store(in: cancellables)

    XCTAssertEqual(result, [])
  }

  func test_shareMenuPresentationPublisher_doesNotPublishesInitially() async throws {
    let controller: LogsViewerController = try testedInstance()

    var result: String?
    controller
      .shareMenuPresentationPublisher()
      .sink { logs in
        result = logs
      }
      .store(in: cancellables)

    XCTAssertNil(result)
  }

  func test_shareMenuPresentationPublisher_publishesEmptyLogs_afterCallingPresentShareMenu_withoutLogsInCache()
    async throws
  {
    let controller: LogsViewerController = try testedInstance()

    var result: String?
    controller
      .shareMenuPresentationPublisher()
      .sink { logs in
        result = logs
      }
      .store(in: cancellables)

    controller.presentShareMenu()

    XCTAssertEqual(result, "Passbolt:\nN/A")
  }

  func test_shareMenuPresentationPublisher_publishesJoinedLogs_afterCallingPresentShareMenu_withLogsInCache()
    async throws
  {
    Diagnostics.shared.info = { () -> Array<String> in
      ["test", "another"]
    }

    let controller: LogsViewerController = try testedInstance()

    var result: String?
    controller
      .shareMenuPresentationPublisher()
      .sink { logs in
        result = logs
      }
      .store(in: cancellables)

    controller.refreshLogs()
    await asyncExecutionControl.executeAll()
    controller.presentShareMenu()

    XCTAssertEqual(result, "Passbolt:\ntest\nanother")
  }
}
