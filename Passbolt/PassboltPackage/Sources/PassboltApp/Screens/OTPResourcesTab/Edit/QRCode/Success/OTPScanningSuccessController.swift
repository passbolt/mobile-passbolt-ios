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

internal final class OTPScanningSuccessController: ViewController {

  internal struct ViewState: Equatable {

    internal var snackBarMessage: SnackBarMessage?
  }

  internal nonisolated let viewState: ViewStateVariable<ViewState>

  private let resourceEditPreparation: ResourceEditPreparation

  private let navigationToScanning: NavigationToOTPScanning

  private let diagnostics: OSDiagnostics
  private let asyncExecutor: AsyncExecutor

  private let context: TOTPConfiguration

  private let features: Features

  internal init(
    context: TOTPConfiguration,
    features: Features
  ) throws {
    try features.ensureScope(SessionScope.self)
    guard !features.checkScope(ResourceEditScope.self)
    else {
      throw
        InternalInconsistency
        .error("OTPScanningSuccessController can't be used when editing a resource!")
    }

    self.features = features
    self.context = context

    self.diagnostics = features.instance()
    self.asyncExecutor = try features.instance()

    self.navigationToScanning = try features.instance()

    self.resourceEditPreparation = try features.instance()

    self.viewState = .init(
      initial: .init()
    )
  }
}

extension OTPScanningSuccessController {

  internal func createStandaloneOTP() async {
    await self.diagnostics.withLogCatch(
      info: .message("Failed to create standalone OTP"),
      fallback: { [viewState] (error: Error) in
        viewState.update(\.snackBarMessage, to: .error(error))
      }
    ) {
      let editingContext: ResourceEditingContext = try await resourceEditPreparation.prepareNew(.totp, .none, .none)
      let features: Features = self.features.branch(
        scope: ResourceEditScope.self,
        context: editingContext
      )
      let resourceEditForm: ResourceEditForm = try features.instance()
      resourceEditForm.update(\.nameField, to: context.account)
      resourceEditForm.update(\.meta.uri, to: context.issuer)
      resourceEditForm.update(\.secret.totp, to: context.secret)

      _ = try await resourceEditForm.sendForm()
      try await navigationToScanning.revert()
    }
  }

  internal func updateExistingResource() async {
    await self.diagnostics.withLogCatch(
      info: .message("Failed to navigate to adding OTP to a resource"),
      fallback: { [viewState] (error: Error) in
        viewState.update(\.snackBarMessage, to: .error(error))
      }
    ) {
      #warning("[MOB-1102] TODO: to complete when adding resources with OTP and password")
      //      throw Unimplemented.error()
      //      try await navigationToScanning.revert()

      // TODO: FIXME!!! temp test
      let editingContext: ResourceEditingContext = try await resourceEditPreparation.prepareExisting(
        .init(uuidString: "77ca1bad-7a70-49c6-80d2-1d584b04a384")!
      )
      let features: Features = self.features.branch(
        scope: ResourceEditScope.self,
        context: editingContext
      )
      let resourceEditForm: ResourceEditForm = try features.instance()
      try resourceEditForm.updateType(
        editingContext.availableTypes.first(where: { $0.specification.slug == .passwordWithTOTP })!
      )
      resourceEditForm.update(\.secret.totp, to: context.secret)

      _ = try await resourceEditForm.sendForm()
      try await navigationToScanning.revert()
    }
  }
}
