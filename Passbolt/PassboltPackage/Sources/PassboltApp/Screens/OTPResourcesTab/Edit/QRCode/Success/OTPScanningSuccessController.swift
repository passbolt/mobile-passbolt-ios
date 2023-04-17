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

// MARK: - Interface

internal struct OTPScanningSuccessController {

  internal var viewState: MutableViewState<ViewState>

  internal var createStandaloneOTP: () -> Void
  internal var updateExistingResource: () -> Void
}

extension OTPScanningSuccessController: ViewController {

  internal struct ViewState: Equatable {

    internal var editingResource: Bool
    internal var snackBarMessage: SnackBarMessage?
  }

  #if DEBUG
  internal static var placeholder: Self {
    .init(
      viewState: .placeholder(),
      createStandaloneOTP: unimplemented0(),
      updateExistingResource: unimplemented0()
    )
  }
  #endif
}

// MARK: - Implementation

extension OTPScanningSuccessController {

  @MainActor fileprivate static func load(
    features: Features,
    context: Context
  ) throws -> Self {
    try features.ensureScope(OTPEditScope.self)
    let editedResourceID: Resource.ID? = try? features.context(of: ResourceEditScope.self).resourceID

    let diagnostics: OSDiagnostics = features.instance()
    let asyncExecutor: AsyncExecutor = try features.instance()
    let otpEditForm: OTPEditForm = try features.instance()

    let navigationToScanning: NavigationToOTPScanning = try features.instance()

    let viewState: MutableViewState<ViewState> = .init(
      initial: .init(
        editingResource: editedResourceID != nil
      )
    )

    nonisolated func createStandaloneOTP() {
      asyncExecutor.scheduleCatchingWith(
        diagnostics,
        behavior: .reuse
      ) {
        do {
          try await otpEditForm.sendForm(.createStandalone)
        }
        catch {
          await viewState
            .update(
              \.snackBarMessage,
              to: .error(error)
            )
          throw error
        }
        try await navigationToScanning.revert()
      }
    }

    nonisolated func updateExistingResource() {
      asyncExecutor.scheduleCatchingWith(
        diagnostics,
        behavior: .reuse
      ) {
        #warning("[MOB-1102] TODO: to complete when adding resources with OTP and password")
        do {
          try await otpEditForm.sendForm(.createStandalone)
        }
        catch {
          await viewState
            .update(
              \.snackBarMessage,
              to: .error(error)
            )
          throw error
        }
        try await navigationToScanning.revert()
      }
    }

    return .init(
      viewState: viewState,
      createStandaloneOTP: createStandaloneOTP,
      updateExistingResource: updateExistingResource
    )
  }
}

extension FeaturesRegistry {

  internal mutating func useLiveOTPScanningSuccessController() {
    self.use(
      .disposable(
        OTPScanningSuccessController.self,
        load: OTPScanningSuccessController.load(features:context:)
      ),
      in: OTPEditScope.self
    )
  }
}
