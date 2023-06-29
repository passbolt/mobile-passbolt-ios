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

internal final class TOTPEditFormController: ViewController {

  public struct Context {

    public var editingContext: ResourceEditingContext
    public var totpPath: Resource.FieldPath
    public var success: @Sendable (Resource?) -> Void

    public init(
      editingContext: ResourceEditingContext,
      totpPath: Resource.FieldPath,
      success: @escaping @Sendable (Resource?) -> Void
    ) {
      self.editingContext = editingContext
      self.totpPath = totpPath
      self.success = success
    }
  }

  internal struct ViewState: Equatable {

    internal var nameField: Validated<String>
    internal var uriField: Validated<String>
    internal var secretField: Validated<String>
  }

  internal var viewState: ComputedViewState<ViewState>
  internal let snackBarMessage: ViewStateVariable<SnackBarMessage?>
  internal let isEditing: Bool

  private let diagnostics: OSDiagnostics
  private let asyncExecutor: AsyncExecutor
  private let navigationToSelf: NavigationToTOTPEditForm
  private let navigationToAdvanced: NavigationToTOTPEditAdvancedForm
  private let resourceEditForm: ResourceEditForm

  private let totpPath: Resource.FieldPath
  private let success: @Sendable (Resource) -> Void

  private let features: Features

  internal init(
    context: Context,
    features: Features
  ) throws {
    try features.ensureScope(SessionScope.self)
    let featuresBranchContainer: FeaturesContainer? = features.branchIfNeeded(
      scope: ResourceEditScope.self,
      context: context.editingContext
    )

    let features: Features = featuresBranchContainer ?? features
    self.features = features

    let totpPath: Resource.FieldPath = context.totpPath
    self.totpPath = totpPath
    self.success = context.success

    self.diagnostics = features.instance()
    self.asyncExecutor = try features.instance()

    self.navigationToSelf = try features.instance()
    self.navigationToAdvanced = try features.instance()

    self.resourceEditForm = try features.instance()

    self.isEditing = !context.editingContext.editedResource.isLocal

    self.viewState = .init(
      initial: .init(
        nameField: .valid(""),
        uriField: .valid(""),
        secretField: .valid("")
      ),
      from: self.resourceEditForm.state,
      transform: { (resource: Resource) in
        guard resource.contains(totpPath)
        else {
          throw
            InvalidResourceType
            .error(message: "Resource without TOTP, can't edit it.")
        }

        return .init(
          nameField:
            resource
            .validated(\.nameField)
            .map { $0.stringValue ?? "" },
          uriField:
            resource
            .validated(\.meta.uri)
            .map { $0.stringValue ?? "" },
          secretField:
            resource
            .validated(totpPath.appending(path: \.secret_key))
            .map { $0.stringValue ?? "" }
        )
      },
      failure: { [diagnostics] (error: Error) in
        diagnostics.log(error: error)
        return .init(
          nameField: .invalid(
            "",
            error: error.asTheError()
          ),
          uriField: .invalid(
            "",
            error: error.asTheError()
          ),
          secretField: .invalid(
            "",
            error: error.asTheError()
          )
        )
      }
    )

    self.snackBarMessage = .init(initial: .none)
  }
}

extension TOTPEditFormController {

  internal final func setNameField(
    _ name: String
  ) {
    self.resourceEditForm
      .update(\.nameField, to: name)
  }

  internal final func setURIField(
    _ uri: String
  ) {
    self.resourceEditForm
      .update(\.meta.uri, to: uri)
  }

  internal final func setSecretField(
    _ secret: String
  ) {
    self.resourceEditForm
      .update(
        self.totpPath.appending(path: \.secret_key),
        to: secret
      )
  }

  @MainActor internal final func showAdvancedSettings() async {
    await self.diagnostics
      .withLogCatch(
        info: .message("Navigation to OTP advanced settings failed!"),
        fallback: { [snackBarMessage] (error: Error) in
          snackBarMessage.update(\.self, to: .error(error))
        }
      ) {
        try await navigationToAdvanced.perform(
          context: .init(
            totpPath: totpPath
          )
        )
      }
  }

  @MainActor internal final func sendForm() async {
    await self.diagnostics
      .withLogCatch(
        info: .message("Sending OTP form failed!"),
        fallback: { [snackBarMessage] (error: Error) in
          snackBarMessage.update(\.self, to: .error(error))
        }
      ) {
        let resource: Resource = try await resourceEditForm.sendForm()
        try await navigationToSelf.revert()
        success(resource)
      }
  }
}
