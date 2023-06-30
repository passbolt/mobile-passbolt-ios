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
import SharedUIComponents

internal enum ResourceContextualMenuAccessAction: Hashable, Identifiable {

  case openURI
  case copyURI
  case copyUsername
  case revealOTP
  case copyOTP
  case copyPassword
  case copyDescription

  internal var id: Self { self }
}

internal enum ResourceContextualMenuModifyAction: Hashable, Identifiable {

  case toggle(favorite: Bool)

  case share
  case editPassword
  case editTOTP
  case delete

  internal var id: Self { self }
}

internal final class ResourceContextualMenuViewController: ViewController {

  internal struct Context {

    internal var revealOTP: (@MainActor () -> Void)?
    internal var showMessage: @MainActor (SnackBarMessage?) -> Void
  }

  internal struct ViewState: Equatable {

    internal var title: String
    internal var accessActions: Array<ResourceContextualMenuAccessAction>
    internal var modifyActions: Array<ResourceContextualMenuModifyAction>
  }

  internal nonisolated let viewState: ViewStateVariable<ViewState>

  private let resourceController: ResourceController
  private let otpCodesController: OTPCodesController

  private let navigationToSelf: NavigationToResourceContextualMenu
  private let navigationToDeleteAlert: NavigationToResourceDeleteAlert
  private let navigationToShare: NavigationToResourceShare
  private let navigationToResourceEdit: NavigationToResourceEdit
  private let navigationToTOTPEdit: NavigationToTOTPEditForm

  private let linkOpener: OSLinkOpener
  private let pasteboard: OSPasteboard

  private let asyncExecutor: AsyncExecutor

  private let revealOTP: (@MainActor () -> Void)?
  private let showMessage: @MainActor (SnackBarMessage?) -> Void
  private let resourceID: Resource.ID

  private let features: Features

  internal init(
    context: Context,
    features: Features
  ) throws {
    try features.ensureScope(ResourceDetailsScope.self)
    self.resourceID = try features.context(of: ResourceDetailsScope.self)

    self.features = features.takeOwned()

    self.revealOTP = context.revealOTP
    self.showMessage = context.showMessage

    self.linkOpener = features.instance()
    self.pasteboard = features.instance()

    self.asyncExecutor = try features.instance()

    self.navigationToSelf = try features.instance()
    self.navigationToDeleteAlert = try features.instance()
    self.navigationToShare = try features.instance()
    self.navigationToResourceEdit = try features.instance()
    self.navigationToTOTPEdit = try features.instance()

    self.resourceController = try features.instance()
    self.otpCodesController = try features.instance()

    self.viewState = .init(
      initial: .init(
        title: "",
        accessActions: .init(),
        modifyActions: .init()
      )
    )
  }
}

extension ResourceContextualMenuViewController {

  @Sendable internal func activate() async {
    await Diagnostics
      .logCatch(
        info: .message("Resource contextual menu updates broken!"),
        fallback: { _ in
          try? await self.navigationToSelf.revert()
        }
      ) {
        for try await resource in self.resourceController.state {
          self.update(resource)
        }
      }
  }

  internal func update(
    _ resource: Resource
  ) {
    var accessActions: Array<ResourceContextualMenuAccessAction> = .init()
    if resource.contains(\.meta.uri) {
      accessActions.append(.openURI)
      accessActions.append(.copyURI)
    }  // else NOP

    if resource.contains(\.meta.username) {
      accessActions.append(.copyUsername)
    }  // else NOP

    if resource.hasPassword {
      accessActions.append(.copyPassword)
    }  // else NOP

    if resource.contains(\.secret.description) || resource.contains(\.meta.description) {
      accessActions.append(.copyDescription)
    }  // else NOP

    if case .some = self.revealOTP {
      accessActions.append(.revealOTP)
    }  // else NOP

    if resource.hasTOTP {
      accessActions.append(.copyOTP)
    }  // else NOP

    var modifyActions: Array<ResourceContextualMenuModifyAction> = [
      .toggle(favorite: resource.favorite)
    ]

    if resource.permission.canShare {
      modifyActions.append(.share)
    }  // else NOP

    if resource.permission.canEdit {
      if resource.containsUndefinedFields {
        // NOP - can't do much with it
      }
      else {
        if resource.hasPassword {
          modifyActions.append(.editPassword)
        }  // else NOP

        if resource.hasTOTP {
          modifyActions.append(.editTOTP)
        }  // else NOP
      }

      modifyActions.append(.delete)
    }  // else NOP

    self.viewState.update { (state: inout ViewState) in
      state.title = resource.name
      state.accessActions = accessActions
      state.modifyActions = modifyActions
    }
  }

