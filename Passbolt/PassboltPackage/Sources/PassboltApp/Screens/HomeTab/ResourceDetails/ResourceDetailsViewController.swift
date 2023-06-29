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
import Users

internal final class ResourceDetailsViewController: ViewController {

  internal struct ViewState: Equatable {

    internal var name: String
    internal var favorite: Bool
    internal var containsUndefinedFields: Bool
    internal var fields: Array<ResourceDetailsFieldViewModel>
    internal var location: Array<String>
    internal var tags: Array<String>
    internal var permissions: Array<OverlappingAvatarStackView.Item>

    internal var snackbarMessage: SnackBarMessage?
  }

  internal nonisolated let viewState: ViewStateVariable<ViewState>

  private var revealedFields: Set<Resource.FieldPath>

  private let resourceController: ResourceController
  private let otpCodesController: OTPCodesController
  private let users: Users

  private let navigationToSelf: NavigationToResourceDetails
  private let navigationToResourceContextualMenu: NavigationToResourceContextualMenu
  private let navigationToResourceLocationDetails: NavigationToResourceLocationDetails
  private let navigationToResourceTagsDetails: NavigationToResourceTagsDetails
  private let navigationToResourcePermissionsDetails: NavigationToResourcePermissionsDetails
  private let pasteboard: OSPasteboard

  private let diagnostics: OSDiagnostics
  private let asyncExecutor: AsyncExecutor

  private let resourceID: Resource.ID
  private let passwordPreviewEnabled: Bool

  private let features: Features

  internal init(
    context: Resource.ID,
    features: Features
  ) throws {
    let features: Features = features.branch(
      scope: ResourceDetailsScope.self,
      context: context
    )
    self.passwordPreviewEnabled =
      try features
      .sessionConfiguration()
      .passwordPreviewEnabled
    self.resourceID = context

    self.features = features

    self.diagnostics = features.instance()
    self.asyncExecutor = try features.instance()

    self.pasteboard = features.instance()

    self.navigationToSelf = try features.instance()
    self.navigationToResourceContextualMenu = try features.instance()
    self.navigationToResourceLocationDetails = try features.instance()
    self.navigationToResourceTagsDetails = try features.instance()
    self.navigationToResourcePermissionsDetails = try features.instance()

    self.resourceController = try features.instance()
    self.otpCodesController = try features.instance()
    self.users = try features.instance()

    self.revealedFields = .init()

    self.viewState = .init(
      initial: .init(
        name: .init(),
        favorite: false,
        containsUndefinedFields: false,
        fields: .init(),
        location: .init(),
        tags: .init(),
        permissions: .init(),
        snackbarMessage: .none
      )
    )
  }
}

extension ResourceDetailsViewController {

  @Sendable internal func activate() async {
    await self.diagnostics
      .withLogCatch(
        info: .message("Resource details updates broken!"),
        fallback: { _ in
          try? await self.navigationToSelf.revert()
        }
      ) {
        for try await resource in self.resourceController.state {
          self.update(resource)
        }
      }
  }

  @MainActor private func update(
    _ resource: Resource
  ) {
    @Sendable func avatarImageFetch(
      for userID: User.ID
    ) -> @Sendable () async -> Data? {
      { [users] () async -> Data? in
        try? await users.userAvatarImage(userID)
      }
    }

    if !resource.secretAvailable {
      self.revealedFields.removeAll(keepingCapacity: true)
    }  // else NOP

    self.viewState.update { (state: inout ViewState) -> Void in
      state.name = resource.name
      state.favorite = resource.favorite
      state.containsUndefinedFields = resource.containsUndefinedFields
      state.location = resource.path.map(\.name)
      state.tags = resource.tags.map(\.slug.rawValue)
      state.permissions = resource.permissions.map { (permission: ResourcePermission) in
        switch permission {
        case .user(let id, _, _):
          return .user(
            id,
            avatarImage: avatarImageFetch(for: id)
          )

        case .userGroup(let id, _, _):
          return .userGroup(id)

        }
      }

      state.updateFields(
        for: resource,
        using: self.features,
        revealedFields: self.revealedFields,
        passwordPreviewEnabled: self.passwordPreviewEnabled
      )
    }
  }

  internal nonisolated func showMenu() async {
    await self.diagnostics
      .withLogCatch(
        info: .message("Failed to present resource menu!"),
        fallback: { @MainActor (error: Error) async -> Void in
          self.viewState.update(\.snackbarMessage, to: .error(error))
        }
      ) {
        try await self.navigationToResourceContextualMenu
          .perform(
            context: .init(
              showMessage: { [viewState] (message: SnackBarMessage?) in
                viewState.update(\.snackbarMessage, to: message)
              }
            )
          )
      }
  }

