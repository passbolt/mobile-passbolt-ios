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

internal struct OTPCreateMenuController {

  @Stateless internal var viewState

  internal var createFromQRCode: () -> Void
  internal var createManually: () -> Void
  internal var dismiss: () -> Void
}

extension OTPCreateMenuController: ViewController {

  #if DEBUG
  internal static var placeholder: Self {
    .init(
      createFromQRCode: unimplemented0(),
      createManually: unimplemented0(),
      dismiss: unimplemented0()
    )
  }
  #endif
}

// MARK: - Implementation

extension OTPCreateMenuController {

  @MainActor fileprivate static func load(
    features: Features
  ) throws -> Self {
    try features.ensureScope(SessionScope.self)

    let diagnostics: OSDiagnostics = features.instance()
    let asyncExecutor: AsyncExecutor = try features.instance()

    let navigationToSelf: NavigationToOTPCreateMenu = try features.instance()
    let navigationToQRCodeCreateOTPView: NavigationToOTPScanning = try features.instance()

    nonisolated func createFromQRCode() {
      asyncExecutor.scheduleCatchingWith(
        diagnostics,
        failMessage: "Navigation to create OTP from QR code failed!",
        behavior: .reuse
      ) {
        try await navigationToSelf.revert()
        try await navigationToQRCodeCreateOTPView.perform(context: .init())
      }
    }
    nonisolated func createManually() {
      asyncExecutor.scheduleCatchingWith(
        diagnostics,
        failMessage: "Navigation to create OTP manually failed!",
        behavior: .reuse
      ) {
        try await navigationToSelf.revert()
      }
    }

    nonisolated func dismiss() {
      asyncExecutor.scheduleCatchingWith(
        diagnostics,
        failMessage: "Navigation back from create OTP menu failed!",
        behavior: .reuse
      ) {
        try await navigationToSelf.revert()
      }
    }

    return .init(
      createFromQRCode: createFromQRCode,
      createManually: createManually,
      dismiss: dismiss
    )
  }
}

extension FeaturesRegistry {

  internal mutating func useLiveOTPCreateMenuController() {
    self.use(
      .disposable(
        OTPCreateMenuController.self,
        load: OTPCreateMenuController.load(features:)
      ),
      in: SessionScope.self
    )
  }
}
