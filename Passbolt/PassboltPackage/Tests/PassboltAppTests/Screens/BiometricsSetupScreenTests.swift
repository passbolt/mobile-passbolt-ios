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
import Combine
import FeatureScopes
import Features
import OSFeatures
import TestExtensions

@testable import PassboltApp

// swift-format-ignore: AlwaysUseLowerCamelCase, NeverUseImplicitlyUnwrappedOptionals
final class BiometricsSetupScreenTests: FeaturesTestCase {

  override func commonPrepare() async throws {
    try await super.commonPrepare()
    patch(
      \AccountInitialSetup.completeSetup,
      with: always(())
    )
    patch(
      \ApplicationLifecycle.lifecycle,
      with: always(Array<ApplicationLifecycle.Transition>([.willEnterForeground]).asAnyAsyncSequence())()
    )
  }

  func test_viewState_showsInfoScreen_whenBiometricsUnavailable() async throws {
    patch(
      \OSBiometry.availability,
      with: always(.unavailable)
    )

    await withInstance(
      of: BiometricsSetupViewController.self,
      context: ()
    ) { feature in
      let state = await feature.viewState.current

      XCTAssertEqual(state.icon, .biometrics)
      XCTAssertEqual(state.title, "biometrics.info.title")
      XCTAssertEqual(state.message, "biometrics.info.description")
      XCTAssertEqual(state.primaryButtonTitle, "biometrics.info.setup.button")
    }
  }

  func test_viewState_showsInfoScreen_whenBiometricsUnconfigured() async throws {
    patch(
      \OSBiometry.availability,
      with: always(.unconfigured)
    )

    await withInstance(
      of: BiometricsSetupViewController.self,
      context: ()
    ) { feature in
      let state = await feature.viewState.current

      XCTAssertEqual(state.icon, .biometrics)
      XCTAssertEqual(state.title, "biometrics.info.title")
      XCTAssertEqual(state.message, "biometrics.info.description")
      XCTAssertEqual(state.primaryButtonTitle, "biometrics.info.setup.button")
    }
  }

  func test_viewState_showsTouchIDSetupScreen_whenTouchIDAvailable() async throws {
    patch(
      \OSBiometry.availability,
      with: always(.touchID)
    )

    await withInstance(
      of: BiometricsSetupViewController.self,
      context: ()
    ) { feature in
      let state = await feature.viewState.current

      XCTAssertEqual(state.icon, .touchIDSetup)
      XCTAssertEqual(state.title, "biometrics.setup.title.finger")
      XCTAssertEqual(state.message, "biometrics.setup.description")
      XCTAssertEqual(state.primaryButtonTitle, "biometrics.setup.setup.button.finger")
    }
  }

  func test_viewState_showsFaceIDSetupScreen_whenFaceIDAvailable() async throws {
    patch(
      \OSBiometry.availability,
      with: always(.faceID)
    )

    await withInstance(
      of: BiometricsSetupViewController.self,
      context: ()
    ) { feature in
      let state = await feature.viewState.current

      XCTAssertEqual(state.icon, .faceIDSetup)
      XCTAssertEqual(state.title, "biometrics.setup.title.face")
      XCTAssertEqual(state.message, "biometrics.setup.description")
      XCTAssertEqual(state.primaryButtonTitle, "biometrics.setup.setup.button.face")
    }
  }

  func test_primaryButtonTapped_opensSystemSettings_whenBiometricsUnavailable() async throws {
    let settingsOpened = expectation(description: "Settings opened")

    patch(
      \OSLinkOpener.openSystemSettings,
      with: { () async throws -> Void in
        settingsOpened.fulfill()
      }
    )

    patch(
      \OSBiometry.availability,
      with: always(.unavailable)
    )

    await withInstance(
      of: BiometricsSetupViewController.self,
      context: ()
    ) { feature in
      await feature.primaryButtonTapped()
    }

    await fulfillment(of: [settingsOpened], timeout: 1.0)
  }

  func test_primaryButtonTapped_opensSystemSettings_whenBiometricsUnconfigured() async throws {
    let settingsOpened = expectation(description: "Settings opened")

    patch(
      \OSLinkOpener.openSystemSettings,
      with: { () async throws -> Void in
        settingsOpened.fulfill()
      }
    )

    patch(
      \OSBiometry.availability,
      with: always(.unconfigured)
    )

    await withInstance(
      of: BiometricsSetupViewController.self,
      context: ()
    ) { feature in
      await feature.primaryButtonTapped()
    }

    await fulfillment(of: [settingsOpened], timeout: 1.0)
  }

  func test_primaryButtonTapped_setupsBiometrics_whenTouchIDAvailable() async throws {
    let setupCompleted = expectation(description: "Setup completed")

    patch(
      \AccountPreferences.storePassphrase,
      with: { (store: Bool) async throws in
        XCTAssertTrue(store)
        setupCompleted.fulfill()
      }
    )

    patch(
      \OSBiometry.availability,
      with: always(.touchID)
    )

    patch(
      \OSExtensions.autofillExtensionEnabled,
      with: always(true)
    )

    patch(
      \NavigationToBiometricsSetup.mockRevert,
      with: { (_) in }
    )

    await withInstance(
      of: BiometricsSetupViewController.self,
      context: ()
    ) { feature in
      await feature.primaryButtonTapped()
    }

    await fulfillment(of: [setupCompleted], timeout: 1.0)
  }