  internal nonisolated func showLocationDetails() async {
    await self.diagnostics
      .withLogCatch(
        info: .message("Failed to present resource location details!"),
        fallback: { @MainActor (error: Error) async -> Void in
          self.viewState.update(\.snackbarMessage, to: .error(error))
        }
      ) {
        try await self.navigationToResourceLocationDetails.perform()
      }
  }

  internal nonisolated func showTagsDetails() async {
    await self.diagnostics
      .withLogCatch(
        info: .message("Failed to present resource tags details!"),
        fallback: { @MainActor (error: Error) async -> Void in
          self.viewState.update(\.snackbarMessage, to: .error(error))
        }
      ) {
        try await self.navigationToResourceTagsDetails.perform()
      }
  }

  internal nonisolated func showPermissionsDetails() async {
    await self.diagnostics
      .withLogCatch(
        info: .message("Failed to present resource permissions details!"),
        fallback: { @MainActor (error: Error) async -> Void in
          self.viewState.update(\.snackbarMessage, to: .error(error))
        }
      ) {
        try await self.navigationToResourcePermissionsDetails.perform()
      }
  }

  internal nonisolated func copyFieldValue(
    path: Resource.FieldPath
  ) async {
    await self.diagnostics
      .withLogCatch(
        info: .message("Failed to copy resource field value!"),
        fallback: { @MainActor (error: Error) async -> Void in
          self.viewState.update(\.snackbarMessage, to: .error(error))
        }
      ) {
        var resource: Resource = try await self.resourceController.state.value

        // ensure having secret if field is part of it
        if resource.isEncrypted(path) {
          try await self.resourceController.fetchSecretIfNeeded()
          resource = try await self.resourceController.state.value
        }  // else NOP
        let fieldValue: JSON = resource[keyPath: path]
        if let totpSecret: TOTPSecret = fieldValue.totpSecretValue {
          let totpValue: TOTPValue = try await self.features
            .instance(
              of: TOTPCodeGenerator.self,
              context: .init(
                resourceID: resource.id,
                totpSecret: totpSecret
              )
            )
            .generate()
          self.pasteboard.put(totpValue.otp.rawValue)
        }
        else {
          self.pasteboard.put(fieldValue.stringValue ?? "")
        }

        await self.viewState.update { (state: inout ViewState) in
          state.snackbarMessage = .info(
            .localized(
              key: "resource.value.copied",
              arguments: [
                resource
                  .displayableName(forField: path)?
                  .string()
                  ?? DisplayableString
                  .localized("resource.field.name.unknown")
                  .string()
              ]
            )
          )
        }
      }
  }

  internal nonisolated func revealFieldValue(
    path: Resource.FieldPath
  ) async {
    await self.diagnostics
      .withLogCatch(
        info: .message("Failed to reveal resource field value!"),
        fallback: { @MainActor (error: Error) async -> Void in
          self.viewState.update(\.snackbarMessage, to: .error(error))
        }
      ) { @MainActor in
        self.revealedFields.insert(path)
        try await self.resourceController.fetchSecretIfNeeded()
        try await self.update(resourceController.state.value)
      }
  }

  internal nonisolated func coverFieldValue(
    path: Resource.FieldPath
  ) async {
    await self.diagnostics
      .withLogCatch(
        info: .message("Failed to cover resource field value!"),
        fallback: { @MainActor (error: Error) async -> Void in
          self.viewState.update(\.snackbarMessage, to: .error(error))
        }
      ) { @MainActor in
        self.revealedFields.remove(path)
        try await self.update(resourceController.state.value)
      }
  }

  internal func deactivate() {
    self.diagnostics
      .logCatch(
        info: .message("Failed to cover resource fields!")
      ) { @MainActor in
        self.revealedFields.removeAll()
      }
  }
}

extension ResourceDetailsViewController.ViewState {

  @MainActor fileprivate mutating func updateFields(
    for resource: Resource,
    using features: Features,
    revealedFields: Set<Resource.FieldPath>,
    passwordPreviewEnabled: Bool
  ) {
    if resource.type.specification.slug == .placeholder {
      self.fields = .init()  // show no fields for placeholder type
    }
    else {
      self.fields =
        resource
        .fields
        .compactMap { (field: ResourceFieldSpecification) -> ResourceDetailsFieldViewModel? in
          // remove name from fields, we already have it displayed
          if field.isNameField {
            return .none
          }
          else {
            return .init(
              field,
              in: resource,
              revealedFields: revealedFields,
              passwordPreviewEnabled: passwordPreviewEnabled,
              prepareTOTPGenerator: { [features] totpSecret in
                let generator: TOTPCodeGenerator = try features.instance(
                  context: .init(
                    resourceID: resource.id,
                    totpSecret: totpSecret
                  )
                )
                return generator.generate
              }
            )
          }
        }
    }
  }
}

