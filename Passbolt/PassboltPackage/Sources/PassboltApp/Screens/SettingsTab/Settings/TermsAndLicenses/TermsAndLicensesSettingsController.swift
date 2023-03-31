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
import OSFeatures

// MARK: - Interface

internal struct TermsAndLicensesSettingsController {

  internal var viewState: MutableViewState<ViewState>

  internal var navigateToTermsAndConditions: () -> Void
  internal var navigateToPrivacyPolicy: () -> Void
  internal var navigateToLicenses: () -> Void
}

extension TermsAndLicensesSettingsController: ViewController {

  internal struct ViewState: Equatable {

    internal var termsAndConditionsLinkAvailable: Bool
    internal var privacyPolicyLinkAvailable: Bool
  }

  #if DEBUG
  internal static var placeholder: Self {
    .init(
      viewState: .placeholder(),
      navigateToTermsAndConditions: unimplemented0(),
      navigateToPrivacyPolicy: unimplemented0(),
      navigateToLicenses: unimplemented0()
    )
  }
  #endif
}

// MARK: - Implementation

extension TermsAndLicensesSettingsController {

  @MainActor fileprivate static func load(
    features: Features
  ) throws -> Self {
    try features.ensureScope(SettingsScope.self)
    try features.ensureScope(SessionScope.self)
    let sessionConfiguration: SessionConfiguration = try features.sessionConfiguration()

    let diagnostics: OSDiagnostics = features.instance()
    let linkOpener: OSLinkOpener = features.instance()

    let asyncExecutor: AsyncExecutor = try features.instance()

    let viewState: MutableViewState<ViewState> = .init(
      initial: .init(
				termsAndConditionsLinkAvailable: !(sessionConfiguration.termsURL?.isEmpty ?? true),
        privacyPolicyLinkAvailable: (sessionConfiguration.privacyPolicyURL?.isEmpty ?? true)
      )
    )

    nonisolated func navigateToTermsAndConditions() {
      asyncExecutor
        .scheduleCatchingWith(
          diagnostics,
          failMessage: "Navigation to terms and conditions failed!",
          behavior: .reuse
        ) {
          guard
            let url: URLString = sessionConfiguration.termsURL,
            !url.isEmpty
          else {
            throw
            InternalInconsistency
              .error("Missing terms and conditions URL")
          }
          try await linkOpener.openURL(url)
      }
    }

    nonisolated func navigateToPrivacyPolicy() {
      asyncExecutor
        .scheduleCatchingWith(
          diagnostics,
          failMessage: "Navigation to privacy policy failed!",
          behavior: .reuse
        ) {
          guard
            let url: URLString = sessionConfiguration.privacyPolicyURL,
            !url.isEmpty
          else {
            throw
            InternalInconsistency
              .error("Missing privacy policy URL")
          }
          try await linkOpener.openURL(url)
      }
    }

    nonisolated func navigateToLicenses() {
      asyncExecutor
        .scheduleCatchingWith(
          diagnostics,
          failMessage: "Navigation to licenses failed!",
          behavior: .reuse
        ) {
          try await linkOpener.openApplicationSettings()
        }
    }

    return .init(
      viewState: viewState,
      navigateToTermsAndConditions: navigateToTermsAndConditions,
      navigateToPrivacyPolicy: navigateToPrivacyPolicy,
      navigateToLicenses: navigateToLicenses
    )
  }
}

extension FeaturesRegistry {

  internal mutating func useLiveTermsAndLicensesSettingsController() {
    self.use(
      .disposable(
        TermsAndLicensesSettingsController.self,
        load: TermsAndLicensesSettingsController.load(features:)
      ),
      in: SettingsScope.self
    )
  }
}
