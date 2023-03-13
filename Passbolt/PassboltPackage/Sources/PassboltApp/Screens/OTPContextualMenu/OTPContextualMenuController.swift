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

internal struct OTPContextualMenuController {

	internal var viewState: MutableViewState<ViewState>

  internal var copyCode: () -> Void
  internal var dismiss: () -> Void
}

extension OTPContextualMenuController: ViewController {

  internal struct Context: LoadableFeatureContext {

    internal var identifier: AnyHashable { self.resourceID }

    internal var resourceID: Resource.ID
    internal var showMessage: @MainActor (SnackBarMessage?) -> Void
  }

	internal struct ViewState: Equatable {

		internal var title: DisplayableString
	}

  #if DEBUG
  internal static var placeholder: Self {
    .init(
			viewState: .placeholder(),
      copyCode: unimplemented0(),
      dismiss: unimplemented0()
    )
  }
  #endif
}

// MARK: - Implementation

extension OTPContextualMenuController {

  @MainActor fileprivate static func load(
    features: Features,
    context: Context
  ) throws -> Self {
    try features.ensureScope(SessionScope.self)

    let diagnostics: OSDiagnostics = features.instance()
    let asyncExecutor: AsyncExecutor = try features.instance()

    let time: OSTime = features.instance()
    let pasteboard: OSPasteboard = features.instance()

    let otpResources: OTPResources = try features.instance()
		let resourceDetails: ResourceDetails = try features.instance(context: context.resourceID)

    let navigationToSelf: NavigationToOTPContextualMenu = try features.instance()

		let viewState: MutableViewState<ViewState> = .init(
			initial: .init(
				title: .raw("OTP")
			)
		)

		asyncExecutor.scheduleCatchingWith(
			diagnostics,
			failMessage: "Loading resource details failed!"
		) {
			let resourceName: String = try await resourceDetails.details().name
			await viewState.update(\.title, to: .raw(resourceName))
		}

    nonisolated func copyCode() {
      asyncExecutor.schedule(.reuse) {
        var message: SnackBarMessage? = .none
        do {
          let code: OTP =
            try await otpResources
            .totpCodesFor(context.resourceID)
            .generate(time.timestamp())
            .otp
          pasteboard.put(code.rawValue)
          message = .info("otp.copied.message")
        }
        catch {
          diagnostics.log(
            error: error,
            info: .message(
              "Generating resource OTP code failed!"
            )
          )
          message = .error(error)
        }

        do {
          try await navigationToSelf.revert(animated: true)
          await context.showMessage(message)
        }
        catch {
          diagnostics.log(
            error: error,
            info: .message(
              "Navigation back from OTP contextual menu failed!"
            )
          )
        }
      }
    }

    nonisolated func dismiss() {
      asyncExecutor.scheduleCatchingWith(
        diagnostics,
        failMessage: "Navigation back from OTP contextual menu failed!",
        behavior: .reuse
      ) {
        try await navigationToSelf.revert()
      }
    }

    return .init(
			viewState: viewState,
      copyCode: copyCode,
      dismiss: dismiss
    )
  }
}

extension FeaturesRegistry {

  internal mutating func useLiveOTPCContextualMenuController() {
    self.use(
      .disposable(
        OTPContextualMenuController.self,
        load: OTPContextualMenuController.load(features:context:)
      ),
      in: SessionScope.self
    )
  }
}