internal struct ResourceDetailsFieldViewModel {

  internal enum Accessory {

    case copy
    case reveal
    case hide
  }

  internal enum Value: Equatable {

    internal static func == (
      _ lhs: ResourceDetailsFieldViewModel.Value,
      _ rhs: ResourceDetailsFieldViewModel.Value
    ) -> Bool {
      switch (lhs, rhs) {
      case (.plain(let lString), .plain(let rString)):
        return lString == rString

      case (.encrypted, .encrypted):
        return true

      case (.password(let lString), .password(let rString)):
        return lString == rString

      case (.encryptedTOTP, .encryptedTOTP):
        return true

      case (.totp(let lHash, _), .totp(let rHash, _)):
        return lHash == rHash

      case _:
        return false
      }
    }

    case encrypted
    case placeholder(String)
    case plain(String)
    case password(String)
    case totp(hash: Int, generate: @Sendable () -> TOTPValue)
    case encryptedTOTP
    case invalid(TheError)
  }

  internal var path: Resource.FieldPath
  internal var name: DisplayableString
  internal var value: Value
  internal var accessory: Accessory?

  internal init?(
    _ field: ResourceFieldSpecification,
    in resource: Resource,
    revealedFields: Set<Resource.FieldPath>,
    passwordPreviewEnabled: Bool,
    prepareTOTPGenerator: (TOTPSecret) throws -> @Sendable () -> TOTPValue
  ) {
    assert(
      resource.type.specification.slug != .placeholder,
      "Can't prepare fields for placeholder resources"
    )
    self.path = field.path
    switch field.semantics {
    case  // unencrypted
    .text(let name, let placeholder, _) where !field.encrypted,
      .longText(let name, let placeholder, _) where !field.encrypted,
      .selection(let name, values: _, let placeholder, _) where !field.encrypted,
      .intValue(let name, let placeholder, _) where !field.encrypted,
      .floatValue(let name, let placeholder, _) where !field.encrypted:
      self.name = name
      if let stringValue = resource[keyPath: field.path].stringValue, !stringValue.isEmpty {
        self.value = .plain(stringValue)
        self.accessory = .copy
      }
      else {
        self.value = .placeholder(placeholder.string())
        self.accessory = .none
      }

    case  // encrypted
    .text(let name, let placeholder, _),
      .longText(let name, let placeholder, _),
      .selection(let name, values: _, let placeholder, _),
      .intValue(let name, let placeholder, _),
      .floatValue(let name, let placeholder, _):
      self.name = name
      let revealed: Bool = revealedFields.contains(field.path)
      if revealed {
        if let stringValue = resource[keyPath: field.path].stringValue, !stringValue.isEmpty {
          self.value = .plain(stringValue)
        }
        else {
          self.value = .placeholder(placeholder.string())
        }
        self.accessory = .hide
      }
      else {
        self.value = .encrypted
        self.accessory = .reveal
      }

    case .password(let name, let placeholder, _):
      self.name = name
      let revealed: Bool = revealedFields.contains(field.path)
      if revealed && passwordPreviewEnabled {
        if let stringValue = resource[keyPath: field.path].stringValue, !stringValue.isEmpty {
          self.value = .password(stringValue)
        }
        else {
          self.value = .placeholder(placeholder.string())
        }
        self.accessory = .hide
      }
      else {
        self.value = .encrypted
        self.accessory =
          passwordPreviewEnabled
          ? .reveal
          : .copy  // if not allowed use copy action accessory
      }

    case .totp(let name):
      let revealed: Bool = revealedFields.contains(field.path)
      self.name = name
      if revealed {
        if let totpSecret: TOTPSecret = resource[keyPath: field.path].totpSecretValue {
          do {
            self.value = .totp(
              hash: totpSecret.hashValue,
              generate: try prepareTOTPGenerator(totpSecret)
            )
          }
          catch {
            self.value = .invalid(error.asTheError())
          }
        }
        else {
          self.value = .invalid(
            InvalidResourceField
              .error(
                "Invalid or missing TOTP field",
                specification: field,
                path: field.path,
                value: nil,
                displayable: "error.otp.configuration.invalid"
              )
          )
        }
        self.accessory = .hide
      }
      else {
        self.value = .encryptedTOTP
        self.accessory = .reveal
      }

    case .undefined:
      return nil  // do not display undefined fields, unfortunately even a placeholder
    }
  }
}

extension ResourceDetailsFieldViewModel: Equatable {}

extension ResourceDetailsFieldViewModel: Identifiable {

  internal var id: some Hashable { self.path }
}
