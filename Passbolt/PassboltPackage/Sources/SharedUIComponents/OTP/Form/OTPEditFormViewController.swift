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

import Commons
import Display
import FeatureScopes
import Metadata
import OSFeatures
import Resources

public final class OTPEditFormViewController: @MainActor ViewController {

  public struct Context: Sendable {

    internal var totpPath: ResourceType.FieldPath

    public init(
      totpPath: ResourceType.FieldPath
    ) {
      self.totpPath = totpPath
    }
  }

  public struct ViewState: Equatable, Sendable {

    internal var isStandaloneTOTP: Bool
    internal var isEditing: Bool
    internal var nameField: Validated<String>
    internal var uriField: Validated<String>
    internal var secretField: Validated<String>
    internal var initialValues: Dictionary<Resource.FieldPath, JSON> = [:]
  }

  public var viewState: ViewStateSource<ViewState>

  private struct LocalState: Equatable {

    fileprivate var editedFields: Set<Resource.FieldPath>
  }

  private let localState: Variable<LocalState>

  private let allFields: Set<Resource.FieldPath>

  private let navigationToOTPScanning: NavigationToOTPScanning
  private let navigationToAttach: NavigationToOTPAttachSelectionList
  private let navigationToAdvanced: NavigationToOTPEditAdvancedForm
  private let navigationToSelf: NavigationToOTPEditForm
  nonisolated private let resourceEditForm: ResourceEditForm

  // Saving a standalone TOTP from here submits the whole resource, so it goes through the permission
  // confirmation like any other creation or edit.
  private let permissionConfirmation: ResourceEditPermissionConfirmation

  /// Whether saving adds the code or replaces one the resource already carries. Captured from the editing context
  /// rather than read from the form, which stops looking local once a confirmation created the resource - a
  /// resumed creation would otherwise report the code as replaced.
  private let submissionMessage: SnackBarMessage

  nonisolated private let context: Context

  private let features: Features

  public init(
    context: Context,
    features: Features
  ) throws {
    try features.ensureScope(SessionScope.self)
    try features.ensureScope(ResourceEditScope.self)

    self.features = features.takeOwned()

    self.context = context

    self.navigationToOTPScanning = try features.instance()
    self.navigationToAttach = try features.instance()
    self.navigationToAdvanced = try features.instance()
    self.navigationToSelf = try features.instance()

    self.resourceEditForm = try features.instance()
    self.permissionConfirmation = try .init(features: self.features)

    let editingContext: ResourceEditingContext = try features.context(of: ResourceEditScope.self)
    self.submissionMessage =
      editingContext.editedResource.isLocal || !editingContext.editedResource.hasTOTP
      ? "otp.edit.otp.created.message"
      : "otp.edit.otp.replaced.message"

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
        isStandaloneTOTP: false,
        isEditing: false,
        nameField: .valid(""),
        uriField: .valid(""),
        secretField: .valid("")
      ),
      updateFrom: ComputedVariable(
        combined: self.resourceEditForm.state,
        with: self.localState
      ),
      update: {
        [context] (updateState, update: Update<(Resource, LocalState)>) async in
        do {
          let resource: Resource = try update.value.0
          let localState: LocalState = try update.value.1
          guard resource.contains(context.totpPath)
          else {
            return
          }
          updateState { (viewState: inout ViewState) in
            viewState.isEditing = !resource.isLocal
            viewState.isStandaloneTOTP = resource.type.specification.slug.isStandaloneTOTPType

            if localState.editedFields.contains(\.meta.name) {
              viewState.nameField =
                resource
                .validated(\.meta.name)
                .map { $0.stringValue ?? "" }
            }
            else {
              viewState.nameField =
                .valid(resource[keyPath: \.meta.name].stringValue ?? "")
              viewState.initialValues[\.meta.name] = resource[keyPath: \.meta.name]
            }
            if localState.editedFields.contains(\.meta.uris) {
              viewState.uriField =
                resource
                .validated(\.meta.uris)
                .map { $0.arrayValue?.first?.stringValue ?? "" }
            }
            else {
              viewState.uriField =
                .valid(resource[keyPath: \.meta.uris].arrayValue?.first?.stringValue ?? "")
              viewState.initialValues[\.meta.uris] = resource[keyPath: \.meta.uris].arrayValue?.first
            }

            if localState.editedFields.contains(context.totpPath.appending(path: \.secret_key)) {
              viewState.secretField =
                resource
                .validated(context.totpPath.appending(path: \.secret_key))
                .map { $0.stringValue ?? "" }
            }
            else {
              let secretPath: Resource.FieldPath = context.totpPath.appending(path: \.secret_key)
              viewState.secretField =
                .valid(resource[keyPath: secretPath].stringValue ?? "")
              viewState.initialValues[secretPath] = resource[keyPath: secretPath]
            }
          }
        }
        catch {
          SnackBarMessageEvent.send(.error(error))
        }
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
    self.localState.mutate { (state: inout LocalState) in
      state.editedFields.insert(\.meta.name)
    }
  }

