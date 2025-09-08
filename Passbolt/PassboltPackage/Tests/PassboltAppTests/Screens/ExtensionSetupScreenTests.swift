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
import FeatureScopes
import Features
import TestExtensions
import UIComponents

@testable import PassboltApp

// swift-format-ignore: AlwaysUseLowerCamelCase, NeverUseImplicitlyUnwrappedOptionals
final class ExtensionSetupScreenTests: FeaturesTestCase {

  override func commonPrepare() {

  }

  func test_whenSkippingAllowed_skipButtonShouldBeVisible() async throws {
    await withInstance(
      of: ExtensionSetupViewController.self,
      context: .init(allowSkipping: true)
    ) { feature in
      let isButtonVisible = await feature.viewState.current.showSkipButton
      XCTAssertTrue(isButtonVisible)
    }
  }

  func test_whenSkippingIsNotAllowed_skipButtonShouldNotBeVisible() async throws {
    await withInstance(
      of: ExtensionSetupViewController.self,
      context: .init(allowSkipping: false)
    ) { feature in
      let isButtonVisible = await feature.viewState.current.showSkipButton
      XCTAssertFalse(isButtonVisible)
    }
  }

  func test_openingSettings_andConfiguringExtension_shouldCompleteSetup() async throws {
    let settingsOpened = expectation(description: "Settings opened")
    let setupCompleted = expectation(description: "Setup completed")

    patch(
      \OSLinkOpener.openSystemSettings,
      with: { () async throws -> Void in
        settingsOpened.fulfill()
      }
    )

    patch(
      \AccountInitialSetup.completeSetup,
      with: { (element: AccountInitialSetup.SetupElement) -> Void in
        XCTAssertEqual(element, .autofill)
        setupCompleted.fulfill()
      }
    )

    patch(
      \ApplicationLifecycle.lifecyclePublisher,
      with: always(Just(.didBecomeActive).eraseToAnyPublisher())
    )

    patch(
      \OSExtensions.autofillExtensionEnabled,
      with: always(true)
    )

    await withInstance(
      of: ExtensionSetupViewController.self,
      context: .init(allowSkipping: false)
    ) { feature in
      await feature.setupExtension()
    }

    await fulfillment(of: [settingsOpened, setupCompleted], timeout: 1.0)
  }

  func test_openingSettings_andNotConfiguringExtension_shouldNotCompleteSetup() async throws {
    let settingsOpened = expectation(description: "Settings opened")
    settingsOpened.expectedFulfillmentCount = 1
    let setupCompleted = expectation(description: "Setup completed")
    setupCompleted.isInverted = true

    patch(
      \OSLinkOpener.openSystemSettings,
      with: { () async throws -> Void in
        settingsOpened.fulfill()
      }
    )

    patch(
      \ApplicationLifecycle.lifecyclePublisher,
      with: always(Just(.didBecomeActive).eraseToAnyPublisher())
    )

    patch(
      \OSExtensions.autofillExtensionEnabled,
      with: always(false)
    )

    await withInstance(
      of: ExtensionSetupViewController.self,
      context: .init(allowSkipping: false)
    ) { feature in
      await feature.setupExtension()
    }

    await fulfillment(of: [settingsOpened, setupCompleted], timeout: 1.0)
  }

  func test_skippingSetup_shouldCompleteSetup_andRevertNavigation() async throws {
    let setupCompleted = expectation(description: "Setup completed")
    let navigationReverted = expectation(description: "Navigation reverted")

    patch(
      \AccountInitialSetup.completeSetup,
      with: { (element: AccountInitialSetup.SetupElement) -> Void in
        XCTAssertEqual(element, .autofill)
        setupCompleted.fulfill()
      }
    )

    patch(
      \NavigationToExtensionSetup.mockRevert,
      with: { (_) -> Void in
        navigationReverted.fulfill()
      }
    )

    await withInstance(
      of: ExtensionSetupViewController.self,
      context: .init(allowSkipping: true)
    ) { feature in
      await feature.skipSetup()
    }

    await fulfillment(of: [setupCompleted, navigationReverted], timeout: 1.0)
  }
}
