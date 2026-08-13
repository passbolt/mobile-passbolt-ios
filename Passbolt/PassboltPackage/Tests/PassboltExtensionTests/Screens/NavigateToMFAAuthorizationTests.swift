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

import TestExtensions

@testable import Display
@testable import PassboltExtension

// swift-format-ignore: AlwaysUseLowerCamelCase, NeverUseImplicitlyUnwrappedOptionals
final class NavigateToMFAAuthorizationTests: FeaturesTestCase {

  /// Providers passed to the MFA screen, `.none` when it was not presented.
  private let performedProviders: CriticalState<Array<SessionMFAProvider>?> = .init(.none)

  override func commonPrepare() async throws {
    try await super.commonPrepare()
    let performedProviders: CriticalState<Array<SessionMFAProvider>?> = self.performedProviders
    patch(
      \NavigationToMFA.mockPerform,
      with: { (_: Bool, context: Array<SessionMFAProvider>) async throws -> Void in
        performedProviders.set(context)
      }
    )
    // the unsupported MFA screen has no context, `mockExecuted` tracks it
    patch(
      \NavigationToUnsupportedMFA.mockPerform,
      with: always(self.mockExecuted())
    )
  }

  func test_navigateToMFAAuthorization_navigatesToMFA_withAllProvidersSupported() async throws {
    try await self.testedFeatures
      .navigateToMFAAuthorization(providers: [.totp, .duo])

    XCTAssertEqual(self.performedProviders.get(), [.totp, .duo])
    XCTAssertFalse(self.mockWasExecuted)
  }

  func test_navigateToMFAAuthorization_navigatesToMFA_withoutProvidersNotSupported() async throws {
    try await self.testedFeatures
      .navigateToMFAAuthorization(providers: [.unknown, .totp, .unknown, .duo])

    XCTAssertEqual(self.performedProviders.get(), [.totp, .duo])
    XCTAssertFalse(self.mockWasExecuted)
  }

  func test_navigateToMFAAuthorization_navigatesToUnsupportedMFA_withOnlyProvidersNotSupported() async throws {
    try await self.testedFeatures
      .navigateToMFAAuthorization(providers: [.unknown, .unknown])

    XCTAssertTrue(self.mockWasExecuted)
    XCTAssertNil(self.performedProviders.get())
  }

  func test_navigateToMFAAuthorization_navigatesToUnsupportedMFA_withoutProviders() async throws {
    try await self.testedFeatures
      .navigateToMFAAuthorization(providers: [])

    XCTAssertTrue(self.mockWasExecuted)
    XCTAssertNil(self.performedProviders.get())
  }

  func test_navigateToMFAAuthorization_navigatesToUnsupportedMFA_whenMFAScreenIsUnavailable() async throws {
    patch(
      \NavigationToMFA.mockPerform,
      with: { (_: Bool, _: Array<SessionMFAProvider>) async throws -> Void in
        throw MockIssue.error()
      }
    )

    try await self.testedFeatures
      .navigateToMFAAuthorization(providers: [.totp])

    XCTAssertTrue(self.mockWasExecuted)
  }

  func test_navigateToMFAAuthorization_throwsError_whenBothScreensAreUnavailable() async throws {
    patch(
      \NavigationToMFA.mockPerform,
      with: alwaysThrow(MockIssue.error())
    )
    patch(
      \NavigationToUnsupportedMFA.mockPerform,
      with: alwaysThrow(MockIssue.error())
    )

    do {
      try await self.testedFeatures
        .navigateToMFAAuthorization(providers: [.totp])
      XCTFail("Expected an error when neither screen can be presented")
    }
    catch {
      // expected, there is nothing left to fall back to
    }
  }

  func test_navigateToMFAAuthorizationCatching_navigatesToMFA_withoutProvidersNotSupported() async {
    await self.testedFeatures
      .navigateToMFAAuthorizationCatching(providers: [.unknown, .totp])

    XCTAssertEqual(self.performedProviders.get(), [.totp])
    XCTAssertFalse(self.mockWasExecuted)
  }

  func test_navigateToMFAAuthorizationCatching_navigatesToUnsupportedMFA_withOnlyProvidersNotSupported() async {
    await self.testedFeatures
      .navigateToMFAAuthorizationCatching(providers: [.unknown])

    XCTAssertTrue(self.mockWasExecuted)
    XCTAssertNil(self.performedProviders.get())
  }

  func test_navigateToMFAAuthorizationCatching_consumesError_whenNavigationFails() async {
    let navigationAttempted: CriticalState<Bool> = .init(false)
    patch(
      \NavigationToMFA.mockPerform,
      with: { (_: Bool, _: Array<SessionMFAProvider>) async throws -> Void in
        navigationAttempted.set(true)
        throw MockIssue.error()
      }
    )
    // fail the fallback as well, otherwise there is no error left to consume
    patch(
      \NavigationToUnsupportedMFA.mockPerform,
      with: alwaysThrow(MockIssue.error())
    )

    // the error is consumed, returning normally instead of
    // propagating the failure is the assertion here
    await self.testedFeatures
      .navigateToMFAAuthorizationCatching(providers: [.totp])

    XCTAssertTrue(navigationAttempted.get())
  }
}