  @Sendable nonisolated internal func setURI(
    _ uri: String
  ) {
    self.resourceEditForm
      .update(\.meta.uris, to: uri)
    self.localState.mutate { (state: inout LocalState) in
      state.editedFields.insert(\.meta.uris)
    }
  }

  @Sendable nonisolated internal func setSecret(
    _ secret: String
  ) {
    self.resourceEditForm
      .update(
        context.totpPath.appending(path: \.secret_key),
        to: secret
      )
    self.localState.mutate { (state: inout LocalState) in
      state.editedFields.insert(context.totpPath.appending(path: \.secret_key))
    }
  }

  @MainActor internal func showAdvancedSettings() async {
    await navigationToAdvanced.performCatching(
      context: .init(
        totpPath: context.totpPath
      )
    )
  }

  @MainActor internal func createOrUpdateOTP() async {
    await consumingErrors {
      do {
        let message: SnackBarMessage = self.submissionMessage

        // Validated before the confirmation is offered - reviewing recipients only to be told the form is
        // invalid would be reviewing them for nothing.
        try await resourceEditForm.validateForm()

        // Both confirmed paths end the same way as the direct submission below - the confirmation only decides
        // when the resource is saved, not what happens afterwards.
        let onApplied: ResourceEditPermissionConfirmation.OnApplied = { [weak self] (_: Resource) in
          await self?.finishSubmission(message: message)
        }
        let onInvalidMetadataKey: ResourceEditPermissionConfirmation.OnInvalidMetadataKey = {
          [weak self] (reason: MetadataPinnedKeyValidationError.Reason) in
          await self?.navigateToMetadataPinnedKeyValidation(reason: reason)
        }

        // Creating inside a shared folder, or changing the secret of a shared resource, interposes the
        // permission confirmation screen; those paths run the submission on confirm, so return early.
        if try await self.permissionConfirmation.presentCreateConfirmationIfNeeded(
          onApplied: onApplied,
          onInvalidMetadataKey: onInvalidMetadataKey
        ) {
          return
        }
        if try await self.permissionConfirmation.presentEditConfirmationIfNeeded(
          onApplied: onApplied,
          onInvalidMetadataKey: onInvalidMetadataKey
        ) {
          return
        }

        try await resourceEditForm.send()
        await self.finishSubmission(message: message)
      }
      catch let error as InvalidForm {
        self.localState.mutate { (state: inout LocalState) in
          state.editedFields = self.allFields
        }
        throw error
      }
      catch let error as MetadataPinnedKeyValidationError {
        // Same offer as on the confirmed path - a rotated key is trusted and the submission retried, rather than
        // leaving the operator with an error they cannot act on.
        await self.navigateToMetadataPinnedKeyValidation(reason: error.reason)
      }
      catch {
        throw error
      }
    }
  }

