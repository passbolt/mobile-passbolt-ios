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

import Commons
import Display
import FeatureScopes
import Metadata
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

  // Creating a standalone TOTP is a resource creation like any other, so the same permission confirmation is
  // interposed when it lands in a shared folder.
  private let permissionConfirmation: ResourceEditPermissionConfirmation

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
    self.permissionConfirmation = try .init(features: features)
  }
}

extension OTPScanningSuccessViewController {

  internal func createStandaloneOTP() async {
    await consumingErrors(
      errorDiagnostics: "Failed to create standalone OTP"
    ) {
      // Validated before the confirmation is offered - reviewing recipients only to be told the form is invalid
      // would be reviewing them for nothing.
      try await self.resourceEditForm.validateForm()
      // Creating inside a shared folder interposes the permission confirmation screen; that path drives its own
      // create + share, so return early when it takes over.
      if try await self.permissionConfirmation.presentCreateConfirmationIfNeeded(
        onApplied: { [weak self] (_: Resource) in
          await self?.finishCreation()
        },
        onInvalidMetadataKey: { [weak self] (reason: MetadataPinnedKeyValidationError.Reason) in
          await self?.navigateToMetadataPinnedKeyValidation(reason: reason)
        }
      ) {
        return
      }

      do {
        try await self.resourceEditForm.send()
        await self.finishCreation()
      }
      catch let error as MetadataPinnedKeyValidationError {
        // Same offer as on the confirmed path - a rotated key is trusted and the creation retried, rather than
        // leaving the operator with an error they cannot act on.
        await self.navigateToMetadataPinnedKeyValidation(reason: error.reason)
      }
    }
  }

  /// Leaves the scanning flow after the resource was created. Navigation failures are logged rather than thrown:
  /// the resource already exists, and reporting a failure here would invite creating it a second time.
  private func finishCreation() async {
    do {
      try await self.navigationToOTPScanning.revert()
    }
    catch {
      error.logged()
    }
    SnackBarMessageEvent.send("otp.edit.otp.created.message")
  }

  private func navigateToMetadataPinnedKeyValidation(
    reason: MetadataPinnedKeyValidationError.Reason
  ) async {
    await presentMetadataPinnedKeyValidation(
      features: self.features,
      reason: reason,
      onTrustedKey: { [weak self] in await self?.createStandaloneOTP() }
    )
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
