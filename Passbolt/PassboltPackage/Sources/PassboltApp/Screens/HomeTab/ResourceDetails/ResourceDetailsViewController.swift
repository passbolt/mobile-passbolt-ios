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
    fileprivate var revealedFields: Set<ResourceType.FieldPath>
  }

  internal let viewState: UpdatableViewState<ViewState>
  internal let messageState: ViewStateVariable<SnackBarMessage?>

  private let resourceController: ResourceController
  private let otpCodesController: OTPCodesController

  private let navigationToSelf: NavigationToResourceDetails
  private let navigationToResourceContextualMenu: NavigationToResourceContextualMenu
  private let navigationToResourceLocationDetails: NavigationToResourceLocationDetails
  private let navigationToResourceTagsDetails: NavigationToResourceTagsDetails
  private let navigationToResourcePermissionsDetails: NavigationToResourcePermissionsDetails
  private let pasteboard: OSPasteboard

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
    let passwordPreviewEnabled: Bool =
      try features
      .sessionConfiguration()
      .passwordPreviewEnabled
    self.passwordPreviewEnabled = passwordPreviewEnabled

    self.resourceID = context

    self.features = features

    self.asyncExecutor = try features.instance()

    self.pasteboard = features.instance()

    self.navigationToSelf = try features.instance()
    self.navigationToResourceContextualMenu = try features.instance()
    self.navigationToResourceLocationDetails = try features.instance()
    self.navigationToResourceTagsDetails = try features.instance()
    self.navigationToResourcePermissionsDetails = try features.instance()

    self.resourceController = try features.instance()
    self.otpCodesController = try features.instance()
    let users: Users = try features.instance()

    self.viewState = .init(
      initial: .init(
        name: .init(),
        favorite: false,
        containsUndefinedFields: false,
        fields: .init(),
        location: .init(),
        tags: .init(),
        permissions: .init(),
        revealedFields: .init()
      ),
      updateFrom: self.resourceController.state,
      update: { (state: inout ViewState, resource: Resource) async throws in
        if !resource.secretAvailable {
          state.revealedFields.removeAll()
        }  // else NOP

        state.name = resource.name
        state.favorite = resource.favorite
        state.containsUndefinedFields = resource.containsUndefinedFields
        state.fields = fields(
          for: resource,
          using: features,
          revealedFields: state.revealedFields,
          passwordPreviewEnabled: passwordPreviewEnabled
        )
        state.location = resource.path.map(\.name)
        state.tags = resource.tags.map(\.slug.rawValue)
        state.permissions = resource.permissions.map { (permission: ResourcePermission) in
          switch permission {
          case .user(let id, _, _):
            return .user(
              id,
              avatarImage: users.avatarImage(for: id)
            )

          case .userGroup(let id, _, _):
            return .userGroup(id)
          }
        }
      },
      fallback: { [navigationToSelf] (state: inout ViewState, error: Error) async -> Void in
        try? await navigationToSelf.revert()
      }
    )
    self.messageState = .init(initial: .none)
  }
}

extension ResourceDetailsViewController {

  internal func showMenu() async {
    await Diagnostics
      .logCatch(
        info: .message("Failed to present resource menu!"),
        fallback: { @MainActor [messageState] (error: Error) async -> Void in
          messageState.show(.error(error))
        }
      ) {
        try await self.navigationToResourceContextualMenu
          .perform(
            context: .init(
              showMessage: { [messageState] (message: SnackBarMessage?) in
                messageState.update(\.self, to: message)
              }
            )
          )
      }
  }

  internal func showLocationDetails() async {
    await self.navigationToResourceLocationDetails.performCatching()
  }

  internal func showTagsDetails() async {
    await self.navigationToResourceTagsDetails.performCatching()
  }

  internal func showPermissionsDetails() async {
    await self.navigationToResourcePermissionsDetails.performCatching()
  }

  internal func copyFieldValue(
    path: Resource.FieldPath
  ) async {
    await withLogCatch(
      failInfo: "Failed to copy resource field value!",
      fallback: { @MainActor [messageState] (error: Error) async -> Void in
        messageState.show(.error(error))
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
        let totpValue: TOTPValue = try self.features
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

      self.messageState.show(
        .info(
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
      )
    }
  }

  internal func revealFieldValue(
    path: ResourceType.FieldPath
  ) async {
    await withLogCatch(
      failInfo: "Failed to reveal resource field value!",
      fallback: { @MainActor [messageState] (error: Error) async -> Void in
        messageState.show(.error(error))
      }
    ) {
      try await self.resourceController.fetchSecretIfNeeded()
      await self.viewState.update { (state: inout ViewState) in
        state.revealedFields.insert(path)
      }
    }
  }

  internal func coverFieldValue(
    path: ResourceType.FieldPath
  ) async {
    await self.viewState.update { (state: inout ViewState) in
      state.revealedFields.remove(path)
    }
  }
}

@MainActor private func fields(
  for resource: Resource,
  using features: Features,
  revealedFields: Set<Resource.FieldPath>,
  passwordPreviewEnabled: Bool
) -> Array<ResourceDetailsFieldViewModel> {
  if resource.type.specification.slug == .placeholder {
    return .init()  // show no fields for placeholder type
  }
  else {
    return resource
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

  internal var path: ResourceType.FieldPath
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