  /// Leaves the OTP form once the resource was saved. Navigation failures are logged rather than thrown: the
  /// change is already applied, and reporting a failure here would invite submitting it a second time.
  @MainActor private func finishSubmission(
    message: SnackBarMessage
  ) async {
    do {
      try await self.navigationToSelf.revert()
    }
    catch {
      error.logged()
    }
    SnackBarMessageEvent.send(message)
  }

  @MainActor private func navigateToMetadataPinnedKeyValidation(
    reason: MetadataPinnedKeyValidationError.Reason
  ) async {
    await presentMetadataPinnedKeyValidation(
      features: self.features,
      reason: reason,
      onTrustedKey: { [weak self] in await self?.createOrUpdateOTP() }
    )
  }

  internal func selectResourceToAttach() async {
    await consumingErrors(
      errorDiagnostics: "Failed to navigate to adding OTP to a resource"
    ) {
      do {
        try await resourceEditForm.validateForm()
        guard
          let totpSecret: TOTPSecret = try await resourceEditForm.state.value[keyPath: context.totpPath]
            .totpSecretValue
        else {
          throw
            InvalidResourceSecret
            .error(message: "Missing OTP secret!")
        }
        try await self.navigationToAttach.perform(
          context: .init(
            totpSecret: totpSecret
          )
        )
      }
      catch let error as InvalidForm {
        self.localState.mutate { (state: inout LocalState) in
          state.editedFields = self.allFields
        }
        throw error
      }
      catch {
        throw error
      }
    }
  }

  /// Validate OTP secret and navigate to main resource form if valid.
  internal func applyForm() async {
    await consumingErrors {
      do {
        try await resourceEditForm.validateField(\.secret.totp.secret_key)
        try await navigationToSelf.revert()
      }
      catch {
        throw
          InvalidForm
          .error(displayable: "resource.form.error.invalid")
      }
    }
  }

  /// Navigate to OTP scanning view - only if it is new standalone TOTP resource.
  internal func scanTOTP() async {
    await consumingErrors {
      let currentState = await viewState.current
      if currentState.isEditing == false && currentState.isStandaloneTOTP {
        try await navigationToSelf.revert()
      }
      else {
        try await navigationToOTPScanning.perform(
          context: .init(
            totpPath: context.totpPath
          )
        )
      }
    }
  }

  /// Discard form changes and navigate back.
  internal func discardForm() async {
    await consumingErrors {
      try await navigationToSelf.revert()
      for (field, value) in await viewState.current.initialValues {
        self.resourceEditForm.update(field, to: value)
      }
      let resource: Resource = try await self.resourceEditForm.state.value
      let editingContext: ResourceEditingContext = try features.context(of: ResourceEditScope.self)

      if resource.secret.totp.totpSecretValue.isEmpty,
        let newResourceTypeSlug: ResourceSpecification.Slug = resource.type.detachedOTPSlug,
        let newResourceType = editingContext.availableTypes.first(where: {
          $0.specification.slug == newResourceTypeSlug
        })
      {
        try self.resourceEditForm.updateType(newResourceType)
      }
    }
  }

  internal func removeTOTP() async {
    await consumingErrors {
      let editingContext: ResourceEditingContext = try features.context(of: ResourceEditScope.self)
      let currentState: Resource = try await self.resourceEditForm.state.value
      if let newResourceTypeSlug: ResourceSpecification.Slug = currentState.type.detachedOTPSlug,
        let newResourceType: ResourceType = editingContext.availableTypes.first(
          where: {
            $0.specification.slug == newResourceTypeSlug
          })
      {
        try self.resourceEditForm.updateType(newResourceType)
      }

      if let path: Resource.FieldPath = currentState.firstTOTPPath {
        self.resourceEditForm.update(
          path,
          to: .null
        )
      }
      try await navigationToSelf.revert()
    }
  }
}
