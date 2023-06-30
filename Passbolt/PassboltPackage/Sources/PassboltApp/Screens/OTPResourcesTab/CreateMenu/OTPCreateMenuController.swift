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

internal final class OTPCreateMenuController: ViewController {

  private let resourceEditPreparation: ResourceEditPreparation

  private let navigationToSelf: NavigationToOTPCreateMenu
  private let navigationToQRCodeCreateOTPView: NavigationToOTPScanning
  private let navigationToTOTPEditForm: NavigationToTOTPEditForm

  private let asyncExecutor: AsyncExecutor

  private let features: Features

  internal init(
    context: Void,
    features: Features
  ) throws {
    try features.ensureScope(SessionScope.self)
    self.features = features

    self.asyncExecutor = try features.instance()

    self.navigationToSelf = try features.instance()
    self.navigationToQRCodeCreateOTPView = try features.instance()
    self.navigationToTOTPEditForm = try features.instance()

    self.resourceEditPreparation = try features.instance()
  }
}

extension OTPCreateMenuController {

  internal final func createFromQRCode() {
    self.asyncExecutor.scheduleCatching(
      failMessage: "Navigation to create OTP from QR code failed!",
      behavior: .reuse
    ) { [navigationToSelf, navigationToQRCodeCreateOTPView] in
      try await navigationToSelf.revert()
      try await navigationToQRCodeCreateOTPView.perform()
    }
  }

  internal final func createManually() {
    self.asyncExecutor.scheduleCatching(
      failMessage: "Navigation to create OTP manually failed!",
      behavior: .reuse
    ) { [navigationToSelf, resourceEditPreparation, navigationToTOTPEditForm] in
      let editingContext: ResourceEditingContext = try await resourceEditPreparation.prepareNew(.totp, .none, .none)
      try await navigationToSelf.revert()
      try await navigationToTOTPEditForm
        .perform(
          context: .init(
            editingContext: editingContext,
            // creating resource from predefined fields,
            // there no need to search for edited totp path
            totpPath: \.secret.totp,
            success: { _ in
              #warning("TODO: success message")
            }
          )
        )
    }
  }

  internal final func dismiss() {
    self.asyncExecutor.scheduleCatching(
      failMessage: "Navigation back from create OTP menu failed!",
      behavior: .reuse
    ) { [navigationToSelf] in
      try await navigationToSelf.revert()
    }
  }
}
