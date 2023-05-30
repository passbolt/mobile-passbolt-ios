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
import Resources

internal final class OTPScanningSuccessController: ViewController {

  internal nonisolated let viewState: MutableViewState<ViewState>

  private let diagnostics: OSDiagnostics
  private let asyncExecutor: AsyncExecutor
  private let navigationToScanning: NavigationToOTPScanning

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

    self.context = context
    self.features = features

    self.diagnostics = features.instance()
    self.asyncExecutor = try features.instance()
    self.navigationToScanning = try features.instance()

    self.viewState = .init(
      initial: .init()
    )
  }
}

extension OTPScanningSuccessController {

  internal struct ViewState: Equatable {

    internal var snackBarMessage: SnackBarMessage?
  }
}

extension OTPScanningSuccessController {

  internal final func createStandaloneOTP() {
    self.asyncExecutor.scheduleCatchingWith(
      self.diagnostics,
      failAction: { [viewState] (error: Error) in
        await viewState.update(\.snackBarMessage, to: .error(error))
      },
      behavior: .reuse
    ) { [context, features, navigationToScanning] in
      let features: Features = await features.branch(
        scope: ResourceEditScope.self,
        context: .create(
          .totp,
          folderID: .none,
          uri: .none
        )
      )
      let resourceEditForm: ResourceEditForm = try await features.instance()
      _ = try await resourceEditForm.update { (resouce: inout Resource) in
        resouce.meta.name = .string(context.account)
        resouce.meta.uri = .string(context.issuer)
        resouce.secret.totp.algorithm = .string(context.secret.algorithm.rawValue)
        resouce.secret.totp.digits = .integer(context.secret.digits)
        resouce.secret.totp.period = .integer(context.secret.period.rawValue)
        resouce.secret.totp.secret_key = .string(context.secret.sharedSecret)
      }

      _ = try await resourceEditForm.sendForm()
      try await navigationToScanning.revert()
    }
  }

  internal final func updateExistingResource() {
    self.asyncExecutor.scheduleCatchingWith(
      self.diagnostics,
      failAction: { [viewState] (error: Error) in
        await viewState.update(\.snackBarMessage, to: .error(error))
      },
      behavior: .reuse
    ) { [navigationToScanning] in
      #warning("[MOB-1102] TODO: to complete when adding resources with OTP and password")
      throw Unimplemented.error()
      try await navigationToScanning.revert()
    }
  }
}