  internal func handle(
    _ action: ResourceContextualMenuAccessAction
  ) async {
    switch action {
    case .openURI:
      await self.openURL(field: \.meta.uri)

    case .copyURI:
      await self.copy(field: \.meta.uri)

    case .copyUsername:
      await self.copy(field: \.meta.username)

    case .revealOTP:
      await self.revealOTPCode()

    case .copyOTP:
      await self.copyOTPCode()

    case .copyPassword:
      // using \.firstPassword to find first field with password
      // semantics, actual password have different path
      await self.copy(field: \.firstPassword)

    case .copyDescription:
      // using \.description to find proper description field
      // actual description have different path
      await self.copy(field: \.description)
    }
  }

  internal func handle(
    _ action: ResourceContextualMenuModifyAction
  ) async {
    switch action {
    case .toggle(favorite: _):
      await self.toggleFavorite()

    case .share:
      await self.share()

    case .editPassword:
      await self.editPassword()

    case .editTOTP:
      await self.editTOTP()

    case .delete:
      await self.delete()
    }
  }

  internal func openURL(
    field path: Resource.FieldPath
  ) async {
    await Diagnostics
      .logCatch(
        info: .message("Opening resource field url failed!"),
        fallback: { @MainActor (error: Error) async -> Void in
          self.showMessage(.error(error))
        }
      ) { () async throws -> Void in
        var resource: Resource = try await self.resourceController.state.value

        guard let field: ResourceFieldSpecification = resource.fieldSpecification(for: path)
        else {
          throw
            UnknownResourceField
            .error(
              "Attempting to access not existing resource field value!",
              path: path,
              value: .null
            )
        }

        if field.encrypted {
          _ = try await self.resourceController.fetchSecretIfNeeded()
          resource = try await self.resourceController.state.value
        }  // else continue

        try await self.linkOpener.openURL(.init(rawValue: resource[keyPath: path].stringValue ?? ""))

        try await self.navigationToSelf.revert()
      }
  }

  internal func copy(
    field path: Resource.FieldPath
  ) async {
    await Diagnostics
      .logCatch(
        info: .message("Copying resource field value failed!"),
        fallback: { @MainActor (error: Error) async -> Void in
          self.showMessage(.error(error))
        }
      ) { () async throws -> Void in
        var resource: Resource = try await self.resourceController.state.value

        guard let field: ResourceFieldSpecification = resource.fieldSpecification(for: path)
        else {
          throw
            UnknownResourceField
            .error(
              "Attempting to access not existing resource field value!",
              path: path,
              value: .null
            )
        }

        if field.encrypted {
          _ = try await self.resourceController.fetchSecretIfNeeded()
          resource = try await self.resourceController.state.value
        }  // else continue

        self.pasteboard.put(resource[keyPath: path].stringValue ?? "")

        try await self.navigationToSelf.revert()

        self.showMessage(
          .info(
            .localized(
              key: "resource.menu.item.field.copied",
              arguments: [
                field.name.displayable.string()
              ]
            )
          )
        )
      }
  }

  internal final func revealOTPCode() async {
    await Diagnostics
      .logCatch(
        info: .message("Revealing resource OTP failed!"),
        fallback: { @MainActor (error: Error) async -> Void in
          self.showMessage(.error(error))
        }
      ) { @MainActor in
        guard let revealOTP = self.revealOTP
        else {
          throw
            InvalidResourceData
            .error(message: "Invalid or missing TOTP reveal action!")
        }
        try await self.navigationToSelf.revert(animated: true)
        revealOTP()
      }
  }

