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

internal struct OTPEditFormController {

  internal var viewState: MutableViewState<ViewState>

  internal var setNameField: (String) -> Void
  internal var setURIField: (String) -> Void
  internal var setSecretField: (String) -> Void
  internal var showAdvancedSettings: () -> Void
  internal var sendForm: () -> Void
}

extension OTPEditFormController: ViewController {

  internal struct ViewState: Equatable {

    internal var nameField: Validated<String>
    internal var uriField: Validated<String>
    internal var secretField: Validated<String>
    internal var snackBarMessage: SnackBarMessage?
  }

  #if DEBUG
  internal static var placeholder: Self {
    .init(
      viewState: .placeholder(),
      setNameField: unimplemented1(),
      setURIField: unimplemented1(),
      setSecretField: unimplemented1(),
      showAdvancedSettings: unimplemented0(),
      sendForm: unimplemented0()
    )
  }
  #endif
}

// MARK: - Implementation

extension OTPEditFormController {

  @MainActor fileprivate static func load(
    features: Features
  ) throws -> Self {
    try features.ensureScope(SessionScope.self)
    let featuresBranchContainer: FeaturesContainer? = features.branchIfNeeded(
      scope: OTPEditScope.self
    )
    let features: Features = featuresBranchContainer ?? features

    let editedResourceID: Resource.ID? = try? features.context(of: ResourceEditScope.self).resourceID

    let diagnostics: OSDiagnostics = features.instance()
    let asyncExecutor: AsyncExecutor = try features.instance()

    let navigationToSelf: NavigationToOTPEditForm = try features.instance()
    let navigationToAdvanced: NavigationToOTPEditAdvancedForm = try features.instance()

    let otpEditForm: OTPEditForm = try features.instance()

    let viewState: MutableViewState<ViewState> = .init(
      initial: .init(
        nameField: .valid(""),
        uriField: .valid(""),
        secretField: .valid(""),
        snackBarMessage: .none
      ),
      extendingLifetimeOf: featuresBranchContainer
    )

    asyncExecutor.schedule {
      await viewState.update { (state: inout ViewState) in
        let initialState: OTPEditForm.State = otpEditForm.state()
        state.nameField = initialState.name
        state.uriField = initialState.uri
        state.secretField = initialState.secret
      }
      for await _ in otpEditForm.updates.dropFirst() {
        let updatedState: OTPEditForm.State = otpEditForm.state()
        await viewState.update { (state: inout ViewState) in
          state.nameField = updatedState.name
          state.uriField = updatedState.uri
          state.secretField = updatedState.secret
        }
      }
    }

    nonisolated func setNameField(
      _ value: String
    ) {
      otpEditForm
        .update(
          field: \.name,
          toValidated: value
        )
    }

    nonisolated func setURIField(
      _ value: String
    ) {
      otpEditForm
        .update(
          field: \.uri,
          toValidated: value
        )
    }

    nonisolated func setSecretField(
      _ value: String
    ) {
      otpEditForm
        .update(
          field: \.secret,
          toValidated: value
        )
    }

    nonisolated func showAdvancedSettings() {
      asyncExecutor.scheduleCatchingWith(
        diagnostics,
        failMessage: "Navigation to OTP advanced settings failed!",
        behavior: .reuse
      ) {
        try await navigationToAdvanced.perform()
      }
    }

    nonisolated func sendForm() {
      asyncExecutor.scheduleCatchingWith(
        diagnostics,
        failMessage: "Sending OTP form failed!",
        behavior: .reuse
      ) {
        do {
          if let editedResourceID {
            try await otpEditForm.sendForm(.attach(to: editedResourceID))
          }
          else {
            try await otpEditForm.sendForm(.createStandalone)
          }
        }
        catch {
          await viewState
            .update(
              \.snackBarMessage,
              to: .error(error)
            )
          throw error
        }
        try await navigationToSelf.revert()
      }
    }

    return .init(
      viewState: viewState,
      setNameField: setNameField(_:),
      setURIField: setURIField(_:),
      setSecretField: setSecretField(_:),
      showAdvancedSettings: showAdvancedSettings,
      sendForm: sendForm
    )
  }
}

extension FeaturesRegistry {

  internal mutating func useLiveOTPEditFormController() {
    self.use(
      .disposable(
        OTPEditFormController.self,
        load: OTPEditFormController.load(features:)
      ),
      in: SessionScope.self
    )
  }
}
