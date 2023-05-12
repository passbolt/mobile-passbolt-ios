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

  internal typealias Context = TOTPConfiguration

  internal struct ViewState: Equatable {

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
    try features.ensureScope(SessionScope.self)
    guard !features.checkScope(ResourceEditScope.self)
    else {
      throw
        InternalInconsistency
        .error("OTPScanningSuccessController can't be used when editing a resource!")
    }

    let diagnostics: OSDiagnostics = features.instance()
    let asyncExecutor: AsyncExecutor = try features.instance()

    let navigationToScanning: NavigationToOTPScanning = try features.instance()

    let viewState: MutableViewState<ViewState> = .init(
      initial: .init()
    )

    nonisolated func createStandaloneOTP() {
      asyncExecutor.scheduleCatchingWith(
        diagnostics,
        behavior: .reuse
      ) {
        do {
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
        catch {
          await viewState
            .update(
              \.snackBarMessage,
              to: .error(error)
            )
          throw error
        }
      }
    }

    nonisolated func updateExistingResource() {
      asyncExecutor.scheduleCatchingWith(
        diagnostics,
        behavior: .reuse
      ) {
        #warning("[MOB-1102] TODO: to complete when adding resources with OTP and password")
        do {
          throw Unimplemented.error()
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
      in: SessionScope.self
    )
  }
}
