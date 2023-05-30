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
import Users

internal final class ResourceDetailsViewController: ViewController {

  internal struct ViewState: Equatable {

    internal var name: String
    internal var favorite: Bool
    internal var fields: Array<ResourceDetailsFieldViewModel>
    internal var location: Array<String>
    internal var tags: Array<String>
    internal var permissions: Array<OverlappingAvatarStackView.Item>

    internal var snackbarMessage: SnackBarMessage?
  }

  internal nonisolated let viewState: MutableViewState<ViewState>

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
        fallback: { [navigationToSelf] in
          try? await navigationToSelf.revert()
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
    @Sendable func avatarImageFetch(
      for userID: User.ID
    ) -> @Sendable () async -> Data? {
      { [users] () async -> Data? in
        try? await users.userAvatarImage(userID)
      }
    }

    if !resource.hasSecret {
      self.revealedFields.removeAll(keepingCapacity: true)
    }  // else NOP

    self.viewState.update { (state: inout ViewState) -> Void in
      state.name = resource.meta.name.stringValue ?? ""
      state.favorite = resource.favorite
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
        revealedFields: self.revealedFields,
        passwordPreviewEnabled: self.passwordPreviewEnabled
      )
    }
  }

  internal nonisolated func showMenu() {
    self.asyncExecutor.scheduleCatchingWith(
      self.diagnostics,
      failMessage: "Failed to present resource menu!",
      behavior: .reuse
    ) { [navigationToResourceContextualMenu, viewState] in
      try await navigationToResourceContextualMenu
        .perform(
          context: .init(
            showMessage: { (message: SnackBarMessage?) in
              viewState.update(\.snackbarMessage, to: message)
            }
          )
        )
    }
  }

  internal nonisolated func showLocationDetails() {
    self.asyncExecutor.scheduleCatchingWith(
      self.diagnostics,
      failMessage: "Failed to present resource location details!",
      behavior: .reuse
    ) { [navigationToResourceLocationDetails] in
      try await navigationToResourceLocationDetails.perform()
    }
  }

  internal nonisolated func showTagsDetails() {
    self.asyncExecutor.scheduleCatchingWith(
      self.diagnostics,
      failMessage: "Failed to present resource tags details!",
      behavior: .reuse
    ) { [navigationToResourceTagsDetails] in
      try await navigationToResourceTagsDetails.perform()
    }
  }

  internal nonisolated func showPermissionsDetails() {
    self.asyncExecutor.scheduleCatchingWith(
      self.diagnostics,
      failMessage: "Failed to present resource permissions details!",
      behavior: .reuse
    ) { [navigationToResourcePermissionsDetails] in
      try await navigationToResourcePermissionsDetails.perform()
    }
  }

  internal nonisolated func copyFieldValue(
    path: Resource.FieldPath
  ) {
    self.asyncExecutor.scheduleCatchingWith(
      self.diagnostics,
      failMessage: "Failed to copy resource field value!",
      behavior: .reuse
    ) { [viewState, resourceController, pasteboard] in
      var resource: Resource = try await resourceController.state.value

      // ensure having secret if field is part of it
      if resource.secretContains(path) {
        try await resourceController.fetchSecretIfNeeded()
        resource = try await resourceController.state.value
      }  // else NOP

      pasteboard.put(resource[keyPath: path].stringValue ?? "")

      await viewState.update { (state: inout ViewState) in
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
  ) {
    self.asyncExecutor.scheduleCatchingWith(
      self.diagnostics,
      failMessage: "Failed to reveal resource field value!",
      behavior: .reuse
    ) { @MainActor [self] in
      self.revealedFields.insert(path)
      try await self.resourceController.fetchSecretIfNeeded()
      try await self.update(resourceController.state.value)
    }
  }

  internal nonisolated func coverFieldValue(
    path: Resource.FieldPath
  ) {
    self.asyncExecutor.scheduleCatchingWith(
      self.diagnostics,
      failMessage: "Failed to cover resource field value!",
      behavior: .reuse
    ) { @MainActor [self] in
      self.revealedFields.remove(path)
      try await self.update(resourceController.state.value)
    }
  }
}

extension ResourceDetailsViewController.ViewState {

  fileprivate mutating func updateFields(
    for resource: Resource,
    revealedFields: Set<Resource.FieldPath>,
    passwordPreviewEnabled: Bool
  ) {
    self.fields =
      resource
      .metaFields
      // remove name from fields, we already have it displayed
      .filter { (field: ResourceFieldSpecification) -> Bool in
        field.path != \.meta.name
      }
      .map { (field: ResourceFieldSpecification) -> ResourceDetailsFieldViewModel in
        .meta(field, in: resource)
      }
      + resource
      .secretFields
      .map { (field: ResourceFieldSpecification) -> ResourceDetailsFieldViewModel in
        let revealed: Bool = revealedFields.contains(field.path)
        // check if password preview is allowed
        let revealingAllowed: Bool =
          passwordPreviewEnabled || !(field.path == \.secret.password || field.path == \.secret)
        return .secret(
          field,
          in: resource,
          revealed: revealed,
          revealingAllowed: revealingAllowed
        )
      }
  }
}

internal struct ResourceDetailsFieldViewModel {

  internal enum Accessory {

    case copy
    case reveal
    case hide
  }

  internal enum Value: Equatable, ExpressibleByStringLiteral {

    case plain(String)
    case encrypted
    // TODO: [MOB-1290] - add TOTP to resource details
    //	 case totp(TOTPValue)

    init(
      stringLiteral value: String
    ) {
      self = .plain(value)
    }
  }

  internal var path: Resource.FieldPath
  internal var name: DisplayableString
  internal var value: Value
  internal var accessory: Accessory?

  internal static func meta(
    _ field: ResourceFieldSpecification,
    in resource: Resource
  ) -> Self {
    .init(
      path: field.path,
      name: field.name.displayable,
      value: resource[keyPath: field.path].stringValue.map(Value.plain) ?? "",
      accessory: .copy
    )
  }

  internal static func secret(
    _ field: ResourceFieldSpecification,
    in resource: Resource,
    revealed: Bool,
    revealingAllowed: Bool
  ) -> Self {
    .init(
      path: field.path,
      name: field.name.displayable,
      value: revealed && revealingAllowed
        ? resource[keyPath: field.path].stringValue.map(Value.plain) ?? .encrypted
        : .encrypted,
      accessory: revealingAllowed
        ? (  // if allowed check if secret is here and field is revealed
          !revealed || resource[keyPath: field.path] == nil
          ? .reveal
          : .hide)
        // if not allowed use copy action accessory
        : .copy
    )
  }
}

extension ResourceDetailsFieldViewModel: Equatable {}

extension ResourceDetailsFieldViewModel: Identifiable {

  internal var id: some Hashable { self.path }
}
