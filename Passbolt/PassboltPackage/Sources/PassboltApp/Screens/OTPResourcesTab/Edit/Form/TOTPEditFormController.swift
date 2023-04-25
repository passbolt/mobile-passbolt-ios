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

internal struct TOTPEditFormController {

  internal var isEditing: () -> Bool
  internal var viewState: MutableViewState<ViewState>

  internal var setNameField: @MainActor (String) -> Void
  internal var setURIField: @MainActor (String) -> Void
  internal var setSecretField: @MainActor (String) -> Void
  internal var showAdvancedSettings: @MainActor () -> Void
  internal var sendForm: @MainActor () -> Void
}

extension TOTPEditFormController: ViewController {

  internal typealias Context = Resource.ID?

  internal struct ViewState: Equatable {

    internal var nameField: Validated<String>
    internal var uriField: Validated<String>
    internal var secretField: Validated<String>
    internal var snackBarMessage: SnackBarMessage?
  }

  #if DEBUG
  internal static var placeholder: Self {
    .init(
      isEditing: unimplemented0(),
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

extension TOTPEditFormController {

  @MainActor fileprivate static func load(
    features: Features,
    context: Context
  ) throws -> Self {
    try features.ensureScope(SessionScope.self)
    let featuresBranchContainer: FeaturesContainer? = features.branchIfNeeded(
      scope: ResourceEditScope.self,
      context: {
        if let context {
          return .edit(context)
        }
        else {
          return .create(.totp, folderID: .none, uri: .none)
        }
      }()
    )

    let features: Features = featuresBranchContainer ?? features

    let diagnostics: OSDiagnostics = features.instance()
    let asyncExecutor: AsyncExecutor = try features.instance()

    let navigationToSelf: NavigationToTOTPEditForm = try features.instance()
    let navigationToAdvanced: NavigationToTOTPEditAdvancedForm = try features.instance()

    let resourceEditForm: ResourceEditForm = try features.instance()

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
      do {
        let resource: Resource = try await resourceEditForm.state.value
        let name: String = resource.value(forField: "name").stringValue ?? ""
        let uri: String = resource.value(forField: "uri").stringValue ?? ""
        let secret: String = try resource.value(forTOTP: \.sharedSecret, inField: "totp")

        await viewState.update { (state: inout ViewState) in
          state.nameField = .valid(name)
          state.uriField = .valid(uri)
          state.secretField = .valid(secret)
        }
      }
      catch {
        diagnostics.log(error: error)
        await viewState.update { state in
          state.snackBarMessage = .error(error)
        }
      }
    }

    @MainActor func setNameField(
      _ name: String
    ) {
      viewState.update { (state: inout ViewState) in
        state.nameField = .valid(name)
      }
      asyncExecutor
        .scheduleCatchingWith(diagnostics, behavior: .replace) {
          try Task.checkCancellation()
          let validated = try await resourceEditForm.update(field: "name", to: .string(name))
          await viewState.update { (state: inout ViewState) in
            state.nameField = validated.map { $0.stringValue ?? "" }
          }
        }
    }

    @MainActor func setURIField(
      _ uri: String
    ) {
      viewState.update { (state: inout ViewState) in
        state.uriField = .valid(uri)
      }
      asyncExecutor
        .scheduleCatchingWith(diagnostics, behavior: .replace) {
          try Task.checkCancellation()
          let validated = try await resourceEditForm.update(field: "uri", to: .string(uri))
          await viewState.update { (state: inout ViewState) in
            state.uriField = validated.map { $0.stringValue ?? "" }
          }
        }
    }

    @MainActor func setSecretField(
      _ secret: String
    ) {
      viewState.update { (state: inout ViewState) in
        state.secretField = .valid(secret)
      }
      asyncExecutor
        .scheduleCatchingWith(diagnostics, behavior: .replace) {
          try Task.checkCancellation()
          let updatable = try await resourceEditForm.updatableTOTPField(ResourceField.valuePath(forName: "totp"))
          let validated = try await updatable.update(\.sharedSecret, to: secret)
          await viewState.update { (state: inout ViewState) in
            state.secretField = validated
          }
        }
    }

    @MainActor func showAdvancedSettings() {
      asyncExecutor.scheduleCatchingWith(
        diagnostics,
        failMessage: "Navigation to OTP advanced settings failed!",
        behavior: .reuse
      ) {
        try await navigationToAdvanced.perform()
      }
    }

    @MainActor func sendForm() {
      asyncExecutor.scheduleCatchingWith(
        diagnostics,
        failMessage: "Sending OTP form failed!",
        behavior: .reuse
      ) {
        do {
          _ = try await resourceEditForm.sendForm()
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
      isEditing: { context != nil },
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

  internal mutating func useLiveTOTPEditFormController() {
    self.use(
      .disposable(
        TOTPEditFormController.self,
        load: TOTPEditFormController.load(features:context:)
      ),
      in: SessionScope.self
    )
  }
}