  func test_primaryButtonTapped_setupsBiometrics_whenFaceIDAvailable() async throws {
    let setupCompleted = expectation(description: "Setup completed")

    patch(
      \AccountPreferences.storePassphrase,
      with: { (store: Bool) async throws in
        XCTAssertTrue(store)
        setupCompleted.fulfill()
      }
    )

    patch(
      \OSBiometry.availability,
      with: always(.faceID)
    )

    patch(
      \OSExtensions.autofillExtensionEnabled,
      with: always(true)
    )

    patch(
      \NavigationToBiometricsSetup.mockRevert,
      with: { (_) in }
    )

    await withInstance(
      of: BiometricsSetupViewController.self,
      context: ()
    ) { feature in
      await feature.primaryButtonTapped()
    }

    await fulfillment(of: [setupCompleted], timeout: 1.0)
  }

  func test_skipSetup_revertsNavigation_whenExtensionIsEnabled() async throws {
    let setupCompleted = expectation(description: "Setup completed")
    let navigationReverted = expectation(description: "Navigation reverted")

    patch(
      \AccountInitialSetup.completeSetup,
      with: { (element: AccountInitialSetup.SetupElement) -> Void in
        XCTAssertEqual(element, .biometrics)
        setupCompleted.fulfill()
      }
    )

    patch(
      \OSExtensions.autofillExtensionEnabled,
      with: always(true)
    )

    patch(
      \NavigationToBiometricsSetup.mockRevert,
      with: { (_) -> Void in
        navigationReverted.fulfill()
      }
    )

    await withInstance(
      of: BiometricsSetupViewController.self,
      context: ()
    ) { feature in
      await feature.skipSetup()
    }

    await fulfillment(of: [setupCompleted, navigationReverted], timeout: 1.0)
  }

  func test_skipSetup_navigatesToExtensionSetup_whenExtensionIsDisabled() async throws {
    let setupCompleted = expectation(description: "Setup completed")
    let navigationPerformed = expectation(description: "Navigation performed")

    patch(
      \AccountInitialSetup.completeSetup,
      with: { (element: AccountInitialSetup.SetupElement) -> Void in
        XCTAssertEqual(element, .biometrics)
        setupCompleted.fulfill()
      }
    )

    patch(
      \OSExtensions.autofillExtensionEnabled,
      with: always(false)
    )

    patch(
      \NavigationToExtensionSetup.mockPerform,
      with: { (animated: Bool, context: ExtensionSetupViewController.Context) async throws -> Void in
        XCTAssertTrue(context.allowSkipping)
        navigationPerformed.fulfill()
      }
    )

    await withInstance(
      of: BiometricsSetupViewController.self,
      context: ()
    ) { feature in
      await feature.skipSetup()
    }

    await fulfillment(of: [setupCompleted, navigationPerformed], timeout: 1.0)
  }

  func test_setupBiometrics_setsBiometricsAsEnabled() async throws {
    let setupCompleted = expectation(description: "Setup completed")

    patch(
      \AccountInitialSetup.completeSetup,
      with: { (element: AccountInitialSetup.SetupElement) -> Void in
        XCTAssertEqual(element, .biometrics)
        setupCompleted.fulfill()
      }
    )

    patch(
      \AccountPreferences.storePassphrase,
      with: { (store: Bool) async throws in
        XCTAssertTrue(store)
      }
    )

    patch(
      \OSExtensions.autofillExtensionEnabled,
      with: always(true)
    )

    patch(
      \NavigationToBiometricsSetup.mockRevert,
      with: { (_) in }
    )

    await withInstance(
      of: BiometricsSetupViewController.self,
      context: ()
    ) { feature in
      await feature.setupBiometrics()
    }

    await fulfillment(of: [setupCompleted], timeout: 1.0)
  }

  func test_setupBiometrics_revertsNavigation_whenExtensionIsEnabled() async throws {
    let navigationReverted = expectation(description: "Navigation reverted")

    patch(
      \AccountPreferences.storePassphrase,
      with: always(Void())
    )

    patch(
      \OSExtensions.autofillExtensionEnabled,
      with: always(true)
    )

    patch(
      \NavigationToBiometricsSetup.mockRevert,
      with: { (_) -> Void in
        navigationReverted.fulfill()
      }
    )

    await withInstance(
      of: BiometricsSetupViewController.self,
      context: ()
    ) { feature in
      await feature.setupBiometrics()
    }

    await fulfillment(of: [navigationReverted], timeout: 1.0)
  }

  func test_setupBiometrics_navigatesToExtensionSetup_whenExtensionIsDisabled() async throws {
    let navigationPerformed = expectation(description: "Navigation performed")

    patch(
      \AccountPreferences.storePassphrase,
      with: always(Void())
    )

    patch(
      \OSExtensions.autofillExtensionEnabled,
      with: always(false)
    )

    patch(
      \NavigationToExtensionSetup.mockPerform,
      with: { (animated: Bool, context: ExtensionSetupViewController.Context) async throws -> Void in
        XCTAssertTrue(context.allowSkipping)
        navigationPerformed.fulfill()
      }
    )

    await withInstance(
      of: BiometricsSetupViewController.self,
      context: ()
    ) { feature in
      await feature.setupBiometrics()
    }

    await fulfillment(of: [navigationPerformed], timeout: 1.0)
  }
}
