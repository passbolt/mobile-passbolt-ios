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
    internal var showMessage: @MainActor (SnackBarMessage) -> Void
  }

  internal struct ViewState: Equatable {

    internal var snackBarMessage: SnackBarMessage?
  }

  internal nonisolated let viewState: ViewStateSource<ViewState>

  private let resourceEditPreparation: ResourceEditPreparation
  private let resourceEditForm: ResourceEditForm

  private let navigationToAttach: NavigationToOTPAttachSelectionList
  private let navigationToOTPResourcesList: NavigationToOTPResourcesList

  private let asyncExecutor: AsyncExecutor

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

    self.asyncExecutor = try features.instance()

    self.navigationToAttach = try features.instance()
    self.navigationToOTPResourcesList = try features.instance()

    self.resourceEditPreparation = try features.instance()
    self.resourceEditForm = try features.instance()

    self.viewState = .init(
      initial: .init()
    )
  }
}

extension OTPScanningSuccessViewController {

  internal func createStandaloneOTP() async {
    await withLogCatch(
      failInfo: "Failed to create standalone OTP",
      fallback: { [viewState] (error: Error) in
        viewState.update(\.snackBarMessage, to: .error(error))
      }
    ) {
      try await self.resourceEditForm.send()
      try await self.navigationToOTPResourcesList.revert()
      self.context.showMessage("otp.edit.otp.created.message")
    }
  }

  internal func updateExistingResource() async {
    await withLogCatch(
      failInfo: "Failed to navigate to adding OTP to a resource",
      fallback: { [viewState] (error: Error) in
        viewState.update(\.snackBarMessage, to: .error(error))
      }
    ) {
      try await self.navigationToAttach.perform(
        context: .init(
          totpSecret: self.context.totpConfiguration.secret,
          showMessage: self.context.showMessage
        )
      )
    }
  }

  internal func close() async {
    await navigationToOTPResourcesList.performCatching()
  }
}
