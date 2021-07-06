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

@testable import PassboltExtension

// swift-format-ignore: AlwaysUseLowerCamelCase, NeverUseImplicitlyUnwrappedOptionals
final class ExtensionSetupScreenTests: TestCase {

  var linkOpener: LinkOpener!
  var extensionContext: AutofillExtensionContext!

  override func setUp() {
    super.setUp()
    linkOpener = .placeholder
    extensionContext = .placeholder
  }

  override func tearDown() {
    linkOpener = nil
    extensionContext = nil
    super.tearDown()
  }

  func test_closeConfiguration_closesExtension() {
    var result: Void!
    extensionContext.completeExtensionConfiguration = {
      result = Void()
    }
    features.use(extensionContext)
    features.use(linkOpener)

    let controller: ExtensionSetupController = testInstance()

    controller.closeConfiguration()

    XCTAssertNotNil(result)
  }

  func test_goBackToApp_opensApplication() {
    features.use(extensionContext)
    var result: Void!
    linkOpener.openApp = {
      result = Void()
      return Just(true).eraseToAnyPublisher()
    }
    features.use(linkOpener)

    let controller: ExtensionSetupController = testInstance()

    controller.goBackToApp()

    XCTAssertNotNil(result)
  }
}
