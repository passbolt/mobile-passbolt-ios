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
  case edit
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

  internal nonisolated let viewState: MutableViewState<ViewState>

  private let resourceController: ResourceController
  private let otpCodesController: OTPCodesController

  private let navigationToSelf: NavigationToResourceContextualMenu
  private let navigationToDeleteAlert: NavigationToResourceDeleteAlert
  private let navigationToShare: NavigationToResourceShare
  private let navigationToEdit: NavigationToResourceEdit

  private let linkOpener: OSLinkOpener
  private let pasteboard: OSPasteboard
  private let diagnostics: OSDiagnostics
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
    self.diagnostics = features.instance()
    self.asyncExecutor = try features.instance()

    self.navigationToSelf = try features.instance()
    self.navigationToDeleteAlert = try features.instance()
    self.navigationToShare = try features.instance()
    self.navigationToEdit = try features.instance()

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
    await self.diagnostics
      .withLogCatch(
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

    if resource.contains(\.secret.password) || resource.contains(\.secret) {
      accessActions.append(.copyPassword)
    }  // else NOP

    if resource.contains(\.secret.description) || resource.contains(\.meta.description) {
      accessActions.append(.copyDescription)
    }  // else NOP

    if case .some = self.revealOTP {
      accessActions.append(.revealOTP)
    }  // else NOP

    // TODO: currently can't identify otp fields other way than by name
    if resource.contains(\.secret.totp) {
      accessActions.append(.copyOTP)
    }  // else NOP

    var modifyActions: Array<ResourceContextualMenuModifyAction> = [
      .toggle(favorite: resource.favorite)
    ]

    if resource.permission.canShare {
      modifyActions.append(.share)
    }  // else NOP
    if resource.permission.canEdit {
      modifyActions.append(.edit)
      modifyActions.append(.delete)
    }  // else NOP

    self.viewState.update { (state: inout ViewState) in
      state.title = resource.meta.name.stringValue ?? ""
      state.accessActions = accessActions
      state.modifyActions = modifyActions
    }
  }

  internal func handle(
    _ action: ResourceContextualMenuAccessAction
  ) {
    switch action {
    case .openURI:
      self.openURL(field: \.meta.uri)

    case .copyURI:
      self.copy(field: \.meta.uri)

    case .copyUsername:
      self.copy(field: \.meta.username)

    case .revealOTP:
      self.revealOTPCode()

    case .copyOTP:
      self.copyOTPCode()

    case .copyPassword:
      // it can be \.secret as well!!!
      self.copy(field: \.secret.password)

    case .copyDescription:
      // it can be \.meta.description as well!!!
      self.copy(field: \.secret.description)
    }
  }

  internal func handle(
    _ action: ResourceContextualMenuModifyAction
  ) {
    switch action {
    case .toggle(favorite: _):
      self.toggleFavorite()

    case .share:
      self.share()

    case .edit:
      self.edit()

    case .delete:
      self.delete()
    }
  }

  internal func openURL(
    field path: Resource.FieldPath
  ) {
    self.asyncExecutor.scheduleCatchingWith(
      self.diagnostics,
      failMessage: "Opening resource field url failed!",
      failAction: { [showMessage] (error: Error) in
        await showMessage(.error(error))
      },
      behavior: .reuse
    ) { [resourceController, linkOpener, navigationToSelf] () async throws -> Void in
      var resource: Resource = try await resourceController.state.value

      let fieldPath: Resource.FieldPath
      // password can be legacy unstructured
      if path == \.secret.password {
        if resource.contains(\.secret.password) {
          fieldPath = \.secret.password
        }
        else if resource.contains(\.secret) {
          fieldPath = \.secret
        }
        else {
          throw
            UnknownResourceField
            .error(
              "Attempting to access not existing resource field value!",
              path: path,
              value: .null
            )
        }
      }
      // edscription can be encrypted or not
      else if path == \.secret.description {
        if resource.contains(\.secret.description) {
          fieldPath = \.secret.description
        }
        else if resource.contains(\.meta.description) {
          fieldPath = \.meta.description
        }
        else {
          throw
            UnknownResourceField
            .error(
              "Attempting to access not existing resource field value!",
              path: path,
              value: .null
            )
        }
      }
      else {
        fieldPath = path
      }

      guard let field: ResourceFieldSpecification = resource.allFields.first(where: { $0.path == fieldPath })
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
        _ = try await resourceController.fetchSecretIfNeeded()
        resource = try await resourceController.state.value
      }  // else continue

      try await linkOpener.openURL(.init(rawValue: resource[keyPath: fieldPath].stringValue ?? ""))

      try await navigationToSelf.revert()
    }
  }

  internal func copy(
    field path: Resource.FieldPath
  ) {
    self.asyncExecutor.scheduleCatchingWith(
      self.diagnostics,
      failMessage: "Copying resource field value failed!",
      failAction: { [showMessage] (error: Error) in
        await showMessage(.error(error))
      },
      behavior: .reuse
    ) { [resourceController, pasteboard, navigationToSelf, showMessage] () async throws -> Void in
      var resource: Resource = try await resourceController.state.value

      let fieldPath: Resource.FieldPath
      // password can be legacy unstructured
      if path == \.secret.password {
        if resource.contains(\.secret.password) {
          fieldPath = \.secret.password
        }
        else if resource.contains(\.secret) {
          fieldPath = \.secret
        }
        else {
          throw
            UnknownResourceField
            .error(
              "Attempting to access not existing resource field value!",
              path: path,
              value: .null
            )
        }
      }
      // edscription can be encrypted or not
      else if path == \.secret.description {
        if resource.contains(\.secret.description) {
          fieldPath = \.secret.description
        }
        else if resource.contains(\.meta.description) {
          fieldPath = \.meta.description
        }
        else {
          throw
            UnknownResourceField
            .error(
              "Attempting to access not existing resource field value!",
              path: path,
              value: .null
            )
        }
      }
      else {
        fieldPath = path
      }

      guard let field: ResourceFieldSpecification = resource.allFields.first(where: { $0.path == fieldPath })
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
        _ = try await resourceController.fetchSecretIfNeeded()
        resource = try await resourceController.state.value
      }  // else continue

      pasteboard.put(resource[keyPath: fieldPath].stringValue ?? "")

      try await navigationToSelf.revert()

      await showMessage(
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

  internal final func revealOTPCode() {
    self.asyncExecutor.scheduleCatchingWith(
      self.diagnostics,
      failMessage: "Revealing resource OTP failed!",
      failAction: { [showMessage] (error: Error) in
        await showMessage(.error(error))
      },
      behavior: .reuse
    ) { @MainActor [revealOTP, navigationToSelf] in
      guard let revealOTP
      else {
        throw
          InvalidResourceData
          .error(message: "Invalid or missing TOTP reveal action!")
      }
      try await navigationToSelf.revert(animated: true)
      revealOTP()
    }
  }

  internal final func copyOTPCode() {
    self.asyncExecutor.scheduleCatchingWith(
      self.diagnostics,
      failMessage: "Copying resource OTP failed!",
      failAction: { [showMessage] (error: Error) in
        await showMessage(.error(error))
      },
      behavior: .reuse
    ) { [features, resourceID, pasteboard, resourceController, navigationToSelf, showMessage] in
      let resourceSecret: JSON = try await resourceController.fetchSecretIfNeeded()

      // searching only for "totp" field, can't identify totp otherwise now
      guard let totpSecret: TOTPSecret = resourceSecret.totp.totpSecretValue
      else {
        throw
          InvalidResourceData
          .error(message: "Invalid or missing TOTP in secret")
      }

      let totpCodeGenerator: TOTPCodeGenerator = try await features.instance(
        context: .init(
          resourceID: resourceID,
          sharedSecret: totpSecret.sharedSecret,
          algorithm: totpSecret.algorithm,
          digits: totpSecret.digits,
          period: totpSecret.period
        )
      )

      let totp: TOTPValue = totpCodeGenerator.generate()
      pasteboard.put(totp.otp.rawValue)
      try await navigationToSelf.revert(animated: true)
      await showMessage(.info("otp.copied.message"))
    }
  }

  internal final func toggleFavorite() {
    self.asyncExecutor.scheduleCatchingWith(
      self.diagnostics,
      failMessage: "Toggling resource favorite failed!",
      failAction: { [showMessage] (error: Error) in
        await showMessage(.error(error))
      },
      behavior: .reuse
    ) { [navigationToSelf, resourceController, showMessage] in
      try await resourceController.toggleFavorite()
      let resource: Resource = try await resourceController.state.value
      try await navigationToSelf.revert()
      if resource.favorite {
        await showMessage(
          .info(
            .localized(
              key: "resource.menu.action.favorite.added",
              arguments: [
                resource.meta.name.stringValue
                  ?? DisplayableString
                  .localized("resource")
                  .string()
              ]
            )
          )
        )
      }
      else {
        await showMessage(
          .info(
            .localized(
              key: "resource.menu.action.favorite.removed",
              arguments: [
                resource.meta.name.stringValue
                  ?? DisplayableString
                  .localized("resource")
                  .string()
              ]
            )
          )
        )
      }
    }
  }

  internal final func share() {
    self.asyncExecutor.scheduleCatchingWith(
      self.diagnostics,
      failMessage: "Navigation to resource share failed!",
      failAction: { [showMessage] (error: Error) in
        await showMessage(.error(error))
      },
      behavior: .reuse
    ) { [resourceID, navigationToSelf, navigationToShare] in
      try await navigationToSelf.revert()
      try await navigationToShare.perform(context: resourceID)
    }
  }

  internal final func edit() {
    self.asyncExecutor.scheduleCatchingWith(
      self.diagnostics,
      failMessage: "Navigation to resource edit failed!",
      failAction: { [showMessage] (error: Error) in
        await showMessage(.error(error))
      },
      behavior: .reuse
    ) { [resourceID, navigationToSelf, navigationToEdit] in
      try await navigationToSelf.revert()
      try await navigationToEdit.perform(
        context: (
          editing: .edit(resourceID),
          completion: { _ in }
        )
      )
    }
  }

  internal final func delete() {
    self.asyncExecutor.scheduleCatchingWith(
      self.diagnostics,
      failMessage: "Navigation to resource delete failed!",
      failAction: { [showMessage] (error: Error) in
        await showMessage(.error(error))
      },
      behavior: .reuse
    ) { [resourceID, showMessage, navigationToSelf, navigationToDeleteAlert] in
      try await navigationToSelf.revert(animated: true)
      try await navigationToDeleteAlert.perform(
        context: (
          resourceID: resourceID,
          showMessage: showMessage
        )
      )
    }
  }

  internal final func dismiss() {
    self.asyncExecutor.scheduleCatchingWith(
      self.diagnostics,
      failMessage: "Dismissing resource contextual menu failed!",
      behavior: .reuse
    ) { [navigationToSelf] in
      try await navigationToSelf.revert()
    }
  }
}