  internal final func copyOTPCode() async {
    await Diagnostics
      .logCatch(
        info: .message("Copying resource OTP failed!"),
        fallback: { @MainActor (error: Error) async -> Void in
          self.showMessage(.error(error))
        }
      ) {
        try await self.resourceController.fetchSecretIfNeeded()
        let resource: Resource = try await self.resourceController.state.value

        // searching only for the first totp field, can't identify totp otherwise now
        guard let totpSecret: TOTPSecret = resource.firstTOTPSecret
        else {
          throw
            InvalidResourceData
            .error(message: "Invalid or missing TOTP in secret")
        }

        let totpCodeGenerator: TOTPCodeGenerator = try self.features.instance(
          context: .init(
            resourceID: resourceID,
            totpSecret: totpSecret
          )
        )

        let totp: TOTPValue = totpCodeGenerator.generate()
        self.pasteboard.put(totp.otp.rawValue)
        try await self.navigationToSelf.revert(animated: true)
        self.showMessage(.info("otp.copied.message"))
      }
  }

  internal final func toggleFavorite() async {
    await Diagnostics
      .logCatch(
        info: .message("Toggling resource favorite failed!"),
        fallback: { @MainActor (error: Error) async -> Void in
          self.showMessage(.error(error))
        }
      ) {
        try await self.resourceController.toggleFavorite()
        let resource: Resource = try await self.resourceController.state.value
        try await self.navigationToSelf.revert()
        if resource.favorite {
          self.showMessage(
            .info(
              .localized(
                key: "resource.menu.action.favorite.added",
                arguments: [resource.name]
              )
            )
          )
        }
        else {
          self.showMessage(
            .info(
              .localized(
                key: "resource.menu.action.favorite.removed",
                arguments: [resource.name]
              )
            )
          )
        }
      }
  }

  internal final func share() async {
    await Diagnostics
      .logCatch(
        info: .message("Navigation to resource share failed!"),
        fallback: { @MainActor (error: Error) async -> Void in
          self.showMessage(.error(error))
        }
      ) {
        try await self.navigationToSelf.revert()
        try await self.navigationToShare.perform(context: self.resourceID)
      }
  }

  internal final func editPassword() async {
    await Diagnostics
      .logCatch(
        info: .message("Navigation to resource edit failed!"),
        fallback: { @MainActor (error: Error) async -> Void in
          self.showMessage(.error(error))
        }
      ) { [resourceID] in
        let resourceEditPreparation: ResourceEditPreparation = try features.instance()
        let editingContext: ResourceEditingContext = try await resourceEditPreparation.prepareExisting(resourceID)
        try await self.navigationToSelf.revert()
        try await self.navigationToResourceEdit.perform(
          context: .init(
            editingContext: editingContext,
            success: { _ in /* TODO: FIXME: to check, no completion? */ }
          )
        )
      }
  }

  internal final func editTOTP() async {
    await Diagnostics
      .logCatch(
        info: .message("Navigation to totp edit failed!"),
        fallback: { @MainActor (error: Error) async -> Void in
          self.showMessage(.error(error))
        }
      ) { [resourceID] in
        let resourceEditPreparation: ResourceEditPreparation = try features.instance()
        let editingContext: ResourceEditingContext = try await resourceEditPreparation.prepareExisting(resourceID)
        guard let totpPath: Resource.FieldPath = editingContext.editedResource.firstTOTPPath
        else {
          throw
            InvalidResourceType
            .error(message: "Resource without TOTP, can't edit it.")
        }
        try await self.navigationToSelf.revert()
        try await self.navigationToTOTPEdit.perform(
          context: .init(
            editingContext: editingContext,
            totpPath: totpPath,
            success: { _ in /* TODO: FIXME: to check, no completion? */ }
          )
        )
      }
  }

  internal final func delete() async {
    await Diagnostics
      .logCatch(
        info: .message("Navigation to resource delete failed!"),
        fallback: { @MainActor (error: Error) async -> Void in
          self.showMessage(.error(error))
        }
      ) {
        try await self.navigationToSelf.revert(animated: true)
        try await self.navigationToDeleteAlert.perform(
          context: (
            resourceID: self.resourceID,
            containsOTP: self.resourceController.state.value.hasTOTP,
            showMessage: self.showMessage
          )
        )
      }
  }

  internal final func dismiss() {
    self.asyncExecutor.scheduleCatching(
      failMessage: "Dismissing resource contextual menu failed!",
      behavior: .reuse
    ) { [navigationToSelf] in
      try await navigationToSelf.revert()
    }
  }
}
