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

internal final class OTPEditFormViewController: ViewController {

  internal struct Context {

    internal var totpPath: ResourceType.FieldPath
    internal var showMessage: @MainActor (SnackBarMessage) -> Void

    internal init(
      totpPath: ResourceType.FieldPath,
      showMessage: @escaping @MainActor (SnackBarMessage) -> Void
    ) {
      self.totpPath = totpPath
      self.showMessage = showMessage
    }
  }

  internal struct ViewState: Equatable {

    internal var isEditing: Bool
    internal var nameField: Validated<String>
    internal var uriField: Validated<String>
    internal var secretField: Validated<String>
    internal var snackBarMessage: SnackBarMessage?
  }

  internal var viewState: ViewStateSource<ViewState>

  private struct LocalState: Equatable {

    fileprivate var editedFields: Set<Resource.FieldPath>
  }

  private let localState: Variable<LocalState>

  private let allFields: Set<Resource.FieldPath>

  private let asyncExecutor: AsyncExecutor
  private let navigationToSelf: NavigationToOTPEditForm
  private let navigationToAttach: NavigationToOTPAttachSelectionList
  private let navigationToAdvanced: NavigationToOTPEditAdvancedForm
  private let resourceEditForm: ResourceEditForm

  private let context: Context

  private let features: Features

  internal init(
    context: Context,
    features: Features
  ) throws {
    try features.ensureScope(SessionScope.self)
    try features.ensureScope(ResourceEditScope.self)

    self.features = features.takeOwned()

    self.context = context

    self.asyncExecutor = try features.instance()

    self.navigationToSelf = try features.instance()
    self.navigationToAttach = try features.instance()
    self.navigationToAdvanced = try features.instance()

    self.resourceEditForm = try features.instance()

    self.allFields = [
      \.meta.name,
      context.totpPath.appending(path: \.secret_key),
    ]

    self.localState = .init(
      initial: .init(
        editedFields: .init()
      )
    )
    self.viewState = .init(
      initial: .init(
        isEditing: false,
        nameField: .valid(""),
        uriField: .valid(""),
        secretField: .valid("")
      ),
      updateFrom: ComputedVariable(
        combining: self.resourceEditForm.state,
        and: self.localState
      ),
      transform: {
        [context] (viewState: inout ViewState, update: (resource: Resource, localState: LocalState)) async throws in
        guard update.resource.contains(context.totpPath)
        else {
          throw
            InvalidResourceType
            .error(message: "Resource without TOTP, can't edit its TOTP.")
        }
        viewState.isEditing = !update.resource.isLocal

        if update.localState.editedFields.contains(\.meta.name) {
          viewState.nameField =
            update.resource
            .validated(\.meta.name)
            .map { $0.stringValue ?? "" }
        }
        else {
          viewState.nameField =
            .valid(update.resource[keyPath: \.meta.name].stringValue ?? "")
        }
        if update.localState.editedFields.contains(\.meta.uri) {
          viewState.uriField =
            update.resource
            .validated(\.meta.uri)
            .map { $0.stringValue ?? "" }
        }
        else {
          viewState.uriField =
            .valid(update.resource[keyPath: \.meta.uri].stringValue ?? "")
        }

        if update.localState.editedFields.contains(context.totpPath.appending(path: \.secret_key)) {
          viewState.secretField =
            update.resource
            .validated(context.totpPath.appending(path: \.secret_key))
            .map { $0.stringValue ?? "" }
        }
        else {
          viewState.secretField =
            .valid(update.resource[keyPath: context.totpPath.appending(path: \.secret_key)].stringValue ?? "")
        }
      },
      fallback: { (viewState: inout ViewState, error: Error) in
        viewState.snackBarMessage = .error(error)
      }
    )
  }
}

extension OTPEditFormViewController {

  @Sendable nonisolated internal func setName(
    _ name: String
  ) {
    self.resourceEditForm
      .update(\.meta.name, to: name)
    self.localState.editedFields.insert(\.meta.name)
  }

  @Sendable nonisolated internal func setURI(
    _ uri: String
  ) {
    self.resourceEditForm
      .update(\.meta.uri, to: uri)
    self.localState.editedFields.insert(\.meta.uri)
  }

  @Sendable nonisolated internal func setSecret(
    _ secret: String
  ) {
    self.resourceEditForm
      .update(
        context.totpPath.appending(path: \.secret_key),
        to: secret
      )
    self.localState.editedFields.insert(context.totpPath.appending(path: \.secret_key))
  }

  @MainActor internal func showAdvancedSettings() async {
    await navigationToAdvanced.performCatching(
      context: .init(
        totpPath: context.totpPath
      )
    )
  }

  @MainActor internal func createOrUpdateOTP() async {
    await withLogCatch(
      fallback: { [viewState] (error: Error) in
        viewState.update(\.snackBarMessage, to: .error(error))
      }
    ) {
      do {
        try await resourceEditForm.send()
        try await navigationToSelf.revert()
        self.context.showMessage("otp.create.otp.created.message")
      }
      catch let error as InvalidForm {
        self.localState.editedFields = self.allFields
        throw error
      }
      catch {
        throw error
      }
    }
  }

  internal func selectResourceToAttach() async {
    await withLogCatch(
      failInfo: "Failed to navigate to adding OTP to a resource",
      fallback: { [viewState] (error: Error) in
        viewState.update(\.snackBarMessage, to: .error(error))
      }
    ) {
      do {
        try await resourceEditForm.validateForm()
        guard
          let totpSecret: TOTPSecret = try await resourceEditForm.state.current[keyPath: context.totpPath]
            .totpSecretValue
        else {
          throw
            InvalidResourceSecret
            .error(message: "Missing OTP secret!")
        }
        try await self.navigationToAttach.perform(
          context: .init(
            totpSecret: totpSecret,
            showMessage: self.context.showMessage
          )
        )
      }
      catch let error as InvalidForm {
        self.localState.editedFields = self.allFields
        throw error
      }
      catch {
        throw error
      }
    }
  }
}
