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

import Display
import FeatureScopes
import SharedUIComponents

internal enum NavigationToMFADestination: NavigationDestination {

  internal typealias TransitionContext = MFAViewController.Context
}

internal typealias NavigationToMFA = NavigationTo<NavigationToMFADestination>

extension NavigationToMFA {

  fileprivate static var live: FeatureLoader {
    replaceRoot(with: MFAView.self)
  }
}

extension Features {

  /// Navigates to the MFA authorization screen using only the providers which can
  /// be presented, or to the dedicated screen when none of them is supported.
  ///
  /// This is the only supported way of reaching MFA authorization - navigating to
  /// `NavigationToMFA` directly with an unfiltered list of providers makes
  /// `MFAViewController` initialization fail when none of them is supported.
  ///
  /// Kept in sync with the `PassboltApp` counterpart.
  @MainActor internal func navigateToMFAAuthorization(
    providers: Array<SessionMFAProvider>
  ) async throws {
    let supportedProviders: Array<SessionMFAProvider> = providers.supportedProviders
    if supportedProviders.isEmpty {
      try await self.navigateToUnsupportedMFA()
    }
    else {
      let navigationToMFA: NavigationToMFA = try self.instance()
      do {
        try await navigationToMFA.perform(context: supportedProviders)
      }
      catch {
        // `MFAViewController` initialization fails when none of the supported
        // providers can actually be presented, it displays those failures itself.
        // Fall back to the dedicated screen which offers closing the session,
        // MFA is mandatory so there is no way forward otherwise.
        error.logged(
          info: .message(
            "MFA authorization screen unavailable, using the unsupported MFA screen!"
          )
        )
        try await self.navigateToUnsupportedMFA()
      }
    }
  }

  /// ``navigateToMFAAuthorization(providers:)`` with automatically consumed errors.
  @MainActor internal func navigateToMFAAuthorizationCatching(
    providers: Array<SessionMFAProvider>,
    file: StaticString = #fileID,
    line: UInt = #line
  ) async {
    await consumingErrors(
      errorDiagnostics: "Navigation to MFA authorization failed!",
      { try await self.navigateToMFAAuthorization(providers: providers) },
      file: file,
      line: line
    )
  }

  @MainActor private func navigateToUnsupportedMFA() async throws {
    let navigationToUnsupportedMFA: NavigationToUnsupportedMFA = try self.instance()
    try await navigationToUnsupportedMFA.perform()
  }
}

extension FeaturesRegistry {

  internal mutating func useLiveNavigationToMFA() {
    self.use(
      NavigationToMFA.live,
      in: RootFeaturesScope.self
    )
  }
}
