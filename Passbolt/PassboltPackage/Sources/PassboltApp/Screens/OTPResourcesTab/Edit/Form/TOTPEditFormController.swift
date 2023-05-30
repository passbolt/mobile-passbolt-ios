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

internal final class TOTPEditFormController: ViewController {

  internal var isEditing: () -> Bool
  internal var viewState: MutableViewState<ViewState>

  private let diagnostics: OSDiagnostics
  private let asyncExecutor: AsyncExecutor
  private let navigationToSelf: NavigationToTOTPEditForm
  private let navigationToAdvanced: NavigationToTOTPEditAdvancedForm
  private let resourceEditForm: ResourceEditForm

  private let features: Features

  internal init(
    context: Resource.ID?,
    features: Features
  ) throws {
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
    self.features = features

    self.isEditing = { context != nil }
    self.diagnostics = features.instance()
    self.asyncExecutor = try features.instance()

    self.navigationToSelf = try features.instance()
    self.navigationToAdvanced = try features.instance()

    self.resourceEditForm = try features.instance()

    self.viewState = .init(
      initial: .init(
        nameField: .valid(""),
        uriField: .valid(""),
        secretField: .valid(""),
        snackBarMessage: .none
      ),
      extendingLifetimeOf: featuresBranchContainer
    )

    self.asyncExecutor
      .scheduleIteration(
        over: self.resourceEditForm.state,
        catchingWith: self.diagnostics,
        failMessage: "Resource form updates broken!",
        failAction: { [viewState] (error: Error) in
          viewState.update { state in
            state.snackBarMessage = .error(error)
          }
        }
      ) { [viewState] (resource: Resource) in
        let resource: Resource = resource
        guard case .some = resource.type.specification.fieldSpecification(for: \.secret.totp)
        else {
          throw
            InvalidResourceType
            .error(message: "Resource without OTP can't edit it.")
        }
        let name: String = resource.meta.name.stringValue ?? ""
        let uri: String = resource.meta.uri.stringValue ?? ""
        let secret: String = resource.secret.totp.secret_key.stringValue ?? ""

        await viewState.update { (state: inout ViewState) in
          state.nameField = .valid(name)
          state.uriField = .valid(uri)
          state.secretField = .valid(secret)
        }
      }
  }
}

extension TOTPEditFormController {

  internal struct ViewState: Equatable {

    internal var nameField: Validated<String>
    internal var uriField: Validated<String>
    internal var secretField: Validated<String>
    internal var snackBarMessage: SnackBarMessage?
  }
}

extension TOTPEditFormController {

  internal final func setNameField(
    _ name: String
  ) {
    self.viewState.update { (state: inout ViewState) in
      state.nameField = .valid(name)
    }
    self.asyncExecutor
      .scheduleCatchingWith(
        self.diagnostics,
        failAction: { [viewState] (error: Error) in
          await viewState.update(\.snackBarMessage, to: .error(error))
        },
        behavior: .replace
      ) { [viewState, resourceEditForm] in
        try Task.checkCancellation()
        let validated: Validated<String> =
          try await resourceEditForm
          .update(
            \.meta.name,
            to: name,
            valueToJSON: { (value: String) -> JSON in
              .string(value)
            },
            jsonToValue: { (json: JSON) -> String in
              json.stringValue ?? ""
            }
          )
        try Task.checkCancellation()
        await viewState.update { (state: inout ViewState) in
          state.nameField = validated
        }
      }
  }

  internal final func setURIField(
    _ uri: String
  ) {
    self.viewState.update { (state: inout ViewState) in
      state.uriField = .valid(uri)
    }
    self.asyncExecutor
      .scheduleCatchingWith(
        self.diagnostics,
        failAction: { [viewState] (error: Error) in
          await viewState.update(\.snackBarMessage, to: .error(error))
        },
        behavior: .replace
      ) { [viewState, resourceEditForm] in
        try Task.checkCancellation()
        let validated: Validated<String> =
          try await resourceEditForm
          .update(
            \.meta.uri,
            to: uri,
            valueToJSON: { (value: String) -> JSON in
              .string(value)
            },
            jsonToValue: { (json: JSON) -> String in
              json.stringValue ?? ""
            }
          )
        try Task.checkCancellation()
        await viewState.update { (state: inout ViewState) in
          state.uriField = validated
        }
      }
  }

  internal final func setSecretField(
    _ secret: String
  ) {
    self.viewState.update { (state: inout ViewState) in
      state.secretField = .valid(secret)
    }
    self.asyncExecutor
      .scheduleCatchingWith(
        self.diagnostics,
        failAction: { [viewState] (error: Error) in
          await viewState.update(\.snackBarMessage, to: .error(error))
        },
        behavior: .replace
      ) { [viewState, resourceEditForm] in
        try Task.checkCancellation()
        let validated: Validated<String> =
          try await resourceEditForm
          .update(
            \.secret.totp.secret_key,
            to: secret,
            valueToJSON: { (value: String) -> JSON in
              .string(value)
            },
            jsonToValue: { (json: JSON) -> String in
              json.stringValue ?? ""
            }
          )
        try Task.checkCancellation()
        await viewState.update { (state: inout ViewState) in
          state.secretField = validated
        }
      }
  }

  internal final func showAdvancedSettings() {
    self.asyncExecutor.scheduleCatchingWith(
      self.diagnostics,
      failMessage: "Navigation to OTP advanced settings failed!",
      failAction: { [viewState] (error: Error) in
        await viewState.update(\.snackBarMessage, to: .error(error))
      },
      behavior: .reuse
    ) { [navigationToAdvanced] in
      try await navigationToAdvanced.perform()
    }
  }

  internal final func sendForm() {
    self.asyncExecutor.scheduleCatchingWith(
      self.diagnostics,
      failMessage: "Sending OTP form failed!",
      failAction: { [viewState] (error: Error) in
        await viewState.update(\.snackBarMessage, to: .error(error))
      },
      behavior: .reuse
    ) { [resourceEditForm, navigationToSelf] in
      _ = try await resourceEditForm.sendForm()
      try await navigationToSelf.revert()
    }
  }
}
