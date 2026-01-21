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

import FeatureScopes
import TestExtensions

@testable import Display
@testable import PassboltApp

// swift-format-ignore: AlwaysUseLowerCamelCase, NeverUseImplicitlyUnwrappedOptionals
final class MFAViewControllerTests: FeaturesTestCase {

  override func commonPrepare() {
    super.commonPrepare()
    patch(
      \Session.close,
      with: always(Void())
    )
  }

  func test_viewState_currentProvider_isFirstProvider() async throws {
    let tested: MFAViewController = try self.testedInstance(
      context: [.totp, .yubiKey, .duo]
    )

    XCTAssertEqual(
      SessionMFAProvider.totp,
      tested.viewState.value.currentProvider
    )
  }

  func test_init_throwsError_whenContextIsEmpty() async throws {
    XCTAssertThrowsError(
      try self.testedInstance(
        context: [] as Array<SessionMFAProvider>
      ) as MFAViewController
    )
  }

  func test_viewState_isLoading_isFalse_initially() async throws {
    let tested: MFAViewController = try self.testedInstance(
      context: [.totp]
    )

    XCTAssertFalse(tested.viewState.value.isLoading)
  }

  func test_nextProvider_cyclesProviders() async throws {
    let tested: MFAViewController = try self.testedInstance(
      context: [.totp, .yubiKey, .duo]
    )

    XCTAssertEqual(.totp, tested.viewState.value.currentProvider)

    await tested.nextProvider()
    XCTAssertEqual(.yubiKey, tested.viewState.value.currentProvider)

    await tested.nextProvider()
    XCTAssertEqual(.duo, tested.viewState.value.currentProvider)

    await tested.nextProvider()
    XCTAssertEqual(.totp, tested.viewState.value.currentProvider)
  }

  func test_nextProvider_staysOnSameProvider_whenOnlyOneProviderAvailable() async throws {
    let tested: MFAViewController = try self.testedInstance(
      context: [.totp]
    )

    await tested.nextProvider()
    XCTAssertEqual(.totp, tested.viewState.value.currentProvider)
  }

  func test_prepareTOTP_returnsViewController() async throws {
    let tested: MFAViewController = try self.testedInstance(
      context: [.totp]
    )

    let totpViewController = tested.prepareTOTP()

    XCTAssertNotNil(totpViewController)
  }

  func test_prepareDUO_returnsViewController() async throws {
    let tested: MFAViewController = try self.testedInstance(
      context: [.duo]
    )

    let duoViewController = tested.prepareDUO()

    XCTAssertNotNil(duoViewController)
  }

  func test_prepareYubiKey_returnsViewController() async throws {
    let tested: MFAViewController = try self.testedInstance(
      context: [.yubiKey]
    )

    let yubikeyViewController = tested.prepareYubiKey()

    XCTAssertNotNil(yubikeyViewController)
  }

  func test_close_closesSession() async throws {
    let sessionClosed: CriticalState<Bool> = .init(false)
    patch(
      \Session.close,
      with: { _ in
        sessionClosed.set(true)
      }
    )

    let tested: MFAViewController = try self.testedInstance(
      context: [.totp]
    )

    await tested.close()

    XCTAssertTrue(sessionClosed.get())
  }
}
