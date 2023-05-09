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
  internal var revealCode: () -> Void
  internal var editResource: () -> Void
  internal var deleteResource: () -> Void
  internal var dismiss: () -> Void
}

extension OTPContextualMenuController: ViewController {

  internal struct Context {

    internal var resourceID: Resource.ID
    internal var showMessage: @MainActor (SnackBarMessage) -> Void
  }

  internal struct ViewState: Equatable {

    internal var title: DisplayableString
    internal var editAvailable: Bool
  }

  #if DEBUG
  internal static var placeholder: Self {
    .init(
      viewState: .placeholder(),
      copyCode: unimplemented0(),
      revealCode: unimplemented0(),
      editResource: unimplemented0(),
      deleteResource: unimplemented0(),
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

    let resourceDetails: ResourceDetails = try features.instance(context: context.resourceID)
    let otpCodesController: OTPCodesController = try features.instance()

    let navigationToSelf: NavigationToOTPContextualMenu = try features.instance()
    let navigationToOTPDeleteAlert: NavigationToOTPDeleteAlert = try features.instance()
    let navigationToTOTPEdit: NavigationToTOTPEditForm = try features.instance()

    let viewState: MutableViewState<ViewState> = .init(
      initial: .init(
        title: .raw("OTP"),
        editAvailable: true
      )
    )

    // load resource name
    asyncExecutor.scheduleCatchingWith(
      diagnostics,
      failMessage: "Loading resource details failed!"
    ) {
      for await _ in resourceDetails.updates {
        let resource: Resource = try await resourceDetails.details()
        let resourceName: String = resource.value(forField: "name").stringValue ?? ""

        await viewState.update { (state: inout ViewState) in
          state.title = .raw(resourceName)
          state.editAvailable = resource.permission.canEdit
        }
      }
    }

    nonisolated func copyCode() {
      asyncExecutor.scheduleCatchingWith(
        diagnostics,
        failMessage: "Copying in OTPContextualMenu failed!",
        behavior: .reuse
      ) {
        var message: SnackBarMessage?
        do {
          try await otpCodesController.copyFor(context.resourceID)
          message = .info("otp.copied.message")
        }
        catch {
          diagnostics.log(error: error)
          message = SnackBarMessage.error(error)
        }  // continue - message will be displayed after dismiss

        try await navigationToSelf.revert(animated: true)

        if let message {
          await context.showMessage(message)
        }  // else nothing to display
      }
    }

    nonisolated func revealCode() {
      asyncExecutor.scheduleCatchingWith(
        diagnostics,
        failMessage: "Revealing in OTPContextualMenu failed!",
        behavior: .reuse
      ) {
        var message: SnackBarMessage?
        do {
          _ = try await otpCodesController.requestNextFor(context.resourceID)
        }
        catch {
          diagnostics.log(error: error)
          message = SnackBarMessage.error(error)
        }  // continue - message will be displayed after dismiss

        try await navigationToSelf.revert(animated: true)

        if let message {
          await context.showMessage(message)
        }  // else nothing to display
      }
    }

    nonisolated func editResource() {
      asyncExecutor.scheduleCatchingWith(
        diagnostics,
        failMessage: "Editing OTP from OTPContextualMenu failed!",
        behavior: .reuse
      ) {
        var message: SnackBarMessage?
        do {
          try await navigationToSelf.revert(animated: true)

          try await navigationToTOTPEdit.perform(context: context.resourceID)
        }
        catch {
          diagnostics.log(error: error)
          message = SnackBarMessage.error(error)
        }  // continue - message will be displayed after dismiss

        if let message {
          await context.showMessage(message)
        }  // else nothing to display
      }
    }

    nonisolated func deleteResource() {
      asyncExecutor.scheduleCatchingWith(
        diagnostics,
        failMessage: "Deleting OTP from OTPContextualMenu failed!",
        behavior: .reuse
      ) {
        var message: SnackBarMessage?
        do {
          try await navigationToSelf.revert(animated: true)
          try await navigationToOTPDeleteAlert.perform(
            context: (
              resourceID: context.resourceID,
              showMessage: context.showMessage
            )
          )
        }
        catch {
          diagnostics.log(error: error)
          message = SnackBarMessage.error(error)
        }  // continue - message will be displayed after dismiss

        if let message {
          await context.showMessage(message)
        }  // else nothing to display
      }
    }

    nonisolated func dismiss() {
      asyncExecutor.scheduleCatchingWith(
        diagnostics,
        failMessage: "Dismissing OTPContextualMenu failed!",
        behavior: .reuse
      ) {
        try await navigationToSelf.revert()
      }
    }

    return .init(
      viewState: viewState,
      copyCode: copyCode,
      revealCode: revealCode,
      editResource: editResource,
      deleteResource: deleteResource,
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
