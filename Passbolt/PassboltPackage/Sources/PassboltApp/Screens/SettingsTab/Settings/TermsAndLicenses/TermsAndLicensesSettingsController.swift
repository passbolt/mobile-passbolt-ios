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

internal final class TermsAndLicensesSettingsController: ViewController {

  internal nonisolated let viewState: MutableViewState<ViewState>

  private let sessionConfiguration: SessionConfiguration
  private let diagnostics: OSDiagnostics
  private let linkOpener: OSLinkOpener
  private let asyncExecutor: AsyncExecutor

  internal init(
    context: Void,
    features: Features
  ) throws {
    try features.ensureScope(SettingsScope.self)
    try features.ensureScope(SessionScope.self)

    self.sessionConfiguration = try features.sessionConfiguration()
    self.diagnostics = features.instance()
    self.linkOpener = features.instance()
    self.asyncExecutor = try features.instance()
    self.viewState = .init(
      initial: .init(
        termsAndConditionsLinkAvailable: !(sessionConfiguration.termsURL?.isEmpty ?? true),
        privacyPolicyLinkAvailable: !(sessionConfiguration.privacyPolicyURL?.isEmpty ?? true)
      )
    )
  }
}

extension TermsAndLicensesSettingsController {

  internal struct ViewState: Equatable {

    internal var termsAndConditionsLinkAvailable: Bool
    internal var privacyPolicyLinkAvailable: Bool
  }
}

extension TermsAndLicensesSettingsController {

  internal final func navigateToTermsAndConditions() {
    self.asyncExecutor
      .scheduleCatchingWith(
        self.diagnostics,
        failMessage: "Navigation to terms and conditions failed!",
        behavior: .reuse
      ) { [sessionConfiguration, linkOpener] in
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

  internal final func navigateToPrivacyPolicy() {
    self.asyncExecutor
      .scheduleCatchingWith(
        self.diagnostics,
        failMessage: "Navigation to privacy policy failed!",
        behavior: .reuse
      ) { [sessionConfiguration, linkOpener] in
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

  internal final func navigateToLicenses() {
    self.asyncExecutor
      .scheduleCatchingWith(
        self.diagnostics,
        failMessage: "Navigation to licenses failed!",
        behavior: .reuse
      ) { [linkOpener] in
        try await linkOpener.openApplicationSettings()
      }
  }
}
