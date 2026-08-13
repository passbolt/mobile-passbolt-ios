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
import Features
import NetworkOperations
import TestExtensions

@testable import Display
@testable import SharedUIComponents

// swift-format-ignore: AlwaysUseLowerCamelCase, NeverUseImplicitlyUnwrappedOptionals
final class MFAViewControllerTests: FeaturesTestCase {

  override func commonPrepare() async throws {
    try await super.commonPrepare()
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

  func test_init_throwsError_whenContextContainsOnlyProvidersNotSupported() async throws {
    XCTAssertThrowsError(
      try self.testedInstance(
        context: [.unknown, .unknown] as Array<SessionMFAProvider>
      ) as MFAViewController
    )
  }

  func test_init_ignoresProvidersNotSupported() async throws {
    let tested: MFAViewController = try self.testedInstance(
      context: [.unknown, .totp]
    )

    XCTAssertEqual(
      SessionMFAProvider.totp,
      tested.viewState.value.currentProvider
    )
    XCTAssertNotNil(tested.totpController)
    XCTAssertNil(tested.duoController)
    XCTAssertNil(tested.yubiKeyController)
  }

  func test_nextProvider_skipsProvidersNotSupported() async throws {
    let tested: MFAViewController = try self.testedInstance(
      context: [.totp, .unknown, .duo]
    )

    await tested.nextProvider()

    XCTAssertEqual(
      SessionMFAProvider.duo,
      tested.viewState.value.currentProvider
    )
  }

  func test_nextProvider_wrapsAround_whenOnlyOneProviderIsSupported() async throws {
    let tested: MFAViewController = try self.testedInstance(
      context: [.totp, .unknown]
    )

    await tested.nextProvider()

    XCTAssertEqual(
      SessionMFAProvider.totp,
      tested.viewState.value.currentProvider
    )
  }

  func test_hasMultipleProviders_isTrue_withMoreThanOneProviderSupported() async throws {
    let tested: MFAViewController = try self.testedInstance(
      context: [.totp, .duo]
    )

    XCTAssertTrue(tested.hasMultipleProviders)
  }

  func test_hasMultipleProviders_isFalse_whenOnlyOneProviderIsSupported() async throws {
    let tested: MFAViewController = try self.testedInstance(
      context: [.totp, .unknown]
    )

    XCTAssertFalse(tested.hasMultipleProviders)
  }

  func test_init_throwsError_whenNoProviderControllerCanBeLoaded() async throws {
    self.failAllControllersLoading()

    XCTAssertThrowsError(
      try self.testedInstance(
        context: [.totp, .duo] as Array<SessionMFAProvider>
      ) as MFAViewController
    )
  }

  func test_init_ignoresProvidersWithControllerNotLoaded() async throws {
    self.failDUOControllerLoading()

    let tested: MFAViewController = try self.testedInstance(
      context: [.totp, .duo]
    )

    XCTAssertNotNil(tested.totpController)
    XCTAssertNil(tested.duoController)
    XCTAssertFalse(tested.hasMultipleProviders)
  }

  func test_init_usesFirstProviderWithControllerLoaded() async throws {
    self.failDUOControllerLoading()

    let tested: MFAViewController = try self.testedInstance(
      context: [.duo, .totp]
    )

    XCTAssertEqual(
      SessionMFAProvider.totp,
      tested.viewState.value.currentProvider
    )
  }

  func test_nextProvider_skipsProvidersWithControllerNotLoaded() async throws {
    self.failDUOControllerLoading()

    let tested: MFAViewController = try self.testedInstance(
      context: [.totp, .duo, .yubiKey]
    )

    await tested.nextProvider()

    XCTAssertEqual(
      SessionMFAProvider.yubiKey,
      tested.viewState.value.currentProvider
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

    let totpViewController = tested.totpController

    XCTAssertNotNil(totpViewController)
  }

  func test_prepareDUO_returnsViewController() async throws {
    let tested: MFAViewController = try self.testedInstance(
      context: [.duo]
    )

    let duoViewController = tested.duoController

    XCTAssertNotNil(duoViewController)
  }

  func test_prepareYubiKey_returnsViewController() async throws {
    let tested: MFAViewController = try self.testedInstance(
      context: [.yubiKey]
    )

    let yubikeyViewController = tested.yubiKeyController

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

extension MFAViewControllerTests {

  /// Makes loading of the DUO provider controller fail, other providers are unaffected.
  private func failDUOControllerLoading() {
    register(
      { (registry: inout FeaturesRegistry) -> Void in
        registry.use(
          FeatureLoader.disposable(
            DUOAuthorizationPromptNetworkOperation.self,
            load: { (_: Features) throws -> DUOAuthorizationPromptNetworkOperation in
              throw MockIssue.error()
            }
          )
        )
      },
      for: DUOAuthorizationPromptNetworkOperation.self
    )
  }

  /// Makes loading of every provider controller fail, all of them require a session.
  private func failAllControllersLoading() {
    register(
      { (registry: inout FeaturesRegistry) -> Void in
        registry.use(
          FeatureLoader.disposable(
            Session.self,
            load: { (_: Features) throws -> Session in
              throw MockIssue.error()
            }
          )
        )
      },
      for: Session.self
    )
  }
}
