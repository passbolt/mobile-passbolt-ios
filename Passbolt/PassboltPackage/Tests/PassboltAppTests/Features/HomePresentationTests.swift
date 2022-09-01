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
import Features
import SessionData
import TestExtensions
import XCTest

@testable import PassboltApp

// swift-format-ignore: AlwaysUseLowerCamelCase, NeverUseImplicitlyUnwrappedOptionals
final class HomePresentationTests: TestCase {

  func test_currentPresentationModePublisher_publishesDefault_initially() async throws {
    await features.patch(
      \Session.currentAccount,
      with: always(Account.valid)
    )
    await features.patch(
      \AccountPreferences.defaultHomePresentation,
      context: Account.valid,
      with: .variable(initial: HomePresentationMode.ownedResourcesList)
    )
    await features.patch(
      \SessionConfiguration.configuration,
      with: always(FeatureFlags.Folders.disabled)
    )

    let feature: HomePresentation = try await testedInstance()

    var result: HomePresentationMode?
    await feature
      .currentPresentationModePublisher()
      .sink { mode in
        result = mode
      }
      .store(in: cancellables)

    XCTAssertEqual(result, .ownedResourcesList)
  }
}
