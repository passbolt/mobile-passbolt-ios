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
import OSFeatures
import Resources

internal final class OTPScanningSuccessViewController: ViewController {

  internal struct Context {
    internal var totpConfiguration: TOTPConfiguration
  }

  private let resourceEditPreparation: ResourceEditPreparation
  private let resourceEditForm: ResourceEditForm

  private let navigationToAttach: NavigationToOTPAttachSelectionList
  private let navigationToOTPScanning: NavigationToOTPScanning

  private let context: Context

  private let features: Features

  internal init(
    context: Context,
    features: Features
  ) throws {
    try features.ensureScope(SessionScope.self)
    try features.ensureScope(ResourceEditScope.self)

    self.features = features
    self.context = context

    self.navigationToAttach = try features.instance()

    self.resourceEditPreparation = try features.instance()
    self.resourceEditForm = try features.instance()
    self.navigationToOTPScanning = try features.instance()
  }
}

extension OTPScanningSuccessViewController {

  internal func createStandaloneOTP() async {
    await consumingErrors(
      errorDiagnostics: "Failed to create standalone OTP"
    ) {
      try await self.resourceEditForm.send()
      try await self.navigationToOTPScanning.revert()
      SnackBarMessageEvent.send("otp.edit.otp.created.message")
    }
  }

  internal func updateExistingResource() async {
    await consumingErrors(
      errorDiagnostics: "Failed to navigate to adding OTP to a resource"
    ) {
      try await self.navigationToAttach.perform(
        context: .init(
          totpSecret: self.context.totpConfiguration.secret
        )
      )
    }
  }

  internal func close() async {
    await self.navigationToOTPScanning.revertCatching()
  }
}
