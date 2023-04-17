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

internal struct OTPScanningController {

  internal var viewState: MutableViewState<ViewState>

  internal var processPayload: (String) -> Void
}

extension OTPScanningController: ViewController {

  internal struct ViewState: Equatable {

    internal var snackBarMessage: SnackBarMessage?
  }

  #if DEBUG
  internal static var placeholder: Self {
    .init(
      viewState: .placeholder(),
      processPayload: unimplemented1()
    )
  }
  #endif
}

// MARK: - Implementation

extension OTPScanningController {

  private enum ScanningState {
    case idle
    case processing
    case finished
  }

  @MainActor fileprivate static func load(
    features: Features
  ) throws -> Self {
    try features.ensureScope(SessionScope.self)
    let features: FeaturesContainer = features.branch(
      scope: OTPEditScope.self
    )

    let editedResourceID: Resource.ID? = try? features.context(of: ResourceEditScope.self).resourceID

    let diagnostics: OSDiagnostics = features.instance()
    let asyncExecutor: AsyncExecutor = try features.instance()

    let navigationToScanningSuccess: NavigationToOTPScanningSuccess = try features.instance()
    let navigationToSelf: NavigationToOTPScanning = try features.instance()

    let otpEditForm: OTPEditForm = try features.instance()

    let scanningState: CriticalState<ScanningState> = .init(.idle)

    let viewState: MutableViewState<ViewState> = .init(
      initial: .init(
        snackBarMessage: .info(
          .localized(
            key: "otp.create.code.scanning.initial.message"
          )
        )
      ),
      extendingLifetimeOf: features
    )

    nonisolated func process(
      payload: String
    ) {
      // it will ignore new payloads
      // until processing current finishes
      asyncExecutor.schedule(.reuse) {
        do {
          guard scanningState.exchange(\.self, with: .processing, when: .idle)
          else { return }  // ignore when already processing

          try otpEditForm.fillFromURI(payload)
          // when filling form succeeds navigate to success
          scanningState
            .exchange(
              \.self,
              with: .finished,
              when: .processing
            )

          if let resourceID: Resource.ID = editedResourceID {
            try await otpEditForm.sendForm(.attach(to: resourceID))
            try await navigationToSelf.revert()
          }
          else {
            try await navigationToScanningSuccess.perform()
          }
        }
        catch is Cancelled {
          scanningState
            .exchange(
              \.self,
              with: .idle,
              when: .processing
            )
        }
        catch {
          scanningState
            .exchange(
              \.self,
              with: .idle,
              when: .processing
            )
          diagnostics.log(error: error)
          await viewState
            .update(
              \.snackBarMessage,
              to: .error(error)
            )
        }
      }
    }

    return .init(
      viewState: viewState,
      processPayload: process(payload:)
    )
  }
}

extension FeaturesRegistry {

  internal mutating func useLiveOTPScanningController() {
    self.use(
      .disposable(
        OTPScanningController.self,
        load: OTPScanningController.load(features:)
      ),
      in: SessionScope.self
    )
  }
}
